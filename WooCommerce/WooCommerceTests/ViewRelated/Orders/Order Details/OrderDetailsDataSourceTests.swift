import Foundation
import XCTest

import Yosemite

import protocol Storage.StorageManagerType
import protocol Storage.StorageType

@testable import WooCommerce

/// Test cases for `OrderDetailsDataSourceTests`
///
final class OrderDetailsDataSourceTests: XCTestCase {

    private typealias Title = OrderDetailsDataSource.Title

    private var storageManager: MockStorageManager!

    private var storage: StorageType {
        storageManager.viewStorage
    }

    override func setUp() {
        super.setUp()
        storageManager = MockStorageManager()
    }

    override func tearDown() {
        storageManager = nil
        super.tearDown()
    }

    func test_payment_section_is_shown_right_after_the_products_and_refunded_products_sections() {
        // Given
        let order = makeOrder()

        insert(refund: makeRefund(orderID: order.orderID, siteID: order.siteID))

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let actualTitles = dataSource.sections.map(\.title)
        let expectedTitles = [
            nil,
            Title.products,
            Title.refundedProducts,
            Title.payment,
            Title.information,
            Title.notes
        ]

        XCTAssertEqual(actualTitles, expectedTitles)
    }

    func test_refund_button_is_visible() throws {
        // Given
        let order = makeOrder()
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        let issueRefundRow = row(row: .issueRefundButton, in: paymentSection)
        XCTAssertNotNil(issueRefundRow)
    }

    func test_refund_button_is_not_visible_when_the_order_status_is_refunded() throws {
        // Given
        let order = MockOrders().makeOrder(status: .refunded, items: [makeOrderItem()])
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        let issueRefundRow = row(row: .issueRefundButton, in: paymentSection)
        XCTAssertNil(issueRefundRow)
    }

    func test_refund_button_is_not_visible_when_the_status_is_other_than_refunded_but_the_order_is_not_refundable() throws {
        // Given
        let order = Order.fake().copy(status: .processing, items: [makeOrderItem()], refunds: [OrderRefundCondensed.fake()])
        let orderRefundsOptionsDeterminer = MockOrderRefundsOptionsDeterminer(isAnythingToRefund: false)
        let dataSource = OrderDetailsDataSource(order: order,
                                                storageManager: storageManager,
                                                cardPresentPaymentsConfiguration: Mocks.configuration,
                                                refundableOrderItemsDeterminer: orderRefundsOptionsDeterminer)

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        let issueRefundRow = row(row: .issueRefundButton, in: paymentSection)
        XCTAssertNil(issueRefundRow)
    }

    func test_markOrderComplete_button_is_visible_and_primary_style_if_order_is_processing_and_not_eligible_for_shipping_label_creation() throws {
        // Given
        let order = makeOrder().copy(status: .processing)
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = false

        // When
        dataSource.reloadSections()

        // Then
        let productsSection = try section(withTitle: Title.products, from: dataSource)
        XCTAssertNotNil(row(row: .markCompleteButton(style: .primary, showsBottomSpacing: true), in: productsSection))
    }

    func test_markOrderComplete_button_is_visible_and_secondary_style_if_order_is_processing_and_eligible_for_shipping_label_creation() throws {
        // Given
        let order = makeOrder().copy(status: .processing)
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true

        // When
        dataSource.reloadSections()

        // Then
        let productsSection = try section(withTitle: Title.products, from: dataSource)
        XCTAssertNotNil(row(row: .markCompleteButton(style: .secondary, showsBottomSpacing: false), in: productsSection))
        XCTAssertNotNil(row(row: .shippingLabelCreationInfo(showsSeparator: false), in: productsSection))
    }

    func test_markOrderComplete_button_is_hidden_if_order_is_not_processing() throws {
        // Given
        let order = makeOrder().copy(status: .onHold)
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)

        // When
        dataSource.reloadSections()

