import Storage

enum BetaFeature: String, CaseIterable {
    case viewAddOns
    case productSKUScanner
    case couponManagement
    case inAppPurchases
    case tapToPayOnIPhone
}

extension BetaFeature {
    var title: String {
        switch self {
        case .viewAddOns:
            return Localization.viewAddOnsTitle
        case .productSKUScanner:
            return Localization.productSKUScannerTitle
        case .couponManagement:
            return Localization.couponManagementTitle
        case .inAppPurchases:
            return Localization.inAppPurchasesManagementTitle
        case .tapToPayOnIPhone:
            return Localization.tapToPayOnIPhoneTitle
        }
    }

    var description: String {
        switch self {
        case .viewAddOns:
            return Localization.viewAddOnsDescription
        case .productSKUScanner:
            return Localization.productSKUScannerDescription
        case .couponManagement:
            return Localization.couponManagementDescription
        case .inAppPurchases:
            return Localization.inAppPurchasesManagementDescription
        case .tapToPayOnIPhone:
            return Localization.tapToPayOnIPhoneDescription
        }
    }

    var settingsKey: WritableKeyPath<GeneralAppSettings, Bool> {
        switch self {
        case .viewAddOns:
            return \.isViewAddOnsSwitchEnabled
        case .productSKUScanner:
            return \.isProductSKUInputScannerSwitchEnabled
        case .couponManagement:
            return \.isCouponManagementSwitchEnabled
        case .inAppPurchases:
            return \.isInAppPurchasesSwitchEnabled
        case .tapToPayOnIPhone:
            return \.isTapToPayOnIPhoneSwitchEnabled
        }
    }

    /// This is intended for removal, and new specific analytic stats should not be set here.
    /// When `viewAddOns` is removed, we can remove this property and always use the `settingsBetaFeatureToggled` event
    var analyticsStat: WooAnalyticsStat {
        switch self {
        case .viewAddOns:
            return .settingsBetaFeaturesOrderAddOnsToggled
        default:
            return .settingsBetaFeatureToggled
        }
    }

    var isAvailable: Bool {
        switch self {
        case .inAppPurchases:
            return ServiceLocator.featureFlagService.isFeatureFlagEnabled(.inAppPurchases)
        case .tapToPayOnIPhone:
            return ServiceLocator.featureFlagService.isFeatureFlagEnabled(.tapToPayOnIPhone)
        default:
            return true
        }
    }

    static var availableFeatures: [Self] {
        allCases.filter(\.isAvailable)
    }

    func analyticsProperties(toggleState enabled: Bool) -> [String: WooAnalyticsEventPropertyType] {
        var properties = ["state": enabled ? "on" : "off"]
        if analyticsStat == .settingsBetaFeatureToggled {
            properties["feature_name"] = self.rawValue
        }
        return properties
    }
}

extension GeneralAppSettingsStorage {
    func betaFeatureEnabled(_ feature: BetaFeature) -> Bool {
        guard feature.isAvailable else {
            return false
        }
        return value(for: feature.settingsKey)
    }

    func betaFeatureEnabledBinding(_ feature: BetaFeature) -> Binding<Bool> {
        Binding(get: {
            betaFeatureEnabled(feature)
        }, set: { newValue in
            try? setBetaFeatureEnabled(feature, enabled: newValue)
        })
    }

    func setBetaFeatureEnabled(_ feature: BetaFeature, enabled: Bool) throws {
        let event = WooAnalyticsEvent(statName: feature.analyticsStat,
                                      properties: feature.analyticsProperties(toggleState: enabled))
        ServiceLocator.analytics.track(event: event)
        try setValue(enabled, for: feature.settingsKey)
    }
}

extension BetaFeature: Identifiable {
    var id: String {
        description
    }
}

private extension BetaFeature {
    enum Localization {
        static let viewAddOnsTitle = NSLocalizedString(
            "View Add-Ons",
            comment: "Cell title on the beta features screen to enable the order add-ons feature")
        static let viewAddOnsDescription = NSLocalizedString(
            "Test out viewing Order Add-Ons as we get ready to launch",
            comment: "Cell description on the beta features screen to enable the order add-ons feature")

        static let productSKUScannerTitle = NSLocalizedString(
            "Product SKU Scanner",
            comment: "Cell title on beta features screen to enable product SKU input scanner in inventory settings.")
        static let productSKUScannerDescription = NSLocalizedString(
            "Test out scanning a barcode for a product SKU in the product inventory settings",
            comment: "Cell description on beta features screen to enable product SKU input scanner in inventory settings.")

        static let couponManagementTitle = NSLocalizedString(
            "Coupon Management",
            comment: "Cell title on beta features screen to enable coupon management")
        static let couponManagementDescription = NSLocalizedString(
            "Test out managing coupons as we get ready to launch",
            comment: "Cell description on beta features screen to enable coupon management")

        static let inAppPurchasesManagementTitle = NSLocalizedString(
            "In-app purchases",
            comment: "Cell title on beta features screen to enable in-app purchases")
        static let inAppPurchasesManagementDescription = NSLocalizedString(
            "Test out in-app purchases as we get ready to launch",
            comment: "Cell description on beta features screen to enable in-app purchases")

        static let tapToPayOnIPhoneTitle = NSLocalizedString(
            "Tap to Pay on iPhone",
            comment: "Cell tytle on beta features screen to enable Tap to Pay on iPhone: card payments with the " +
            "phone's built in reader")
        static let tapToPayOnIPhoneDescription = NSLocalizedString(
            "Test out In-Person Payments using your phone's built-in card reader, as we get ready to launch. " +
            "Supported on iPhone XS and newer phones, running iOS 16 or above, for US-based stores.",
            comment: "Cell description on beta features screen to enable in-app purchases")
    }
}
