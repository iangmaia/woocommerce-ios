import Foundation
import Yosemite
import enum Alamofire.AFError

/// View model for `LoginJetpackSetupView`.
///
final class LoginJetpackSetupViewModel: ObservableObject {
    let siteURL: String
    /// Whether Jetpack is installed and activated and only connection needs to be handled.
    let connectionOnly: Bool
    private let stores: StoresManager
    private let storeNavigationHandler: (_ connectedEmail: String?) -> Void

    let setupSteps: [JetpackInstallStep]

    /// Title to be displayed on the Jetpack setup view
    var title: String {
        let step = currentSetupStep ?? .installation
        if setupFailed, let errorTitle = step.errorTitle {
            return errorTitle
        }
        return connectionOnly ? Localization.connectingJetpack : Localization.installingJetpack
    }

    var shouldShowInitialLoadingIndicator: Bool {
        currentSetupStep == nil && setupFailed == false
    }

    var shouldShowSetupSteps: Bool {
        currentSetupStep != nil && setupFailed == false
    }

    var shouldShowGoToStoreButton: Bool {
        currentSetupStep == .done && setupFailed == false
    }

    var tryAgainButtonTitle: String {
        let step = currentSetupStep ?? .installation
        return step.tryAgainButtonTitle ?? ""
    }

    @Published private(set) var currentSetupStep: JetpackInstallStep?
    @Published private(set) var currentConnectionStep: ConnectionStep?
    @Published private(set) var jetpackConnectionURL: URL?
    @Published var shouldPresentWebView = false
    @Published var jetpackConnectionInterrupted = false

    /// Whether the setup failed. This will be observed by `LoginJetpackSetupView` to present error modal.
    @Published private(set) var setupFailed: Bool = false
    @Published private(set) var setupErrorDetail: SetupErrorDetail?

    private var jetpackConnectedEmail: String?

    /// Error occurred in any install step
    ///
    private var setupError: Error? {
        didSet {
            updateErrorMessage()
        }
    }

    var hasEncounteredPermissionError: Bool {
        if case .responseValidationFailed(reason: .unacceptableStatusCode(code: 403)) = setupError as? AFError {
            return true
        }
        return false
    }

    /// Attributed string for the description text
    lazy private(set) var descriptionAttributedString: NSAttributedString = {
        let font: UIFont = .body
        let boldFont: UIFont = font.bold
        let siteName = siteURL.trimHTTPScheme()

        let attributedString = NSMutableAttributedString(
            string: String(format: Localization.description, siteName),
            attributes: [.font: font,
                         .foregroundColor: UIColor.text.withAlphaComponent(0.8)
                        ]
        )
        let boldSiteAddress = NSAttributedString(string: siteName, attributes: [.font: boldFont, .foregroundColor: UIColor.text])
        attributedString.replaceFirstOccurrence(of: siteName, with: boldSiteAddress)
        return attributedString
    }()

    private let analytics: Analytics

    init(siteURL: String,
         connectionOnly: Bool,
         stores: StoresManager = ServiceLocator.stores,
         analytics: Analytics = ServiceLocator.analytics,
         onStoreNavigation: @escaping (String?) -> Void = { _ in}) {
        self.siteURL = siteURL
        self.connectionOnly = connectionOnly
        self.stores = stores
        self.analytics = analytics
        let setupSteps = connectionOnly ? [.connection, .done] : JetpackInstallStep.allCases
        self.setupSteps = setupSteps
        self.storeNavigationHandler = onStoreNavigation
    }

    func isSetupStepFailed(_ step: JetpackInstallStep) -> Bool {
        guard let currentStep = currentSetupStep else {
            return false
        }
        return step == currentStep && setupFailed
    }

    func isSetupStepInProgress(_ step: JetpackInstallStep) -> Bool {
        guard let currentStep = currentSetupStep else {
            return false
        }
        return step == currentStep && step != .done
    }

    func isSetupStepPending(_ step: JetpackInstallStep) -> Bool {
        guard let currentStep = currentSetupStep else {
            return false
        }
        return step > currentStep
    }

    func startSetup() {
        retrieveJetpackPluginDetails()
    }

    func didAuthorizeJetpackConnection() {
        checkJetpackConnection()
    }

    func navigateToStore() {
        analytics.track(.loginJetpackSetupGoToStoreTapped)
        storeNavigationHandler(jetpackConnectedEmail)
    }