        // Then
        let productsSection = try section(withTitle: Title.products, from: dataSource)
        XCTAssertNil(row(row: .markCompleteButton(style: .primary, showsBottomSpacing: true), in: productsSection))
        XCTAssertNil(row(row: .markCompleteButton(style: .secondary, showsBottomSpacing: false), in: productsSection))
    }

    func test_collect_payment_button_is_visible_and_primary_style_if_order_status_is_processing_and_method_is_cash_on_delivery() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: .some(nil), paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_visible_and_primary_style_if_order_status_is_on_hold_and_method_is_woocommerce_payments() throws {
        // Given
        let order = makeOrder().copy(status: .onHold, datePaid: .some(nil), paymentMethodID: "woocommerce_payments")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_order_is_processing_and_order_is_not_eligible_for_cash_on_delivery() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: nil, paymentMethodID: "stripe")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_account_not_eligible_for_card_present_payments() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: nil, paymentMethodID: "stripe")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_order_is_eligible_for_cash_on_delivery_and_total_amount_is_zero() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: nil, total: "0", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_visible_if_order_is_eligible_for_cash_on_delivery_and_total_amount_is_greater_than_zero() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: .some(nil), total: "1", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_order_is_a_confirmed_booking_and_total_amount_is_zero() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: nil, total: "0", paymentMethodID: "wc-booking-gateway")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_visible_if_order_is_a_confirmed_booking_and_total_amount_is_greater_than_zero() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: .some(nil), total: "1", paymentMethodID: "wc-booking-gateway")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }


    func test_collect_payment_button_is_not_visible_if_date_paid_is_not_nil() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: Date(), total: "0", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_visible_if_order_is_eligible_and_currency_is_usd() throws {
        // Given
        let order = makeOrder().copy(status: .processing, currency: "usd", datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_visible_if_order_is_eligible_and_currency_is_in_configuration() throws {
        // Given
        let configuration = CardPresentPaymentsConfiguration(country: "CA", canadaEnabled: true)
        let order = makeOrder().copy(status: .processing, currency: "cad", datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNotNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_order_currency_is_not_in_configuration() throws {
        // Given
        let configuration = CardPresentPaymentsConfiguration(country: "US", canadaEnabled: true)
        let order = makeOrder().copy(status: .processing, currency: "cad", datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_collect_payment_button_is_not_visible_if_order_currency_would_be_in_configuration_but_not_enabled() throws {
        // Given
        let configuration = CardPresentPaymentsConfiguration(country: "CA", canadaEnabled: false)
        let order = makeOrder().copy(status: .processing, currency: "cad", datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: configuration)
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let paymentSection = try section(withTitle: Title.payment, from: dataSource)
        XCTAssertNil(row(row: .collectCardPaymentButton, in: paymentSection))
    }

    func test_create_shipping_label_button_is_visible_for_eligible_order_with_no_labels() throws {
        // Given
        let order = makeOrder()
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        let createShippingLabelRow = row(row: .shippingLabelCreateButton, in: productSection)
        XCTAssertNotNil(createShippingLabelRow)
    }

    func test_create_shipping_label_button_is_visible_for_eligible_order_with_only_refunded_labels() throws {
        // Given
        let order = makeOrder()
        let refundedShippingLabel = ShippingLabel.fake().copy(siteID: order.siteID, orderID: order.orderID, refund: ShippingLabelRefund.fake())
        insert(shippingLabel: refundedShippingLabel)

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        let createShippingLabelRow = row(row: .shippingLabelCreateButton, in: productSection)
        XCTAssertNotNil(createShippingLabelRow)
    }

    func test_create_shipping_label_button_is_not_visible_for_eligible_order_with_labels() throws {
        // Given
        let order = makeOrder()
        let shippingLabel = ShippingLabel.fake().copy(siteID: order.siteID, orderID: order.orderID)
        insert(shippingLabel: shippingLabel)

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        let createShippingLabelRow = row(row: .shippingLabelCreateButton, in: productSection)
        XCTAssertNil(createShippingLabelRow)
    }

    func test_create_shipping_label_button_is_not_visible_for_ineligible_order() throws {
        // Given
        let order = makeOrder()
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = false

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        let createShippingLabelRow = row(row: .shippingLabelCreateButton, in: productSection)
        XCTAssertNil(createShippingLabelRow)
    }

    func test_create_shipping_label_button_is_not_visible_for_cash_on_delivery_order() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true

        // When
        dataSource.configureResultsControllers { }
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        let createShippingLabelRow = row(row: .shippingLabelCreateButton, in: productSection)
        XCTAssertNil(createShippingLabelRow)
    }

    func test_more_button_is_visible_in_product_section_for_eligible_order_without_refunded_labels() throws {
        // Given
        let order = makeOrder()
        let shippingLabel = ShippingLabel.fake().copy(siteID: order.siteID, orderID: order.orderID)
        insert(shippingLabel: shippingLabel)

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        guard case .actionablePrimary = productSection.headerStyle else {
            XCTFail("Product section should show more button on the header for eligible order without refunded labels")
            return
        }
    }

    func test_more_button_is_visible_in_product_section_for_eligible_order_with_refunded_labels() throws {
        // Given
        let order = makeOrder()
        let refundedShippingLabel = ShippingLabel.fake().copy(siteID: order.siteID, orderID: order.orderID, refund: ShippingLabelRefund.fake())
        insert(shippingLabel: refundedShippingLabel)

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        guard case .actionablePrimary = productSection.headerStyle else {
            XCTFail("Product section should show more button on the header for eligible order with refunded labels")
            return
        }
    }

    func test_more_button_is_not_visible_in_product_section_for_eligible_order_without_shipping_labels() throws {
        // Given
        let order = makeOrder()

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        guard case .primary = productSection.headerStyle else {
            XCTFail("Product section should not show button on the header for eligible order without shipping labels")
            return
        }
    }

    func test_more_button_is_not_visible_in_product_section_for_ineligible_order() throws {
        // Given
        let order = makeOrder()

        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = false
        dataSource.configureResultsControllers { }

        // When
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        guard case .primary = productSection.headerStyle else {
            XCTFail("Product section should not show button on the header for ineligible order")
            return
        }
    }

    func test_more_button_is_not_visible_in_product_section_for_cash_on_delivery_order() throws {
        // Given
        let order = makeOrder().copy(status: .processing, datePaid: .some(nil), total: "100", paymentMethodID: "cod")
        let dataSource = OrderDetailsDataSource(order: order, storageManager: storageManager, cardPresentPaymentsConfiguration: Mocks.configuration)
        dataSource.isEligibleForShippingLabelCreation = true

        // When
        dataSource.configureResultsControllers { }
        dataSource.reloadSections()

        // Then
        let productSection = try section(withTitle: Title.products, from: dataSource)
        guard case .primary = productSection.headerStyle else {
            XCTFail("Product section should not show button on the header for cash on delivery order")
            return
        }
    }
}

// MARK: - Test Data

private extension OrderDetailsDataSourceTests {
    func makeOrder() -> Order {
        MockOrders().makeOrder(items: [makeOrderItem(), makeOrderItem()])
    }

    func makeOrderItem() -> OrderItem {
        OrderItem(itemID: 1,
                  name: "Order Item Name",
                  productID: 1_00,
                  variationID: 0,
                  quantity: 1,
                  price: NSDecimalNumber(integerLiteral: 1),
                  sku: nil,
                  subtotal: "1",
                  subtotalTax: "1",
                  taxClass: "TaxClass",
                  taxes: [],
                  total: "1",
                  totalTax: "1",
                  attributes: [])
    }

    func makeRefund(orderID: Int64, siteID: Int64) -> Refund {
        let orderItemRefund = OrderItemRefund(itemID: 1,
                                              name: "OrderItemRefund",
                                              productID: 1,
                                              variationID: 1,
                                              quantity: 1,
                                              price: NSDecimalNumber(integerLiteral: 1),
                                              sku: nil,
                                              subtotal: "1",
                                              subtotalTax: "1",
                                              taxClass: "TaxClass",
                                              taxes: [],
                                              total: "1",
                                              totalTax: "1")
        return Refund(refundID: 1,
                      orderID: orderID,
                      siteID: siteID,
                      dateCreated: Date(),
                      amount: "1",
                      reason: "Reason",
                      refundedByUserID: 1,
                      isAutomated: nil,
                      createAutomated: nil,
                      items: [orderItemRefund],
                      shippingLines: [])
    }

    func insert(refund: Refund) {
        let storageOrderItemRefunds: Set<StorageOrderItemRefund> = Set(refund.items.map { orderItemRefund in
            let storageOrderItemRefund = storage.insertNewObject(ofType: StorageOrderItemRefund.self)
            storageOrderItemRefund.update(with: orderItemRefund)
            return storageOrderItemRefund
        })

        let storageRefund = storage.insertNewObject(ofType: StorageRefund.self)
        storageRefund.update(with: refund)
        storageRefund.addToItems(storageOrderItemRefunds as NSSet)
    }

    /// Inserts the shipping label into storage
    ///
    func insert(shippingLabel: ShippingLabel) {
        let storageShippingLabel = storage.insertNewObject(ofType: StorageShippingLabel.self)
        storageShippingLabel.update(with: shippingLabel)
        if let shippingLabelRefund = shippingLabel.refund {
            let storageRefund = storage.insertNewObject(ofType: StorageShippingLabelRefund.self)
            storageRefund.update(with: shippingLabelRefund)
            storageShippingLabel.refund = storageRefund
        }
    }

    /// Finds first section with a given title from the provided data source.
    ///
    private func section(withTitle title: String, from dataSource: OrderDetailsDataSource) throws -> OrderDetailsDataSource.Section {
        let section = dataSource.sections.first { $0.title == title }
        return try XCTUnwrap(section)
    }

    /// Finds the first row that matches the given row from the provided section.
    ///
    func row(row: OrderDetailsDataSource.Row, in section: OrderDetailsDataSource.Section) -> OrderDetailsDataSource.Row? {
        section.rows.first { $0 == row }
    }
}


private extension OrderDetailsDataSourceTests {
    enum Mocks {
        static let configuration = CardPresentPaymentsConfiguration(country: "US", canadaEnabled: true)
    }
}
