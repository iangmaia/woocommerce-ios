import XCTest

@testable import WooCommerce
@testable import Yosemite
@testable import Networking


/// Tests for `EditProductCategoryListViewModel`.
///
final class EditProductCategoryListViewModelTests: XCTestCase {

    func testAddAndSelectNewCategory() {
        // Given
        let product = Product.fake()
        let viewModel = EditProductCategoryListViewModel(product: product, baseProductCategoryListViewModel: ProductCategoryListViewModel(siteID: 1))
        let newCategory = sampleCategory(categoryID: 1234, name: "Test")

        // When
        viewModel.addAndSelectNewCategory(category: newCategory)

        // Then
        XCTAssertEqual(viewModel.selectedCategories.first, newCategory)
    }
}

private extension ProductCategoryListViewModelTests {
    func sampleCategories(count: Int64) -> [ProductCategory] {
        return (0..<count).map {
            return sampleCategory(categoryID: $0, name: String($0))
        }
    }

    func sampleCategory(categoryID: Int64, name: String) -> ProductCategory {
        return ProductCategory(categoryID: categoryID, siteID: 123, parentID: 0, name: name, slug: "")
    }
}

private extension EditProductCategoryListViewModelTests {
    func sampleCategories(count: Int64) -> [ProductCategory] {
        return (0..<count).map {
            return sampleCategory(categoryID: $0, name: String($0))
        }
    }

    func sampleCategory(categoryID: Int64, name: String) -> ProductCategory {
        return ProductCategory(categoryID: categoryID, siteID: 123, parentID: 0, name: name, slug: "")
    }
}
