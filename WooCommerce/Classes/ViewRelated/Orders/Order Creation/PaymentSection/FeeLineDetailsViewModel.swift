import SwiftUI
import struct Yosemite.OrderFeeLine

class FeeLineDetailsViewModel: ObservableObject {

    /// Closure to be invoked when the fee line is updated.
    ///
    var didSelectSave: ((OrderFeeLine?) -> Void)

    /// Helper to format price field input.
    ///
    private let priceFieldFormatter: PriceFieldFormatter

    /// Formatted amount to display. When empty displays a placeholder value.
    ///
    var formattedAmount: String {
        priceFieldFormatter.formattedAmount
    }

    /// Stores the amount(unformatted) entered by the merchant.
    ///
    @Published var amount: String = "" {
        didSet {
            guard amount != oldValue else { return }
            amount = priceFieldFormatter.formatAmount(amount)
        }
    }

    /// Defines the amount text color.
    ///
    var amountTextColor: UIColor {
        amount.isEmpty ? .textPlaceholder : .text
    }

    private let initialAmount: Decimal

    /// Returns true when existing fee line is edited.
    ///
    let isExistingFeeLine: Bool

    /// Returns true when there are no valid pending changes.
    ///
    var shouldDisableDoneButton: Bool {
        guard let amountDecimal = priceFieldFormatter.amountDecimal, amountDecimal > .zero else {
            return true
        }

        return amountDecimal == initialAmount
    }

    init(inputData: NewOrderViewModel.PaymentDataViewModel,
         locale: Locale = Locale.autoupdatingCurrent,
         storeCurrencySettings: CurrencySettings = ServiceLocator.currencySettings,
         didSelectSave: @escaping ((OrderFeeLine?) -> Void)) {
        self.priceFieldFormatter = .init(locale: locale, storeCurrencySettings: storeCurrencySettings)

        self.isExistingFeeLine = inputData.shouldShowFees

       let currencyFormatter = CurrencyFormatter(currencySettings: storeCurrencySettings)
        if let initialAmount = currencyFormatter.convertToDecimal(from: inputData.feesTotal) {
            self.initialAmount = initialAmount as Decimal
        } else {
            self.initialAmount = .zero
        }

        if initialAmount > 0, let formattedInputAmount = currencyFormatter.formatAmount(initialAmount) {
            self.amount = priceFieldFormatter.formatAmount(formattedInputAmount)
        }

        self.didSelectSave = didSelectSave
    }

    func saveData() {
        let feeLine = OrderFeeLine(feeID: 0,
                                   name: "Fee",
                                   taxClass: "",
                                   taxStatus: .none,
                                   total: amount,
                                   totalTax: "",
                                   taxes: [],
                                   attributes: [])
        didSelectSave(feeLine)
    }
}
