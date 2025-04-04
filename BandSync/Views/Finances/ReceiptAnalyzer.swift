//
//  ReceiptAnalyzer.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


import Foundation
import NaturalLanguage
import Vision

/// Class for analyzing and extracting data from receipt text
class ReceiptAnalyzer {
    
    /// Extracted data from receipt
    struct ReceiptData {
        var amount: Double?
        var date: Date?
        var merchantName: String?
        var category: String?
        var items: [String]
        
        init(amount: Double? = nil, date: Date? = nil, merchantName: String? = nil, category: String? = nil, items: [String] = []) {
            self.amount = amount
            self.date = date
            self.merchantName = merchantName
            self.category = category
            self.items = items
        }
    }
    
    /// Analyze receipt text
    /// - Parameter text: Recognized text from receipt
    /// - Returns: Extracted data
    static func analyze(text: String) -> ReceiptData {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        let amount = extractAmount(from: lines)
        let date = extractDate(from: lines)
        let merchantName = extractMerchantName(from: lines)
        let items = extractItems(from: lines)
        let category = determineCategory(items: items, merchantName: merchantName)
        
        return ReceiptData(
            amount: amount,
            date: date,
            merchantName: merchantName,
            category: category,
            items: items
        )
    }
    
    /// Extract amount from receipt text
    private static func extractAmount(from lines: [String]) -> Double? {
        // Look for lines that may contain the total amount
        let possibleAmountLines = lines.filter { line in
            let lowercased = line.lowercased()
            return lowercased.contains("total") || 
                   lowercased.contains("amount") || 
                   lowercased.contains("sum") ||
                   lowercased.contains("due") ||
                   lowercased.contains("balance") ||
                   lowercased.contains("pay")
        }
        
        // Regex to extract amount values like 123.45
        let amountRegex = try? NSRegularExpression(pattern: "\\d+[.,]\\d{2}", options: [])
        
        // First check lines that most likely contain the total amount
        for line in possibleAmountLines {
            if let amount = extractAmountValue(from: line, using: amountRegex) {
                return amount
            }
        }
        
        // If not found in specific lines, look for a number in any line (often amount is just a number)
        for line in lines.reversed() { // Start from the end, as total is often at the bottom
            if let amount = extractAmountValue(from: line, using: amountRegex) {
                return amount
            }
        }
        
        return nil
    }
    
    /// Extract amount value from a line
    private static func extractAmountValue(from line: String, using regex: NSRegularExpression?) -> Double? {
        guard let regex = regex else { return nil }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        // Find all matches with regex
        let matches = regex.matches(in: line, options: [], range: range)
        
        if let match = matches.last { // Take the last number, as total is often at the end of the line
            let matchedString = nsString.substring(with: match.range)
            // Replace comma with period for correct conversion to Double
            let normalizedString = matchedString.replacingOccurrences(of: ",", with: ".")
            return Double(normalizedString)
        }
        
        // If no matches with regex, try to find numbers another way
        let scanner = Scanner(string: line)
        var amount: Double = 0
        var largestAmount: Double = 0
        
        while scanner.scanDouble(&amount) {
            if amount > largestAmount {
                largestAmount = amount
            }
        }
        
        return largestAmount > 0 ? largestAmount : nil
    }
    
    /// Extract date from receipt text
    private static func extractDate(from lines: [String]) -> Date? {
        // Look for lines that may contain date
        let possibleDateLines = lines.filter { line in
            let lowercased = line.lowercased()
            return lowercased.contains("date") || 
                   lowercased.contains("time") || 
                   lowercased.contains("receipt") ||
                   lowercased.contains("transaction") ||
                   lowercased.contains("purchase")
        }
        
        // Date formats that might be in the receipt
        let dateFormatters: [DateFormatter] = [
            createDateFormatter(format: "MM/dd/yyyy"),
            createDateFormatter(format: "MM/dd/yy"),
            createDateFormatter(format: "dd/MM/yyyy"),
            createDateFormatter(format: "dd/MM/yy"),
            createDateFormatter(format: "yyyy-MM-dd"),
            createDateFormatter(format: "MM-dd-yyyy"),
            createDateFormatter(format: "dd-MM-yyyy"),
            createDateFormatter(format: "MM.dd.yyyy"),
            createDateFormatter(format: "dd.MM.yyyy"),
            createDateFormatter(format: "MMM dd, yyyy"),
            createDateFormatter(format: "MMMM dd, yyyy"),
            createDateFormatter(format: "MM/dd/yyyy HH:mm"),
            createDateFormatter(format: "MM/dd/yy HH:mm")
        ]
        
        // Regex to extract date patterns like MM/DD/YYYY, DD/MM/YYYY, etc.
        let dateRegex = try? NSRegularExpression(pattern: "\\d{1,2}[./-]\\d{1,2}[./-]\\d{2,4}", options: [])
        
        // First check specific lines
        for line in possibleDateLines {
            if let date = extractDateValue(from: line, using: dateRegex, formatters: dateFormatters) {
                return date
            }
        }
        
        // If not found, check all lines
        for line in lines {
            if let date = extractDateValue(from: line, using: dateRegex, formatters: dateFormatters) {
                return date
            }
        }
        
        return nil
    }
    
    /// Create date formatter
    private static func createDateFormatter(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = format
        formatter.locale = Locale(identifier: "en_US")
        return formatter
    }
    
