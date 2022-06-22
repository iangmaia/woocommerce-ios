import Combine
import struct Yosemite.ProductImage
import enum Yosemite.ProductAction
import protocol Yosemite.StoresManager

struct ProductImageUploadUpdate {
    let siteID: Int64
    let productID: Int64
    let productImageStatuses: [ProductImageStatus]
    let error: Error?
}

/// Handles product image upload to support background image upload.
protocol ProductImageUploaderProtocol {
    var statusUpdates: AnyPublisher<ProductImageUploadUpdate, Never> { get }

    /// Called for product image upload use cases (e.g. product/variation form, downloadable product list).
    /// - Parameters:
    ///   - siteID: the ID of the site where images are uploaded to.
    ///   - productID: the ID of the product where images are added to.
    ///   - isLocalID: whether the product ID is a local ID like in product creation.
    ///   - originalStatuses: the current image statuses of the product for initialization.
    func actionHandler(siteID: Int64, productID: Int64, isLocalID: Bool, originalStatuses: [ProductImageStatus]) -> ProductImageActionHandler

    /// Replaces the local ID of the product with the remote ID from API.
    ///
    /// Called in "Add product" flow as soon as the product is saved in the API.
    ///
    /// Replacing product ID is necessary to update the product with the images that are already uploaded without product ID.
    /// Note that the images start uploading even before the product is created in API.
    ///
    /// - Parameters:
    ///   - siteID: The ID of the site to which images are uploaded to.
    ///   - localProductID: A temporary local ID of the product.
    ///   - remoteProductID: Remote product ID received from API.
    func replaceLocalID(siteID: Int64, localProductID: Int64, remoteProductID: Int64)

    /// Saves the product remotely with the images after none is pending upload.
    /// - Parameters:
    ///   - siteID: the ID of the site where images are uploaded to.
    ///   - productID: the ID of the product where images are added to.
    ///   - isLocalID: whether the product ID is a local ID like in product creation.
    ///   - onProductSave: called after the product is saved remotely with the uploaded images.
    func saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: Int64,
                                                         productID: Int64,
                                                         isLocalID: Bool,
                                                         onProductSave: @escaping (Result<[ProductImage], Error>) -> Void)

    func startEmittingStatusUpdates(siteID: Int64, productID: Int64, isLocalID: Bool)
    func stopEmittingStatusUpdates(siteID: Int64, productID: Int64, isLocalID: Bool)

    /// Determines whether there are unsaved changes on a product's images.
    /// If the product had any save request before, it checks whether the image statuses to save match the latest image statuses.
    /// Otherwise, it checks whether there is any pending upload or the image statuses match the given original image statuses.
    /// - Parameters:
    ///   - siteID: the ID of the site where images are uploaded to.
    ///   - productID: the ID of the product where images are added to.
    ///   - isLocalID: whether the product ID is a local ID like in product creation.
    ///   - originalImages: the image statuses before any edits.
    func hasUnsavedChangesOnImages(siteID: Int64, productID: Int64, isLocalID: Bool, originalImages: [ProductImage]) -> Bool
}

/// Supports background image upload and product images update after the user leaves the product form.
final class ProductImageUploader: ProductImageUploaderProtocol {
    var statusUpdates: AnyPublisher<ProductImageUploadUpdate, Never> {
        statusUpdatesSubject.eraseToAnyPublisher()
    }

    private let statusUpdatesSubject: PassthroughSubject<ProductImageUploadUpdate, Never> = .init()
    private var statusUpdatesExcludedProductKeys: Set<ProductKey> = []
    private var statusUpdatesSubscriptions: Set<AnyCancellable> = []

    private struct ProductKey: Equatable, Hashable {
        let siteID: Int64
        let productID: Int64
        let isLocalID: Bool
    }

    private var actionHandlersByProduct: [ProductKey: ProductImageActionHandler] = [:]
    private var imagesSaverByProduct: [ProductKey: ProductImagesSaver] = [:]
    private let stores: StoresManager

    init(stores: StoresManager = ServiceLocator.stores) {
        self.stores = stores
    }

