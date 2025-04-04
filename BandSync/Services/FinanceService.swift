//
//  FinanceService.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import Foundation
import FirebaseFirestore


final class FinanceService: ObservableObject {
    static let shared = FinanceService()

    @Published var records: [FinanceRecord] = []

    private let db = Firestore.firestore()

    func fetch(for groupId: String) {
        db.collection("finances")
            .whereField("groupId", isEqualTo: groupId)
            .order(by: "date", descending: true)
            .getDocuments { [weak self] snapshot, error in
                if let docs = snapshot?.documents {
                    let items = docs.compactMap { try? $0.data(as: FinanceRecord.self) }
                    DispatchQueue.main.async {
                        self?.records = items
                    }
                } else {
                    print("Error loading finances: \(error?.localizedDescription ?? "unknown")")
                }
            }
    }

    func add(_ record: FinanceRecord, completion: @escaping (Bool) -> Void) {
        do {
            _ = try db.collection("finances").addDocument(from: record) { error in
                if let error = error {
                    print("Error adding: \(error.localizedDescription)")
                    completion(false)
                } else {
                    self.fetch(for: record.groupId)
                    completion(true)
                }
            }
        } catch {
            print("Serialization error: \(error)")
            completion(false)
        }
    }

    func delete(_ record: FinanceRecord) {
        guard !record.id.isEmpty else { return }
        db.collection("finances").document(record.id).delete { error in
            if let error = error {
                print("Error deleting: \(error.localizedDescription)")
            } else if let groupId = AppState.shared.user?.groupId {
                self.fetch(for: groupId)
            }
        }
    }

    var totalIncome: Double {
        records.filter { $0.type == .income }.reduce(0) { $0 + $1.amount }
    }

    var totalExpense: Double {
        records.filter { $0.type == .expense }.reduce(0) { $0 + $1.amount }
    }

    var profit: Double {
        totalIncome - totalExpense
    }
}
