import Foundation
import Combine
import UIKit  // Adding UIKit import

class OfflineFinanceManager {
    static let shared = OfflineFinanceManager()

    private let cacheKey = "cached_finance_records"
    private let pendingUploadsKey = "pending_finance_uploads"
    private var cancellables = Set<AnyCancellable>()
    private var isConnected = true
    private var syncTimer: Timer?

    private init() {
        setupNetworkMonitoring()
        startSyncTimer()
    }

    // Network connection monitoring
    private func setupNetworkMonitoring() {
        // In a real app, Network.framework or Reachability would be used here
        // For example, we simply simulate network operations
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.checkConnection()
            }
            .store(in: &cancellables)
    }

    private func checkConnection() {
        // In a real app, connection check would be here
        // For example, we simply simulate network operations
        isConnected = true
        if isConnected {
            syncPendingUploads()
        }
    }

    // Periodic synchronization
    private func startSyncTimer() {
        syncTimer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
            self?.checkConnection()
        }
    }

    // Caching records
    func cacheRecord(_ record: FinanceRecord) {
        var cachedRecords = getCachedRecords()
        cachedRecords.append(record)

        if let encoded = try? JSONEncoder().encode(cachedRecords) {
            UserDefaults.standard.set(encoded, forKey: cacheKey)
        }
    }

    // Getting cached records
    func getCachedRecords() -> [FinanceRecord] {
        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) {
            return records
        }
        return []
    }

    // Add record to upload queue
    func addToPendingUploads(_ record: FinanceRecord) {
        var pendingUploads = getPendingUploads()
        pendingUploads.append(record)

        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: pendingUploadsKey)
        }

        // If connected, try to synchronize
        if isConnected {
            syncPendingUploads()
        }
    }

    // Get pending upload records
    func getPendingUploads() -> [FinanceRecord] {
        if let data = UserDefaults.standard.data(forKey: pendingUploadsKey),
           let records = try? JSONDecoder().decode([FinanceRecord].self, from: data) {
            return records
        }
        return []
    }

    // Safe record synchronization
    func syncPendingUploads() {
        let pendingUploads = getPendingUploads()
        guard !pendingUploads.isEmpty else { return }

        // Safer record processing
        for record in pendingUploads {
            DispatchQueue.main.async {
                FinanceService.shared.add(record) { [weak self] success in
                    if success {
                        self?.removePendingUpload(record)
                    }
                }
            }
        }
    }

    // Remove synchronized record from queue
    private func removePendingUpload(_ record: FinanceRecord) {
        var pendingUploads = getPendingUploads()
        pendingUploads.removeAll { $0.id == record.id }

        if let encoded = try? JSONEncoder().encode(pendingUploads) {
            UserDefaults.standard.set(encoded, forKey: pendingUploadsKey)
        }
    }

    // Clear cache
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
    }
}

// FinanceService extension for cache operations
extension FinanceService {
    func loadCachedRecordsIfNeeded() {
        // If there are no or few records, add cached ones
        if self.records.count < 5 {
            let cachedRecords = OfflineFinanceManager.shared.getCachedRecords()
            if !cachedRecords.isEmpty {
                self.records.append(contentsOf: cachedRecords)
            }
        }
    }
}