    /// Extract date value from a line
    private static func extractDateValue(from line: String, using regex: NSRegularExpression?, formatters: [DateFormatter]) -> Date? {
        guard let regex = regex else { return nil }
        
        let nsString = line as NSString
        let range = NSRange(location: 0, length: nsString.length)
        
        // Find all matches with regex
        let matches = regex.matches(in: line, options: [], range: range)
        
        for match in matches {
            let matchedString = nsString.substring(with: match.range)
            
            // Try different formats
            for formatter in formatters {
                if let date = formatter.date(from: matchedString) {
                    return date
                }
            }
        }
        
        // Try to find today's or yesterday's date
        let today = Date()
        let calendar = Calendar.current
        
        // If receipt contains "today"
        if line.lowercased().contains("today") {
            return today
        }
        
        // If receipt contains "yesterday"
        if line.lowercased().contains("yesterday") {
            return calendar.date(byAdding: .day, value: -1, to: today)
        }
        
        return nil
    }
    
    /// Extract merchant name from receipt
    private static func extractMerchantName(from lines: [String]) -> String? {
        // Usually merchant name is at the beginning of the receipt
        if !lines.isEmpty {
            // Take first few lines and look for the longest one
            let topLines = Array(lines.prefix(5))
            var merchantName: String?
            var maxLength = 0
            
            for line in topLines {
                // Ignore lines that look like date or address
                if line.contains("/") || line.contains("@") || line.contains("Tel:") ||
                   line.contains("Phone:") || line.contains("Address:") || line.contains("ID:") ||
                   line.lowercased().contains("receipt") {
                    continue
                }
                
                if line.count > maxLength {
                    maxLength = line.count
                    merchantName = line
                }
            }
            
            return merchantName
        }
        
        return nil
    }
    
    /// Extract list of items from receipt
    private static func extractItems(from lines: [String]) -> [String] {
        var items: [String] = []
        var isItemSection = false
        
        // Markers for beginning and end of items section
        let startMarkers = ["item", "description", "product", "quantity", "qty", "price"]
        let endMarkers = ["total", "subtotal", "sub-total", "amount", "balance", "due"]
        
        for line in lines {
            let lowercasedLine = line.lowercased()
            
            // Check for start of items section
            if !isItemSection {
                let isStart = startMarkers.contains { lowercasedLine.contains($0) }
                if isStart {
                    isItemSection = true
                    continue
                }
            }
            
            // Check for end of items section
            if isItemSection {
                let isEnd = endMarkers.contains { lowercasedLine.contains($0) }
                if isEnd {
                    break
                }
                
                // Ignore lines with quantity, price etc.
                if lowercasedLine.contains("qty") || lowercasedLine.contains("x") ||
                   lowercasedLine.contains("$") || lowercasedLine.contains("€") ||
                   (lowercasedLine.contains("quantity") && lowercasedLine.contains("price")) {
                    continue
                }
                
                // Add line as item if it's not empty and long enough
                if !line.isEmpty && line.count > 3 {
                    items.append(line)
                }
            }
        }
        
        // If no items found through markers, try heuristic approach
        if items.isEmpty {
            // Look for lines that look like items (don't contain special words)
            let blockedWords = ["receipt", "store", "date", "time", "total", "amount", 
                              "payment", "cashier", "thank", "you", "discount", "tax",
                              "id", "address", "number", "phone", "welcome", "order"]
            
            for line in lines {
                let lowercasedLine = line.lowercased()
                let containsBlockedWord = blockedWords.contains { lowercasedLine.contains($0) }
                let containsNumber = lowercasedLine.rangeOfCharacter(from: .decimalDigits) != nil
                
                if !containsBlockedWord && !line.isEmpty && line.count > 3 && !containsNumber {
                    items.append(line)
                }
            }
        }
        
        return items
    }
    
    /// Determine category based on items and merchant
    private static func determineCategory(items: [String], merchantName: String?) -> String? {
        // Dictionary of keywords for categories
        let categoryKeywords: [String: [String]] = [
            "Food": ["cafe", "restaurant", "pizza", "sushi", "food", "grocery", "supermarket", 
                     "bread", "milk", "cheese", "meat", "vegetables", "fruits", "bakery", "meal", "burger", "coffee"],
            "Transport": ["taxi", "metro", "bus", "train", "subway", "ticket", "transit", "gas", "fuel", "parking", "uber", "lyft"],
            "Entertainment": ["cinema", "theater", "concert", "exhibition", "museum", "park", "attraction", "movie", "show", "event"],
            "Clothing": ["t-shirt", "pants", "jeans", "jacket", "shoes", "socks", "dress", "shirt", "fashion", "apparel", "wear"],
            "Electronics": ["phone", "computer", "laptop", "headphones", "charger", "cable", "tech", "electronic", "device", "gadget"],
            "Health": ["pharmacy", "medicine", "vitamin", "pill", "tablet", "syrup", "bandage", "drug", "medical", "health"],
            "Utilities": ["mobile", "internet", "phone", "cellular", "telecom", "utility", "bill", "service"],
            "Housing": ["rent", "utilities", "electric", "gas", "water", "heating", "housing", "apartment", "maintenance"]
        ]
        
        // Count matches for each category
        var categoryMatches: [String: Int] = [:]
        
        // Check merchant name
        if let merchant = merchantName?.lowercased() {
            for (category, keywords) in categoryKeywords {
                for keyword in keywords {
                    if merchant.contains(keyword) {
                        categoryMatches[category, default: 0] += 3 // Merchant name has higher weight
                    }
                }
            }
        }
        
        // Check items
        for item in items {
            let lowercasedItem = item.lowercased()
            for (category, keywords) in categoryKeywords {
                for keyword in keywords {
                    if lowercasedItem.contains(keyword) {
                        categoryMatches[category, default: 0] += 1
                    }
                }
            }
        }
        
        // Find best matching category
        let sortedCategories = categoryMatches.sorted { $0.value > $1.value }
        return sortedCategories.first?.key
    }
}