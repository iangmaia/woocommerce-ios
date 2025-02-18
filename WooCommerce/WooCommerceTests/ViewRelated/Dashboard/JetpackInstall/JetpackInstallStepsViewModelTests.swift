import XCTest
@testable import WooCommerce
@testable import Yosemite

final class JetpackInstallStepsViewModelTests: XCTestCase {

    private let testSiteID: Int64 = 1232
    private let testSiteURL = "https://test.com"
    private let testWPAdminURL = "https://test.com/wp-admin/"

    func test_startInstallation_dispatches_installSitePlugin_action_if_getPluginDetails_fails() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        var pluginDetailsSiteID: Int64?
        var checkedPluginName: String?
        var installedSiteID: Int64?
        var pluginSlug: String?
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(let siteID, let slug, _):
                installedSiteID = siteID
                pluginSlug = slug
            case .getPluginDetails(let siteID, let pluginName, let onCompletion):
                pluginDetailsSiteID = siteID
                checkedPluginName = pluginName
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(pluginDetailsSiteID, testSiteID)
        XCTAssertEqual(checkedPluginName, "jetpack/jetpack")
        XCTAssertEqual(installedSiteID, testSiteID)
        XCTAssertEqual(pluginSlug, "jetpack")
    }

    func test_activateSitePlugin_is_dispatched_when_installSitePlugin_succeeds() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        var activatedSiteID: Int64?
        var activatedPluginName: String?
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .activateSitePlugin(let siteID, let pluginName, _):
                activatedSiteID = siteID
                activatedPluginName = pluginName
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(activatedSiteID, testSiteID)
        XCTAssertEqual(activatedPluginName, "jetpack/jetpack")
    }

    func test_startInstallation_skips_installSitePlugin_action_if_getPluginDetails_succeeds() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        var installedSiteID: Int64?
        var activatedSiteID: Int64?
        var activatedPluginName: String?
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(let siteID, _, _):
                installedSiteID = siteID
            case .activateSitePlugin(let siteID, let pluginName, _):
                activatedSiteID = siteID
                activatedPluginName = pluginName
            case .getPluginDetails(let siteID, let pluginName, let onCompletion):
                let jetpack = SitePlugin.fake().copy(siteID: siteID, plugin: pluginName, status: .inactive)
                onCompletion(.success(jetpack))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertNil(installedSiteID)
        XCTAssertEqual(activatedSiteID, testSiteID)
        XCTAssertEqual(activatedPluginName, "jetpack/jetpack")
    }

    func test_installSitePlugin_is_retried_2_times_if_continuously_fails() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        var installedPluginInvokedCount = 0
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                installedPluginInvokedCount += 1
                onCompletion(.failure(NSError(domain: "Server Error", code: 500)))
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(installedPluginInvokedCount, 3) // 1 initial time plus 2 retries
        XCTAssertTrue(viewModel.installFailed)
    }

    func test_loadAndSynchronizeSite_is_dispatched_when_activating_plugin_succeeds() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        var checkedSiteID: Int64?
        var forcedUpdateSite: Bool?
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .activateSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        storesManager.whenReceivingAction(ofType: AccountAction.self) { action in
            switch action {
            case .loadAndSynchronizeSite(let siteID, let forcedUpdate, _):
                checkedSiteID = siteID
                forcedUpdateSite = forcedUpdate
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(checkedSiteID, testSiteID)
        XCTAssertEqual(forcedUpdateSite, true)
    }

    func test_currentStep_is_installation_on_startInstallation() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(viewModel.currentStep, .installation)
    }

    func test_currentStep_is_activate_when_installation_succeeds() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(viewModel.currentStep, .activation)
    }

    func test_currentStep_is_connection_when_installation_and_activation_succeeds() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .activateSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(viewModel.currentStep, .connection)
    }

    func test_currentStep_is_done_when_site_has_isWooCommerceActive_and_not_isJetpackCPConnected() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .installSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .activateSitePlugin(_, _, let onCompletion):
                onCompletion(.success(()))
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        storesManager.whenReceivingAction(ofType: AccountAction.self) { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .loadAndSynchronizeSite(_, _, let onCompletion):
                let fetchedSite = Site.fake().copy(siteID: self.testSiteID,
                                                   isJetpackThePluginInstalled: true,
                                                   isJetpackConnected: true,
                                                   isWooCommerceActive: true)
                onCompletion(.success(fetchedSite))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(viewModel.currentStep, .done)
        XCTAssertFalse(viewModel.installFailed)
    }

    func test_currentStep_is_not_done_when_site_does_not_have_isWooCommerceActive() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .getPluginDetails(let siteID, let pluginName, let onCompletion):
                let jetpack = SitePlugin.fake().copy(siteID: siteID, plugin: pluginName, status: .active)
                onCompletion(.success(jetpack))
            default:
                break
            }
        }
        var checkConnectionInvokedCount = 0
        storesManager.whenReceivingAction(ofType: AccountAction.self) { [weak self] action in
            guard let self = self else { return }
            switch action {
            case .loadAndSynchronizeSite(_, _, let onCompletion):
                checkConnectionInvokedCount += 1
                let fetchedSite = Site.fake().copy(siteID: self.testSiteID,
                                                   isJetpackThePluginInstalled: true,
                                                   isJetpackConnected: true,
                                                   isWooCommerceActive: false)
                onCompletion(.success(fetchedSite))
            default:
                break
            }
        }
        viewModel.startInstallation()

        // Then
        XCTAssertEqual(viewModel.currentStep, .connection)
        XCTAssertTrue(viewModel.installFailed)
        XCTAssertEqual(checkConnectionInvokedCount, 3) // 1 initial time plus 2 retries
    }

    func test_wpAdminURL_returns_siteAdminURL_if_it_has_valid_scheme() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: testWPAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation() // force the installation step to get non-nil url

        // Then
        XCTAssertEqual(viewModel.wpAdminURL?.absoluteString.hasPrefix(testWPAdminURL), true)
    }

    func test_wpAdminURL_returns_url_constructed_from_siteURL_if_it_does_not_have_valid_scheme() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let invalidAdminURL = ""
        let constructedPath = testSiteURL + "/wp-admin/"
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: testSiteURL, siteAdminURL: invalidAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation() // force the installation step to get non-nil url

        // Then
        XCTAssertEqual(viewModel.wpAdminURL?.absoluteString.hasPrefix(constructedPath), true)
    }

    func test_wpAdminURL_returns_nil_if_both_siteURL_and_siteAdminURL_do_not_have_valid_scheme() {
        // Given
        let storesManager = MockStoresManager(sessionManager: .testingInstance)
        let invalidSiteURL = ""
        let invalidAdminURL = ""
        let viewModel = JetpackInstallStepsViewModel(siteID: testSiteID, siteURL: invalidSiteURL, siteAdminURL: invalidAdminURL, stores: storesManager)

        // When
        storesManager.whenReceivingAction(ofType: SitePluginAction.self) { action in
            switch action {
            case .getPluginDetails(_, _, let onCompletion):
                onCompletion(.failure(NSError(domain: "Not Found", code: 404)))
            default:
                break
            }
        }
        viewModel.startInstallation() // force the installation step to get non-nil url

        // Then
        XCTAssertNil(viewModel.wpAdminURL)
    }
}
