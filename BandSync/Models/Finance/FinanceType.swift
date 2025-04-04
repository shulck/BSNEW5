// FinanceModel.swift
// Combined models: types and categories

import Foundation

// MARK: - Operation type
enum FinanceType: String, Codable, CaseIterable, Identifiable {
    case income = "Income"
    case expense = "Expense"

    var id: String { rawValue }
}

// MARK: - Category
enum FinanceCategory: String, Codable, CaseIterable, Identifiable {
    var id: String { rawValue }

    // Expenses
    case logistics = "Logistics"
    case accommodation = "Accommodation"
    case food = "Food"
    case gear = "Equipment"
    case promo = "Promotion"
    case other = "Other"

    // Income
    case performance = "Performances"
    case merch = "Merchandise"
    case royalties = "Royalties"
    case sponsorship = "Sponsorship"

    static func forType(_ type: FinanceType) -> [FinanceCategory] {
        switch type {
        case .income:
            return [.performance, .merch, .royalties, .sponsorship, .other]
        case .expense:
            return [.logistics, .accommodation, .food, .gear, .promo, .other]
        }
    }
}