    func retryAllSteps() {
        analytics.track(.loginJetpackSetupScreenTryAgainButtonTapped,
                        withProperties: currentSetupStep?.analyticsDescription)
        setupFailed = false
        setupError = nil
        setupErrorDetail = nil

        currentSetupStep = nil
        currentConnectionStep = nil
        startSetup()
    }

    // MARK: - LoginJetpackSetupInterruptedView
    func didTapContinueConnectionButton() {
        analytics.track(.loginJetpackSetupScreenTryAgainButtonTapped,
                        withProperties: currentSetupStep?.analyticsDescription)
    }
}

// MARK: Private helpers
//
private extension LoginJetpackSetupViewModel {
    func retrieveJetpackPluginDetails() {
        let action = JetpackConnectionAction.retrieveJetpackPluginDetails { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let plugin):
                if plugin.status == .inactive {
                    self.activateJetpack()
                } else {
                    self.fetchJetpackConnectionURL()
                }
            case .failure(let error):
                DDLogError("⛔️ Error retrieving Jetpack: \(error)")
                self.setupError = error
                if self.hasEncounteredPermissionError == false,
                    self.setupSteps.contains(.installation) {
                    // plugin is likely to not have been installed, so proceed to install it.
                    self.installJetpack()
                } else {
                    self.setupFailed = true
                }
            }
        }
        stores.dispatch(action)
    }

    func installJetpack() {
        currentSetupStep = .installation
        let action = JetpackConnectionAction.installJetpackPlugin { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.analytics.track(.loginJetpackSetupScreenInstallSuccessful)
                self.activateJetpack()
            case .failure(let error):
                self.analytics.track(.loginJetpackSetupScreenInstallFailed, withError: error)
                DDLogError("⛔️ Error installing Jetpack: \(error)")
                self.setupError = error
                self.setupFailed = true
            }
        }
        stores.dispatch(action)
    }

    func activateJetpack() {
        currentSetupStep = .activation
        let action = JetpackConnectionAction.activateJetpackPlugin { [weak self] result in
            guard let self else { return }
            switch result {
            case .success:
                self.analytics.track(.loginJetpackSetupActivationSuccessful)
                self.fetchJetpackConnectionURL()
            case .failure(let error):
                self.analytics.track(.loginJetpackSetupActivationFailed, withError: error)
                DDLogError("⛔️ Error activating Jetpack: \(error)")
                self.setupError = error
                self.setupFailed = true
            }
        }
        stores.dispatch(action)
    }

    func fetchJetpackConnectionURL() {
        currentSetupStep = .connection
        let action = JetpackConnectionAction.fetchJetpackConnectionURL { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let url):
                self.analytics.track(.loginJetpackSetupFetchJetpackConnectionURLSuccessful)
                self.jetpackConnectionURL = url
                self.shouldPresentWebView = true
            case .failure(let error):
                self.analytics.track(.loginJetpackSetupFetchJetpackConnectionURLFailed, withError: error)
                DDLogError("⛔️ Error fetching Jetpack connection URL: \(error)")
                self.setupError = error
                self.setupFailed = true
            }
        }
        stores.dispatch(action)
    }

    func checkJetpackConnection(retryCount: Int = 0) {
        guard retryCount <= Constants.maxRetryCount else {
            setupFailed = true
            if let setupError {
                analytics.track(.loginJetpackSetupErrorCheckingJetpackConnection, withError: setupError)
            }
            return
        }
        currentConnectionStep = .inProgress
        let action = JetpackConnectionAction.fetchJetpackUser { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let user):
                guard let connectedEmail = user.wpcomUser?.email else {
                    DDLogWarn("⚠️ Cannot find connected WPcom user")
                    let missingWpcomUserError = NSError(domain: Constants.errorDomain,
                                                        code: Constants.errorCodeNoWPComUser,
                                                        userInfo: [Constants.errorUserInfoReason: Constants.errorUserInfoNoWPComUser])
                    self.setupError = missingWpcomUserError
                    self.analytics.track(.loginJetpackSetupCannotFindWPCOMUser, withError: missingWpcomUserError)
                    // Retry fetching user in case Jetpack sync takes some time.
                    DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delayBeforeRetry) { [weak self] in
                        self?.checkJetpackConnection(retryCount: retryCount + 1)
                    }
                    return
                }

                self.jetpackConnectedEmail = connectedEmail
                self.currentConnectionStep = .authorized
                self.currentSetupStep = .done

                self.analytics.track(.loginJetpackSetupAllStepsMarkedDone)
            case .failure(let error):
                DDLogError("⛔️ Error checking Jetpack connection: \(error)")
                self.setupError = error
                DispatchQueue.main.asyncAfter(deadline: .now() + Constants.delayBeforeRetry) { [weak self] in
                    self?.checkJetpackConnection(retryCount: retryCount + 1)
                }
            }
        }
        stores.dispatch(action)
    }

    func updateErrorMessage() {
        switch setupError {
        case .some(AFError.responseValidationFailed(reason: .unacceptableStatusCode(code: 403))):
            setupErrorDetail = .init(setupErrorMessage: Localization.permissionErrorMessage,
                                     setupErrorSuggestion: Localization.permissionErrorSuggestion,
                                     errorCode: 403)
        case .some(AFError.responseValidationFailed(reason: .unacceptableStatusCode(let code))) where 500...599 ~= code:
            setupErrorDetail = .init(setupErrorMessage: Localization.communicationErrorMessage,
                                     setupErrorSuggestion: Localization.communicationErrorSuggestion,
                                     errorCode: code)
        default:
            let code: Int? = {
                if let afError = setupError as? AFError, let code = afError.responseCode {
                    return code
                }
                return (setupError as? NSError)?.code
            }()
            setupErrorDetail = .init(setupErrorMessage: Localization.genericErrorMessage,
                                     setupErrorSuggestion: Localization.communicationErrorSuggestion,
                                     errorCode: code)
        }
    }
}

