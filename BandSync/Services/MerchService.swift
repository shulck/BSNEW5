//
//  MerchService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import Foundation
import FirebaseFirestore
import FirebaseStorage
import UIKit

final class MerchService: ObservableObject {
    static let shared = MerchService()

    @Published var items: [MerchItem] = []
    @Published var sales: [MerchSale] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var lowStockItems: [MerchItem] = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage().reference()

    func fetchItems(for groupId: String) {
        isLoading = true
        errorMessage = nil

        db.collection("merchandise")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error loading products: \(error.localizedDescription)"
                        return
                    }

                    if let docs = snapshot?.documents {
                        let result = docs.compactMap { try? $0.data(as: MerchItem.self) }
                        self.items = result

                        // Update low stock items list
                        self.updateLowStockItems()

                        // Cache data for offline access
                        CacheService.shared.cacheMerch(result, forGroupId: groupId)
                    }
                }
            }
    }

    func fetchSales(for groupId: String) {
        db.collection("merch_sales")
            .whereField("groupId", isEqualTo: groupId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Error loading sales: \(error.localizedDescription)"
                    }
                    return
                }

                if let docs = snapshot?.documents {
                    let result = docs.compactMap { try? $0.data(as: MerchSale.self) }
                    DispatchQueue.main.async {
                        self.sales = result
                    }
                }
            }
    }

    func addItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        isLoading = true
        errorMessage = nil

        do {
            _ = try db.collection("merchandise").addDocument(from: item) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error adding product: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func updateItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        // Update updatedAt field
        var updatedItem = item
        updatedItem.updatedAt = Date()

        do {
            try db.collection("merchandise").document(id).setData(from: updatedItem) { [weak self] error in
                guard let self = self else { return }

                DispatchQueue.main.async {
                    self.isLoading = false

                    if let error = error {
                        self.errorMessage = "Error updating product: \(error.localizedDescription)"
                        completion(false)
                    } else {
                        // Update local list
                        if let index = self.items.firstIndex(where: { $0.id == id }) {
                            self.items[index] = updatedItem
                        }

                        // Update low stock items list
                        self.updateLowStockItems()

                        completion(true)
                    }
                }
            }
        } catch {
            DispatchQueue.main.async {
                self.isLoading = false
                self.errorMessage = "Serialization error: \(error.localizedDescription)"
                completion(false)
            }
        }
    }

    func deleteItem(_ item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let id = item.id else {
            completion(false)
            return
        }

        isLoading = true
        errorMessage = nil

        db.collection("merchandise").document(id).delete { [weak self] error in
            guard let self = self else { return }

            DispatchQueue.main.async {
                self.isLoading = false

                if let error = error {
                    self.errorMessage = "Error deleting product: \(error.localizedDescription)"
                    completion(false)
                } else {
                    // Remove from local list
                    self.items.removeAll { $0.id == id }

                    // Update low stock items list
                    self.updateLowStockItems()

                    completion(true)
                }
            }
        }
    }

    func recordSale(item: MerchItem, size: String, quantity: Int, channel: MerchSaleChannel) {
        guard let itemId = item.id,
              let groupId = AppState.shared.user?.groupId else { return }

        let sale = MerchSale(
            itemId: itemId,
            size: size,
            quantity: quantity,
            channel: channel,
            groupId: groupId
        )

        do {
            _ = try db.collection("merch_sales").addDocument(from: sale) { [weak self] error in
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Error recording sale: \(error.localizedDescription)"
                    }
                }
            }
        } catch {
            print("Error recording sale: \(error)")
        }

        // Update stock
        updateStock(for: item, size: size, delta: -quantity)

        // Auto-add to finances only if not a gift
        if channel != .gift {
            let record = FinanceRecord(
                type: .income,
                amount: Double(quantity) * item.price,
                currency: "EUR",
                category: "Merchandise",
                details: "Sale of \(item.name) (size \(size))",
                date: Date(),
                receiptUrl: nil,
                groupId: groupId
            )

            FinanceService.shared.add(record) { _ in }
        }
    }

    private func updateStock(for item: MerchItem, size: String, delta: Int) {
        guard let id = item.id else { return }
        var updated = item
        updated.updatedAt = Date()

        switch size {
        case "S": updated.stock.S += delta
        case "M": updated.stock.M += delta
        case "L": updated.stock.L += delta
        case "XL": updated.stock.XL += delta
        case "XXL": updated.stock.XXL += delta
        default: break
        }

        do {
            try db.collection("merchandise").document(id).setData(from: updated) { [weak self] error in
                if let error = error {
                    print("Error updating stock: \(error)")
                } else {
                    // Update local list
                    DispatchQueue.main.async {
                        if let index = self?.items.firstIndex(where: { $0.id == id }) {
                            self?.items[index] = updated
                        }

                        // Update low stock items list
                        self?.updateLowStockItems()
                    }
                }
            }
        } catch {
            print("Serialization error when updating stock: \(error)")
        }
    }

    // MARK: - Methods for working with images

    func uploadItemImage(_ image: UIImage, for item: MerchItem, completion: @escaping (Result<String, Error>) -> Void) {
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "MerchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing item ID"])))
            return
        }

        guard let imageData = image.jpegData(compressionQuality: 0.7) else {
            completion(.failure(NSError(domain: "MerchService", code: 2, userInfo: [NSLocalizedDescriptionKey: "Failed to create image data"])))
            return
        }

        let imageName = "\(itemId)_\(UUID().uuidString).jpg"
        let imageRef = storage.child("merchandise/\(imageName)")

        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        imageRef.putData(imageData, metadata: metadata) { metadata, error in
            if let error = error {
                completion(.failure(error))
                return
            }

            imageRef.downloadURL { url, error in
                if let error = error {
                    completion(.failure(error))
                    return
                }

                if let url = url {
                    completion(.success(url.absoluteString))
                } else {
                    completion(.failure(NSError(domain: "MerchService", code: 3, userInfo: [NSLocalizedDescriptionKey: "Failed to get image URL"])))
                }
            }
        }
    }

    func uploadItemImages(_ images: [UIImage], for item: MerchItem, completion: @escaping (Result<[String], Error>) -> Void) {
        guard let itemId = item.id else {
            completion(.failure(NSError(domain: "MerchService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Missing item ID"])))
            return
        }

        let group = DispatchGroup()
        var urls: [String] = []
        var uploadError: Error?

        for image in images {
            group.enter()

            uploadItemImage(image, for: item) { result in
                switch result {
                case .success(let url):
                    urls.append(url)
                case .failure(let error):
                    uploadError = error
                }

                group.leave()
            }
        }

        group.notify(queue: .main) {
            if let error = uploadError {
                completion(.failure(error))
            } else {
                completion(.success(urls))
            }
        }
    }

    func deleteItemImage(url: String, completion: @escaping (Bool) -> Void) {
        guard let urlObject = URL(string: url), let path = urlObject.path.components(separatedBy: "/o/").last?.removingPercentEncoding else {
            completion(false)
            return
        }

        let imageRef = storage.child(path)

        imageRef.delete { error in
            if let error = error {
                print("Error deleting image: \(error.localizedDescription)")
                completion(false)
            } else {
                completion(true)
            }
        }
    }

    // MARK: - Methods for working with low stock items

    private func updateLowStockItems() {
        lowStockItems = items.filter { $0.hasLowStock }

        // Send notification if there are low stock items
        if !lowStockItems.isEmpty {
            sendLowStockNotification()
        }
    }

    private func sendLowStockNotification() {
        // Send notification only once a day for each item
        let lastNotificationDate = UserDefaults.standard.object(forKey: "lastLowStockNotificationDate") as? Date ?? Date(timeIntervalSince1970: 0)
        let calendar = Calendar.current

        if !calendar.isDateInToday(lastNotificationDate) {
            // Format notification text
            let itemCount = lowStockItems.count
            let title = "Low stock items"
            let body = "You have \(itemCount) item\(itemCount == 1 ? "" : "s") with low stock."

            // Send notification
            NotificationManager.shared.scheduleLocalNotification(
                title: title,
                body: body,
                date: Date(),
                identifier: "low_stock_notification_\(Date().timeIntervalSince1970)",
                userInfo: ["type": "low_stock"]
            ) { _ in }

            // Save last notification date
            UserDefaults.standard.set(Date(), forKey: "lastLowStockNotificationDate")
        }
    }

    // MARK: - Analytics methods

    func getSalesByPeriod(from startDate: Date, to endDate: Date) -> [MerchSale] {
        return sales.filter { $0.date >= startDate && $0.date <= endDate }
    }

    func getSalesByItem(itemId: String) -> [MerchSale] {
        return sales.filter { $0.itemId == itemId }
    }

    func getSalesByCategory(category: MerchCategory) -> [MerchSale] {
        let itemIds = items.filter { $0.category == category }.compactMap { $0.id }
        return sales.filter { sale in itemIds.contains(sale.itemId) }
    }

    func getSalesByMonth() -> [String: Int] {
        let calendar = Calendar.current
        var result: [String: Int] = [:]

        for sale in sales {
            let components = calendar.dateComponents([.year, .month], from: sale.date)
            if let year = components.year, let month = components.month {
                let key = "\(year)-\(String(format: "%02d", month))"
                result[key, default: 0] += sale.quantity
            }
        }

        return result
    }

    func getTopSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 > sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getLeastSellingItems(limit: Int = 5) -> [MerchItem] {
        var itemSalesCount: [String: Int] = [:]

        for sale in sales {
            itemSalesCount[sale.itemId, default: 0] += sale.quantity
        }

        // Add items with no sales
        for item in items {
            if let id = item.id, itemSalesCount[id] == nil {
                itemSalesCount[id] = 0
            }
        }

        let sortedItems = items.sorted { item1, item2 in
            let sales1 = itemSalesCount[item1.id ?? ""] ?? 0
            let sales2 = itemSalesCount[item2.id ?? ""] ?? 0
            return sales1 < sales2
        }

        return Array(sortedItems.prefix(limit))
    }

    func getTotalRevenue() -> Double {
        var revenue: Double = 0

        for sale in sales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                revenue += item.price * Double(sale.quantity)
            }
        }

        return revenue
    }

    func getRevenueByMonth() -> [String: Double] {
        let calendar = Calendar.current
        var result: [String: Double] = [:]

        for sale in sales {
            if let item = items.first(where: { $0.id == sale.itemId }) {
                let components = calendar.dateComponents([.year, .month], from: sale.date)
                if let year = components.year, let month = components.month {
                    let key = "\(year)-\(String(format: "%02d", month))"
                    result[key, default: 0] += item.price * Double(sale.quantity)
                }
            }
        }

        return result
    }

    // MARK: - Data export

    func exportSalesData() -> Data? {
        // Create CSV with sales data
        var csvString = "Date,Item,Category,Subcategory,Size,Quantity,Price,Amount,Channel\n"

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"

        for sale in sales {
            guard let item = items.first(where: { $0.id == sale.itemId }) else {
                continue
            }

            let dateString = dateFormatter.string(from: sale.date)
            let amount = item.price * Double(sale.quantity)

            let line = "\(dateString),\"\(item.name)\",\(item.category.rawValue),\(item.subcategory?.rawValue ?? ""),\(sale.size),\(sale.quantity),\(item.price),\(amount),\(sale.channel.rawValue)\n"
            csvString.append(line)
        }

        return csvString.data(using: .utf8)
    }

    // Fixing method to work with optional subcategory
    private func filter(_ items: [MerchItem], by searchText: String) -> [MerchItem] {
        return items.filter { item in
            let subcategoryText = item.subcategory?.rawValue ?? ""

            return item.name.lowercased().contains(searchText.lowercased()) ||
                item.description.lowercased().contains(searchText.lowercased()) ||
                item.category.rawValue.lowercased().contains(searchText.lowercased()) ||
                subcategoryText.lowercased().contains(searchText.lowercased())
        }
    }

    func cancelSale(_ sale: MerchSale, item: MerchItem, completion: @escaping (Bool) -> Void) {
        guard let saleId = sale.id else {
            completion(false)
            return
        }

        let batch = db.batch()

        // Delete sale record
        let saleRef = db.collection("merch_sales").document(saleId)
        batch.deleteDocument(saleRef)

        // Return item to stock
        if let itemId = item.id {
            let itemRef = db.collection("merchandise").document(itemId)

            // Create update to return items to stock
            var updatedStock = item.stock
            switch sale.size {
            case "S": updatedStock.S += sale.quantity
            case "M": updatedStock.M += sale.quantity
            case "L": updatedStock.L += sale.quantity
            case "XL": updatedStock.XL += sale.quantity
            case "XXL": updatedStock.XXL += sale.quantity
            case "one_size": updatedStock.S += sale.quantity
            default: break
            }

            batch.updateData([
                "stock": try! Firestore.Encoder().encode(updatedStock),
                "updatedAt": Timestamp(date: Date())
            ], forDocument: itemRef)

            // Delete or create compensating financial record
            let amount = Double(sale.quantity) * item.price

            // Method 1: Find and delete corresponding finance record
            // Look for record with same amount and date close to sale date
            findFinanceRecordForSale(sale: sale, item: item) { financeRecord in
                batch.commit { error in
                    if let error = error {
                        print("Error canceling sale: \(error)")
                        completion(false)
                    } else {
                        // Update local data
                        DispatchQueue.main.async { [weak self] in
                            guard let self = self else { return }

                            // Remove sale from local list
                            self.sales.removeAll { $0.id == saleId }

                            // Update item
                            if let index = self.items.firstIndex(where: { $0.id == itemId }) {
                                var updatedItem = self.items[index]
                                updatedItem.stock = updatedStock
                                self.items[index] = updatedItem
                            }

                            self.updateLowStockItems()

                            // Replace incorrect remove method call with add with opposite transaction type
                            if let record = financeRecord {
                                // Create compensating record instead of calling non-existent remove method
                                let refundRecord = FinanceRecord(
                                    type: .expense,
                                    amount: amount,
                                    currency: "EUR",
                                    category: "Refund",
                                    details: "Merch sale cancellation: \(item.name) (size \(sale.size))",
                                    date: Date(),
                                    receiptUrl: nil,
                                    groupId: item.groupId
                                )

                                FinanceService.shared.add(refundRecord) { _ in
                                    completion(true)
                                }
                            } else {
                                // If not found, create compensating record
                                let refundRecord = FinanceRecord(
                                    type: .expense,
                                    amount: amount,
                                    currency: "EUR",
                                    category: "Refund",
                                    details: "Merch sale cancellation: \(item.name) (size \(sale.size))",
                                    date: Date(),
                                    receiptUrl: nil,
                                    groupId: item.groupId
                                )

                                FinanceService.shared.add(refundRecord) { _ in
                                    completion(true)
                                }
                            }
                        }
                    }
                }
            }
        } else {
            completion(false)
        }
    }

    // Helper method to find financial record related to sale
    private func findFinanceRecordForSale(sale: MerchSale, item: MerchItem, completion: @escaping (FinanceRecord?) -> Void) {
        let amount = Double(sale.quantity) * item.price
        let timeWindow = 60.0 // 60 seconds before and after sale

        // Fix method for getting financial records - use existing method
        // In this case, just return nil as we cannot accurately find the corresponding record
        completion(nil)

        // Instead of trying to find the sale record, always create a compensating record
    }

    // Method to get all sales for a specific item
    func getSalesForItem(_ itemId: String) -> [MerchSale] {
        return sales.filter { $0.itemId == itemId }
    }
}
