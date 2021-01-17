import UIKit
import SafariServices
import WordPressUI
import Yosemite


/// Configuration and actions for an ULErrorViewController, modelling
/// an error when Jetpack is not installed or is not connected
struct WrongAccountErrorViewModel: ULAccountMismatchViewModel {
    private let siteURL: String
    private let defaultAccount: Account?

    init(siteURL: String?, sessionManager: SessionManagerProtocol =  ServiceLocator.stores.sessionManager) {
        self.siteURL = siteURL ?? Localization.yourSite
        self.defaultAccount = sessionManager.defaultAccount
    }

    // MARK: - Data and configuration
    var userEmail: String {
        guard let account = defaultAccount else {
            DDLogWarn("⚠️ Present account mismatch UI for \(siteURL) without a default account")

            return ""
        }
        return account.email
    }

    var userName: String {
        guard let account = defaultAccount else {
            DDLogWarn("⚠️ Present account mismatch UI for \(siteURL) without a default account")

            return ""
        }

        return account.username
    }

    var displayName: String {
        guard let account = defaultAccount else {
            DDLogWarn("⚠️ Present account mismatch UI for \(siteURL) without a default display account")

            return ""
        }

        return account.displayName
    }

    let image: UIImage = .errorImage

    var text: NSAttributedString {
        let font: UIFont = .body
        let boldFont: UIFont = font.bold

        let boldSiteAddress = NSAttributedString(string: siteURL.trimHTTPScheme(),
                                                           attributes: [.font: boldFont])
        let message = NSMutableAttributedString(string: Localization.errorMessage)

        message.replaceFirstOccurrence(of: "%@", with: boldSiteAddress)

        return message
    }

    let isAuxiliaryButtonHidden = false

    let auxiliaryButtonTitle = Localization.findYourConnectedEmail

    let primaryButtonTitle = Localization.primaryButtonTitle

    let secondaryButtonTitle = Localization.secondaryButtonTitle

    // MARK: - Actions
    func didTapPrimaryButton(in viewController: UIViewController?) {
        guard let url = URL(string: Strings.instructionsURLString) else {
            return
        }

        let safariViewController = SFSafariViewController(url: url)
        safariViewController.modalPresentationStyle = .pageSheet
        viewController?.present(safariViewController, animated: true)
    }

    func didTapAuxiliaryButton(in viewController: UIViewController?) {
        let fancyAlert = FancyAlertViewController.makeNeedHelpFindingEmailAlertController()
        fancyAlert.modalPresentationStyle = .custom
        fancyAlert.transitioningDelegate = AppDelegate.shared.tabBarController
        viewController?.present(fancyAlert, animated: true)
    }

    func didTapLogOutButton(in viewController: UIViewController?) {
        // Log out and pop
        ServiceLocator.stores.deauthenticate()
        viewController?.navigationController?.popToRootViewController(animated: true)
    }
}


// MARK: - Private data structures
private extension WrongAccountErrorViewModel {
    enum Localization {
        static let errorMessage = NSLocalizedString("It looks like %@ is connected to a different account.",
                                                    comment: "Message explaining that the site entered and the acount logged into do not match. "
                                                        + "Reads like 'It looks like awebsite.com is connected to a different account")

        static let findYourConnectedEmail = NSLocalizedString("Find your connected email",
                                                     comment: "Button linking to webview explaining how to find your connected email"
                                                        + "Presented when logging in with a store address that does not match the account entered")

        static let primaryButtonTitle = NSLocalizedString("See Connected Stores",
                                                          comment: "Action button linking to a list of connected stores."
                                                          + "Presented when logging in with a site address that does not have a valid Jetpack installation")

        static let secondaryButtonTitle = NSLocalizedString("Log In With Another Account",
                                                            comment: "Action button that will restart the login flow."
                                                            + "Presented when logging in with a site address that does not have a valid Jetpack installation")

        static let yourSite = NSLocalizedString("your site",
                                                comment: "Placeholder for site url, if the url is unknown."
                                                    + "Presented when logging in with a site address that does not have a valid Jetpack installation."
                                                + "The error would read: to use this app for your site you'll need...")

    }

    enum Strings {
        static let instructionsURLString = "https://docs.woocommerce.com/document/jetpack-setup-instructions-for-the-woocommerce-mobile-app/"
    }
}
