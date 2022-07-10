import XCTest
@testable import WooCommerce

private typealias FeatureCardEvent = WooAnalyticsEvent.FeatureCard

final class FeatureAnnouncementCardViewModelTests: XCTestCase {

    var sut: FeatureAnnouncementCardViewModel!

    private var analyticsProvider: MockAnalyticsProvider!
    private var analytics: WooAnalytics!

    override func setUp() {
        analyticsProvider = MockAnalyticsProvider()
        analytics = WooAnalytics(analyticsProvider: analyticsProvider)

        let config = FeatureAnnouncementCardViewModel.Configuration(
            source: .paymentMethods,
            campaign: .upsellCardReaders,
            title: "Buy a reader",
            message: "With a card reader, you can accept card payments",
            buttonTitle: "Buy now",
            image: .paymentsFeatureBannerImage)

        sut = FeatureAnnouncementCardViewModel(
            analytics: analytics,
            configuration: config)

        super.setUp()
    }

    func test_onAppear_logs_shown_analytics_event() {
        // Given

        // When
        sut.onAppear()

        // Then
        let expectedSource = FeatureCardEvent.Source.paymentMethods
        let expectedCampaign = FeatureCardEvent.Campaign.upsellCardReaders
        let expectedEvent = WooAnalyticsEvent.FeatureCard.shown(source: expectedSource, campaign: expectedCampaign)

        XCTAssert(analyticsProvider.receivedEvents.contains(where: { $0 == expectedEvent.statName.rawValue
        }))

        verifyUpsellCardProperties(expectedSource: expectedSource, expectedCampaign: expectedCampaign)
    }

    func test_dismissTapped_logs_dismissed_analytics_event() {
        // Given

        // When
        sut.dismissedTapped()

        // Then
        let expectedSource = FeatureCardEvent.Source.paymentMethods
        let expectedCampaign = FeatureCardEvent.Campaign.upsellCardReaders
        let expectedEvent = WooAnalyticsEvent.FeatureCard.dismissed(source: expectedSource, campaign: expectedCampaign)

        XCTAssert(analyticsProvider.receivedEvents.contains(where: { $0 == expectedEvent.statName.rawValue
        }))

        verifyUpsellCardProperties(expectedSource: expectedSource, expectedCampaign: expectedCampaign)
    }

    func test_ctaTapped_logs_analytics_event() {
        // Given

        // When
        sut.ctaTapped()

        // Then
        let expectedSource = FeatureCardEvent.Source.paymentMethods
        let expectedCampaign = FeatureCardEvent.Campaign.upsellCardReaders
        let expectedEvent = WooAnalyticsEvent.FeatureCard.ctaTapped(source: expectedSource, campaign: expectedCampaign)

        XCTAssert(analyticsProvider.receivedEvents.contains(where: { $0 == expectedEvent.statName.rawValue
        }))

        verifyUpsellCardProperties(expectedSource: expectedSource, expectedCampaign: expectedCampaign)
    }

    private func verifyUpsellCardProperties(
        expectedSource: FeatureCardEvent.Source,
        expectedCampaign: FeatureCardEvent.Campaign) {
        guard let actualProperties = analyticsProvider.receivedProperties.first(where: { $0.keys.contains("source")
        }) else {
            return XCTFail("Expected properties were not logged")
        }

        assertEqual(expectedSource.rawValue, actualProperties["source"] as? String)
        assertEqual(expectedCampaign.rawValue, actualProperties["campaign"] as? String)
    }
}