// MARK: Subtypes
//
extension LoginJetpackSetupViewModel {
    /// Details for setup error to display on `LoginJetpackSetupView`
    ///
    struct SetupErrorDetail: Equatable {
        let setupErrorMessage: String
        let setupErrorSuggestion: String
        let errorCode: Int?
    }

    /// Steps for the Jetpack connection process.
    ///
    enum ConnectionStep {
        case inProgress
        case authorized

        var title: String {
            switch self {
            case .inProgress:
                return LoginJetpackSetupViewModel.Localization.validating
            case .authorized:
                return LoginJetpackSetupViewModel.Localization.connectionApproved
            }
        }

        var tintColor: UIColor {
            switch self {
            case .inProgress:
                return .secondaryLabel
            case .authorized:
                return .withColorStudio(.green, shade: .shade50)
            }
        }
    }

    enum Localization {
        static let installingJetpack = NSLocalizedString(
            "Installing Jetpack",
            comment: "Title for the Jetpack setup screen when installation is required"
        )
        static let connectingJetpack = NSLocalizedString(
            "Connecting Jetpack",
            comment: "Title for the Jetpack setup screen when connection is required"
        )
        static let description = NSLocalizedString(
            "Please wait while we connect your store %1$@ with Jetpack.",
            comment: "Message on the Jetpack setup screen. The %1$@ is the site address."
        )
        static let validating = NSLocalizedString(
            "Validating",
            comment: "Message to be displayed when a Jetpack connection is being authorized"
        )
        static let connectionApproved = NSLocalizedString(
            "Connected",
            comment: "Message to be displayed when a Jetpack connection has been authorized"
        )
        static let permissionErrorMessage = NSLocalizedString(
            "You don't have permission to manage plugins on this store.",
            comment: "Message to be displayed when the user encounters a permission error during Jetpack setup"
        )
        static let permissionErrorSuggestion = NSLocalizedString(
            "Please contact your shop manager or administrator for help.",
            comment: "Suggestion to be displayed when the user encounters a permission error during Jetpack setup"
        )
        static let communicationErrorMessage = NSLocalizedString(
            "There was an error communicating with your site.",
            comment: "Message to be displayed when the user encounters a permission error during Jetpack setup"
        )
        static let communicationErrorSuggestion = NSLocalizedString(
            "Please try again or contact support if this error continues.",
            comment: "Suggestion to be displayed when the user encounters a permission error during Jetpack setup"
        )
        static let genericErrorMessage = NSLocalizedString(
            "There was an error completing your request.",
            comment: "Message to be displayed when the user encounters a generic error during Jetpack setup"
        )
    }

    private enum Constants {
        static let maxRetryCount: Int = 2
        static let delayBeforeRetry: Double = 0.5
        static let errorDomain = "LoginJetpackSetup"
        static let errorCodeNoWPComUser = 99
        static let errorUserInfoReason = "reason"
        static let errorUserInfoNoWPComUser = "No connected WP.com user found"
    }
}
