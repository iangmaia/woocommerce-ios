import XCTest
import enum Networking.DotcomError
import enum Networking.SiteCreationError
@testable import class Networking.MockNetwork
@testable import Yosemite

final class SiteStoreTests: XCTestCase {
    /// Mock Dispatcher.
    private var dispatcher: Dispatcher!

    /// Mock Storage: InMemory.
    private var storageManager: MockStorageManager!

    /// Mock Network: Allows us to inject predefined responses.
    private var network: Networking.MockNetwork!

    private var remote: MockSiteRemote!
    private var store: SiteStore!

    override func setUp() {
        super.setUp()
        dispatcher = Dispatcher()
        storageManager = MockStorageManager()
        network = MockNetwork()
        remote = MockSiteRemote()
        store = SiteStore(remote: remote,
                          dispatcher: dispatcher,
                          storageManager: storageManager,
                          network: network)
    }

    override func tearDown() {
        store = nil
        remote = nil
        network = nil
        storageManager = nil
        dispatcher = nil
        super.tearDown()
    }

    // MARK: - `createSite`

    func test_createSite_returns_site_result_on_success() throws {
        // Given
        remote.whenCreatingSite(thenReturn: .success(
            .init(site: .init(siteID: "134",
                              name: "Salsa verde",
                              url: "https://salsa.verde/",
                              siteSlug: "salsa.verde"),
                  success: true)))

        // When
        let result = waitFor { promise in
            self.store.onAction(SiteAction.createSite(name: "Salsa",
                                                      domain: "salsa.roja",
                                                      completion: { result in
                promise(result)
            }))
        }

        // Then
        XCTAssertTrue(result.isSuccess)
        let siteResult = try XCTUnwrap(result.get())
        XCTAssertEqual(siteResult, .init(siteID: 134, name: "Salsa verde", url: "https://salsa.verde/", siteSlug: "salsa.verde"))
    }

    func test_createSite_returns_unsuccessful_error_on_false_success() throws {
        // Given
        remote.whenCreatingSite(thenReturn: .success(
            .init(site: .init(siteID: "134",
                              name: "Salsa verde",
                              url: "https://salsa.verde/",
                              siteSlug: "salsa.verde"),
                  // Success flag is `false` for some reason.
                  success: false)))

        // When
        let result = waitFor { promise in
            self.store.onAction(SiteAction.createSite(name: "Salsa",
                                                      domain: "salsa.roja",
                                                      completion: { result in
                promise(result)
            }))
        }

        // Then
        let error = try XCTUnwrap(result.failure)
        XCTAssertEqual(error, .unsuccessful)
    }

    func test_createSite_returns_invalidDomain_error_on_Networking_domain_error() throws {
        // Given
        remote.whenCreatingSite(thenReturn: .failure(
            Networking.SiteCreationError.invalidDomain
        ))

        // When
        let result = waitFor { promise in
            self.store.onAction(SiteAction.createSite(name: "Salsa",
                                                      domain: "salsa.roja",
                                                      completion: { result in
                promise(result)
            }))
        }

        // Then
        let error = try XCTUnwrap(result.failure)
        XCTAssertEqual(error, .invalidDomain)
    }

    func test_createSite_returns_domainExists_error_on_Dotcom_blog_name_exists_error() throws {
        // Given
        remote.whenCreatingSite(thenReturn: .failure(
            DotcomError.unknown(code: "blog_name_exists", message: "Sorry, that site already exists!")
        ))

        // When
        let result = waitFor { promise in
            self.store.onAction(SiteAction.createSite(name: "Salsa",
                                                      domain: "salsa.roja",
                                                      completion: { result in
                promise(result)
            }))
        }

        // Then
        let error = try XCTUnwrap(result.failure)
        XCTAssertEqual(error, .domainExists)
    }

    func test_createSite_returns_invalidDomain_error_on_Dotcom_blog_name_error() throws {
        // Given
        remote.whenCreatingSite(thenReturn: .failure(
            DotcomError.unknown(code: "blog_name_only_lowercase_letters_and_numbers",
                                message: "Site names can only contain lowercase letters (a-z) and numbers.")
        ))

        // When
        let result = waitFor { promise in
            self.store.onAction(SiteAction.createSite(name: "Salsa",
                                                      domain: "salsa.roja",
                                                      completion: { result in
                promise(result)
            }))
        }

        // Then
        let error = try XCTUnwrap(result.failure)
        XCTAssertEqual(error, .invalidDomain)
    }
}