    func actionHandler(siteID: Int64, productID: Int64, isLocalID: Bool, originalStatuses: [ProductImageStatus]) -> ProductImageActionHandler {
        let key = ProductKey(siteID: siteID, productID: productID, isLocalID: isLocalID)
        let actionHandler: ProductImageActionHandler
        if let handler = actionHandlersByProduct[key], handler.productImageStatuses.hasPendingUpload {
            actionHandler = handler
        } else {
            actionHandler = ProductImageActionHandler(siteID: siteID, productID: productID, imageStatuses: originalStatuses, stores: stores)
            actionHandlersByProduct[key] = actionHandler
            observeStatusUpdatesToUpdateProduct(key: key, actionHandler: actionHandler)
        }
        return actionHandler
    }

    func replaceLocalID(siteID: Int64, localProductID: Int64, remoteProductID: Int64) {
        let key = ProductKey(siteID: siteID, productID: localProductID, isLocalID: true)
        guard let handler = actionHandlersByProduct[key] else {
            return
        }
        actionHandlersByProduct.removeValue(forKey: key)
        let keyWithRemoteProductID = ProductKey(siteID: siteID, productID: remoteProductID, isLocalID: false)
        actionHandlersByProduct[keyWithRemoteProductID] = handler
    }

    func startEmittingStatusUpdates(siteID: Int64, productID: Int64, isLocalID: Bool) {
        let key = ProductKey(siteID: siteID, productID: productID, isLocalID: isLocalID)
        statusUpdatesExcludedProductKeys.remove(key)
    }

    func stopEmittingStatusUpdates(siteID: Int64, productID: Int64, isLocalID: Bool) {
        let key = ProductKey(siteID: siteID, productID: productID, isLocalID: isLocalID)
        statusUpdatesExcludedProductKeys.insert(key)
    }

    func hasUnsavedChangesOnImages(siteID: Int64, productID: Int64, isLocalID: Bool, originalImages: [ProductImage]) -> Bool {
        let key = ProductKey(siteID: siteID, productID: productID, isLocalID: isLocalID)
        guard let handler = actionHandlersByProduct[key] else {
            return false
        }
        if let productImagesSaver = imagesSaverByProduct[key], productImagesSaver.imageStatusesToSave.isNotEmpty {
            // If there are images scheduled to be saved, there are no unsaved changes if the image statuses to save match the latest image statuses.
            return handler.productImageStatuses != productImagesSaver.imageStatusesToSave
        } else {
            // Otherwise, there are unsaved changes if there is any pending image upload or any difference in the remote image IDs between the
            // original and latest product.
            return handler.productImageStatuses.hasPendingUpload ||
            handler.productImageStatuses.images.map { $0.imageID } != originalImages.map { $0.imageID }
        }
    }

    func saveProductImagesWhenNoneIsPendingUploadAnymore(siteID: Int64,
                                                         productID: Int64,
                                                         isLocalID: Bool,
                                                         onProductSave: @escaping (Result<[ProductImage], Error>) -> Void) {
        // The product has to exist remotely in order to save its images remotely.
        // In product creation, this save function should be called after a new product is saved remotely for the first time.
        guard isLocalID == false else {
            return
        }
        let key = ProductKey(siteID: siteID, productID: productID, isLocalID: isLocalID)
        guard let handler = actionHandlersByProduct[key], handler.productImageStatuses.hasPendingUpload else {
            return
        }
        let imagesSaver: ProductImagesSaver
        if let productImagesSaver = imagesSaverByProduct[key] {
            imagesSaver = productImagesSaver
        } else {
            imagesSaver = ProductImagesSaver(siteID: siteID, productID: productID, stores: stores)
            imagesSaverByProduct[key] = imagesSaver
        }
        imagesSaver.saveProductImagesWhenNoneIsPendingUploadAnymore(imageActionHandler: handler, onProductSave: onProductSave)
    }
}

private extension ProductImageUploader {
    private func observeStatusUpdatesToUpdateProduct(key: ProductKey, actionHandler: ProductImageActionHandler) {
        let observationToken = actionHandler.addUpdateObserver(self) { [weak self] (productImageStatuses, error) in
            guard let self = self else { return }

            if let error = error, self.statusUpdatesExcludedProductKeys.contains(key) == false {
                self.statusUpdatesSubject.send(.init(siteID: key.siteID, productID: key.productID, productImageStatuses: productImageStatuses, error: error))
            }
        }
        statusUpdatesSubscriptions.insert(observationToken)
    }
}
