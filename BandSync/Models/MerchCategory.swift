import Foundation
import FirebaseFirestore

enum MerchCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    case clothing = "Clothing"
    case music = "Music"
    case accessory = "Accessories"
    case other = "Other"

    // Adding icon property
    var icon: String {
        switch self {
        case .clothing: return "tshirt"
        case .music: return "music.note"
        case .accessory: return "bag"
        case .other: return "ellipsis.circle"
        }
    }
}

struct MerchSizeStock: Codable {
    var S: Int = 0
    var M: Int = 0
    var L: Int = 0
    var XL: Int = 0
    var XXL: Int = 0

    init(S: Int = 0, M: Int = 0, L: Int = 0, XL: Int = 0, XXL: Int = 0) {
        self.S = S
        self.M = M
        self.L = L
        self.XL = XL
        self.XXL = XXL
    }

    // Total quantity
    var total: Int {
        return S + M + L + XL + XXL
    }

    // Check for low stock - logic changed according to requirement
    func hasLowStock(threshold: Int) -> Bool {
        // For items with total quantity less than 50, use regular threshold
        if total < 50 {
            // For clothing, check each size
            return S <= threshold || M <= threshold || L <= threshold || XL <= threshold || XXL <= threshold
        } else {
            // For items with total quantity greater than or equal to 50, 
            // consider low stock if total does not exceed 50
            return false
        }
    }
}

struct MerchItem: Identifiable, Codable {
    @DocumentID var id: String?

    var name: String
    var description: String
    var price: Double
    var category: MerchCategory
    var subcategory: MerchSubcategory?
    var stock: MerchSizeStock
    var groupId: String
    var imageURL: String?
    var imageUrls: [String]?
    var lowStockThreshold: Int = 3
    var updatedAt: Date = Date()
    var createdAt: Date = Date()

    // Computed properties
    var totalStock: Int {
        return stock.total
    }

    var hasLowStock: Bool {
        // If total quantity >= 50, always consider stock sufficient
        if totalStock >= 10 {
            return false
        }
        // Otherwise check using regular logic
        return stock.hasLowStock(threshold: lowStockThreshold)
    }
}
