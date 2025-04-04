//
//  MerchSalesAnalyticsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 02.04.2025.
//


//
//  MerchSalesAnalyticsView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI
import Charts

struct MerchSalesAnalyticsView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var selectedTimeFrame: TimeFrame = .month
    @State private var selectedCategoryFilter: MerchCategory? = nil
    @State private var showingItemDetail = false
    @State private var selectedItemId: String? = nil

    // Time frames for analysis
    enum TimeFrame: String, CaseIterable, Identifiable {
        case week = "Week"
        case month = "Month"
        case quarter = "Quarter"
        case year = "Year"
        case all = "All time"

        var id: String { self.rawValue }

        var days: Int {
            switch self {
            case .week: return 7
            case .month: return 30
            case .quarter: return 90
            case .year: return 365
            case .all: return 3650 // ~10 years
            }
        }
    }

    // Data for charts
    struct SalesChartPoint {
        var date: Date
        var amount: Int
    }

    struct CategorySalesData {
        var category: String
        var sales: Int
    }

    var body: some View {
        NavigationView {
            List {
                // Filters
                Section {
                    Picker("Period", selection: $selectedTimeFrame) {
                        ForEach(TimeFrame.allCases) { timeFrame in
                            Text(timeFrame.rawValue).tag(timeFrame)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())

                    Menu {
                        Button("All categories") {
                            selectedCategoryFilter = nil
                        }

                        ForEach(MerchCategory.allCases) { category in
                            Button(category.rawValue) {
                                selectedCategoryFilter = category
                            }
                        }
                    } label: {
                        HStack {
                            Text("Category: \(selectedCategoryFilter?.rawValue ?? "All")")
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                    }
                }

                // Sales summary
                Section(header: Text("Sales summary")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total revenue")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(totalRevenue(), specifier: "%.0f") EUR")
                                .font(.title2)
                                .bold()
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Units sold")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(totalSoldItems())")
                                .font(.title2)
                                .bold()
                        }
                    }
                    .padding(.vertical, 5)

                    // Sales chart
                    VStack(alignment: .leading) {
                        Text("Sales dynamics")
                            .font(.caption)
                            .foregroundColor(.gray)

                        if #available(iOS 16.0, *) {
                            Chart(salesChartData(), id: \.date) { item in
                                LineMark(
                                    x: .value("Date", item.date),
                                    y: .value("Sales", item.amount)
                                )
                                .foregroundStyle(.blue)

                                PointMark(
                                    x: .value("Date", item.date),
                                    y: .value("Sales", item.amount)
                                )
                                .foregroundStyle(.blue)
                            }
                            .frame(height: 200)
                            .padding(.top, 8)
                        } else {
                            Text("Chart available in iOS 16 and above")
                                .foregroundColor(.gray)
                                .padding()
                        }
                    }
                }

                // Top items
                Section(header: Text("Top items")) {
                    ForEach(topSellingItems()) { item in
                        Button {
                            selectedItemId = item.id
                            showingItemDetail = true
                        } label: {
                            HStack {
                                if let firstImageUrl = item.imageUrls?.first,
                                   let url = URL(string: firstImageUrl) {
                                    AsyncImage(url: url) { image in
                                        image
                                            .resizable()
                                            .scaledToFill()
                                    } placeholder: {
                                        Image(systemName: "photo")
                                            .foregroundColor(.gray)
                                    }
                                    .frame(width: 50, height: 50)
                                    .cornerRadius(5)
                                } else {
                                    Image(systemName: "tshirt")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(width: 40, height: 40)
                                        .padding(5)
                                        .foregroundColor(.gray)
                                }

                                VStack(alignment: .leading) {
                                    Text(item.name)
                                        .font(.headline)
                                        .foregroundColor(.primary)

                                    Text("Sold: \(itemSalesCount(for: item.id ?? ""))")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }

                                Spacer()

                                Text("\(itemRevenue(for: item.id ?? ""), specifier: "%.0f") EUR")
                                    .bold()
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                }

                // Analysis by category
                Section(header: Text("Sales by category")) {
                    if #available(iOS 16.0, *) {
                        Chart(categorySalesData(), id: \.category) { item in
                            SectorMark(
                                angle: .value("Sales", item.sales),
                                innerRadius: .ratio(0.5),
                                angularInset: 1.5
                            )
                            .cornerRadius(5)
                            .foregroundStyle(by: .value("Category", item.category))
                        }
                        .frame(height: 200)
                        .padding(.vertical)
                    }

                    ForEach(categorySalesData(), id: \.category) { item in
                        HStack {
                            Text(item.category)
                            Spacer()
                            Text("\(item.sales) pcs.")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Stock statistics
                Section(header: Text("Stock")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total in stock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(totalStockCount())")
                                .font(.title3)
                                .bold()
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Items with low stock")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(lowStockItemsCount())")
                                .font(.title3)
                                .bold()
                                .foregroundColor(lowStockItemsCount() > 0 ? .orange : .green)
                        }
                    }
                    .padding(.vertical, 5)
                }
            }
            .navigationTitle("Sales Analytics")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadData()
            }
            .sheet(isPresented: $showingItemDetail) {
                if let id = selectedItemId, let item = getItem(by: id) {
                    MerchItemAnalyticsView(item: item)
                }
            }
            .refreshable {
                loadData()
            }
        }
    }

    // MARK: - Functions for getting data

    private func loadData() {
        if let groupId = AppState.shared.user?.groupId {
            merchService.fetchItems(for: groupId)
            merchService.fetchSales(for: groupId)
        }
    }

    private func getItem(by id: String) -> MerchItem? {
        return merchService.items.first { $0.id == id }
    }

    private func totalRevenue() -> Double {
        let filteredSales = filteredSalesByTimeFrame()

        return filteredSales.reduce(0) { total, sale in
            if let item = merchService.items.first(where: { $0.id == sale.itemId }) {
                return total + (item.price * Double(sale.quantity))
            }
            return total
        }
    }

    private func totalSoldItems() -> Int {
        let filteredSales = filteredSalesByTimeFrame()
        return filteredSales.reduce(0) { $0 + $1.quantity }
    }

    private func filteredSalesByTimeFrame() -> [MerchSale] {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -selectedTimeFrame.days, to: Date()) ?? Date()

        var sales = merchService.sales.filter { $0.date >= cutoffDate }

        if let category = selectedCategoryFilter {
            sales = sales.filter { sale in
                if let item = merchService.items.first(where: { $0.id == sale.itemId }) {
                    return item.category == category
                }
                return false
            }
        }

        return sales
    }

    private func salesChartData() -> [SalesChartPoint] {
        let sales = filteredSalesByTimeFrame()
        let calendar = Calendar.current

        // Group sales by days
        var salesByDay: [Date: Int] = [:]

        for sale in sales {
            let day = calendar.startOfDay(for: sale.date)
            salesByDay[day, default: 0] += sale.quantity
        }

        // Create array of points for chart
        var chartData: [SalesChartPoint] = []

        // Determine date range for chart
        let endDate = Date()
        let startDate: Date

        switch selectedTimeFrame {
        case .week:
            startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate

            // For week show each day
            var current = startDate
            while current <= endDate {
                let sales = salesByDay[calendar.startOfDay(for: current)] ?? 0
                chartData.append(SalesChartPoint(date: current, amount: sales))
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }

        case .month:
            startDate = calendar.date(byAdding: .day, value: -30, to: endDate) ?? endDate

            // For month group by weeks
            var current = startDate
            while current <= endDate {
                let weekStart = calendar.startOfDay(for: current)
                let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) ?? weekStart

                let weekSales = sales.filter { sale in
                    sale.date >= weekStart && sale.date < weekEnd
                }.reduce(0) { $0 + $1.quantity }

                chartData.append(SalesChartPoint(date: weekStart, amount: weekSales))
                current = weekEnd
            }

        case .quarter, .year, .all:
            startDate = calendar.date(byAdding: .day, value: -selectedTimeFrame.days, to: endDate) ?? endDate

            // For quarter and year group by months
            var current = startDate
            while current <= endDate {
                let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: current)) ?? current
                var components = DateComponents()
                components.month = 1
                let monthEnd = calendar.date(byAdding: components, to: monthStart) ?? monthStart

                let monthSales = sales.filter { sale in
                    sale.date >= monthStart && sale.date < monthEnd
                }.reduce(0) { $0 + $1.quantity }

                chartData.append(SalesChartPoint(date: monthStart, amount: monthSales))
                current = monthEnd
            }
        }

        return chartData
    }

    private func topSellingItems() -> [MerchItem] {
        // Get sales filtered by time
        let sales = filteredSalesByTimeFrame()

        // Count sales for each item
        var salesByItem: [String: Int] = [:]
        for sale in sales {
            salesByItem[sale.itemId, default: 0] += sale.quantity
        }

        // Get items and sort them by sales count
        let items = merchService.items.filter { item in
            if let itemId = item.id {
                return salesByItem[itemId] != nil
            }
            return false
        }.sorted { item1, item2 in
            let sales1 = salesByItem[item1.id ?? ""] ?? 0
            let sales2 = salesByItem[item2.id ?? ""] ?? 0
            return sales1 > sales2
        }

        // Return top 5 items or less if not enough
        return Array(items.prefix(5))
    }

    private func itemSalesCount(for itemId: String) -> Int {
        let sales = filteredSalesByTimeFrame()
        return sales.filter { $0.itemId == itemId }.reduce(0) { $0 + $1.quantity }
    }

    private func itemRevenue(for itemId: String) -> Double {
        let sales = filteredSalesByTimeFrame().filter { $0.itemId == itemId }
        let item = merchService.items.first { $0.id == itemId }

        if let item = item {
            return sales.reduce(0) { $0 + (Double($1.quantity) * item.price) }
        }

        return 0
    }

    private func categorySalesData() -> [CategorySalesData] {
        let sales = filteredSalesByTimeFrame()
        var salesByCategory: [MerchCategory: Int] = [:]

        for sale in sales {
            if let item = merchService.items.first(where: { $0.id == sale.itemId }) {
                salesByCategory[item.category, default: 0] += sale.quantity
            }
        }

        return salesByCategory.map { category, sales in
            CategorySalesData(category: category.rawValue, sales: sales)
        }.sorted { $0.sales > $1.sales }
    }

    private func totalStockCount() -> Int {
        return merchService.items.reduce(0) { $0 + $1.totalStock }
    }

    private func lowStockItemsCount() -> Int {
        return merchService.items.filter { $0.hasLowStock }.count
    }
}

// MARK: - View for detailed item analysis

struct MerchItemAnalyticsView: View {
    let item: MerchItem
    @StateObject private var merchService = MerchService.shared
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                // Basic item information
                Section {
                    HStack(alignment: .top, spacing: 15) {
                        if let firstImageUrl = item.imageUrls?.first,
                           let url = URL(string: firstImageUrl) {
                            AsyncImage(url: url) { image in
                                image
                                    .resizable()
                                    .scaledToFit()
                            } placeholder: {
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            }
                            .frame(width: 100, height: 100)
                            .cornerRadius(8)
                        } else {
                            Image(systemName: item.category.icon)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 80, height: 80)
                                .padding(10)
                                .foregroundColor(.gray)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.name)
                                .font(.title3)
                                .bold()

                            HStack {
                                Label(item.category.rawValue, systemImage: item.category.icon)
                                    .font(.caption)

                                Text("•")

                                // Fix reference to optional property
                                if let subcategory = item.subcategory {
                                    Label(subcategory.rawValue, systemImage: subcategory.icon)
                                        .font(.caption)
                                } else {
                                    Text("No subcategory")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.gray)

                            Text("\(Int(item.price)) EUR")
                                .font(.headline)
                                .padding(.top, 2)
                        }
                    }
                    .padding(.vertical, 5)
                }

                // Sales statistics
                Section(header: Text("Sales statistics")) {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Total sold")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(totalSoldQuantity())")
                                .font(.title3)
                                .bold()
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("Revenue")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text("\(totalRevenue(), specifier: "%.0f") EUR")
                                .font(.title3)
                                .bold()
                        }
                    }
                    .padding(.vertical, 5)

                    // Sales by channel
                    ForEach(salesByChannel(), id: \.channel) { channelData in
                        HStack {
                            Text(channelData.channel)
                            Spacer()
                            Text("\(channelData.quantity) pcs. (\(channelData.percentage, specifier: "%.1f")%)")
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Current stock
                Section(header: Text("Current stock")) {
                    ProgressView(value: Double(item.totalStock), total: Double(item.totalStock + totalSoldQuantity())) {
                        HStack {
                            Text("Left: \(item.totalStock) pcs.")
                            Spacer()
                            Text("Sold: \(totalSoldQuantity()) pcs.")
                        }
                        .font(.caption)
                    }
                    .progressViewStyle(LinearProgressViewStyle(tint: progressColor()))
                    .padding(.vertical, 5)

                    HStack {
                        Text("Size")
                            .bold()
                        Spacer()
                        Text("Stock")
                            .bold()
                    }
                    .padding(.top, 5)

                    stockRow(label: "S", quantity: item.stock.S)
                    stockRow(label: "M", quantity: item.stock.M)
                    stockRow(label: "L", quantity: item.stock.L)
                    stockRow(label: "XL", quantity: item.stock.XL)
                    stockRow(label: "XXL", quantity: item.stock.XXL)

                    if item.hasLowStock {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Low stock! Threshold: \(item.lowStockThreshold) pcs.")
                                .foregroundColor(.orange)
                        }
                        .padding(.top, 5)
                    }
                }

                // Recommendations
                Section(header: Text("Recommendations")) {
                    recommendationRow(
                        icon: "arrow.up.arrow.down",
                        title: "Popularity",
                        detail: popularityLabel()
                    )

                    recommendationRow(
                        icon: "cart.fill",
                        title: "Order recommendation",
                        detail: orderRecommendation()
                    )

                    recommendationRow(
                        icon: "dollarsign.circle",
                        title: "Price recommendation",
                        detail: priceRecommendation()
                    )
                }
            }
            .navigationTitle("Item Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Helper functions and components

    private func totalSoldQuantity() -> Int {
        return merchService.sales
            .filter { $0.itemId == item.id }
            .reduce(0) { $0 + $1.quantity }
    }

    private func totalRevenue() -> Double {
        return Double(totalSoldQuantity()) * item.price
    }

    struct ChannelSalesData {
        var channel: String
        var quantity: Int
        var percentage: Double
    }

    private func salesByChannel() -> [ChannelSalesData] {
        let itemSales = merchService.sales.filter { $0.itemId == item.id }
        let total = totalSoldQuantity()

        if total == 0 {
            return []
        }

        var salesByChannel: [MerchSaleChannel: Int] = [:]

        for sale in itemSales {
            salesByChannel[sale.channel, default: 0] += sale.quantity
        }

        return salesByChannel.map { channel, quantity in
            let percentage = Double(quantity) / Double(total) * 100.0
            return ChannelSalesData(
                channel: channel.rawValue,
                quantity: quantity,
                percentage: percentage
            )
        }.sorted { $0.quantity > $1.quantity }
    }

    private func stockRow(label: String, quantity: Int) -> some View {
        HStack {
            Text(label)
            Spacer()
            if quantity <= item.lowStockThreshold {
                Text("\(quantity)")
                    .foregroundColor(.orange)
                    .bold()
            } else {
                Text("\(quantity)")
            }
        }
    }

    private func progressColor() -> Color {
        if item.hasLowStock {
            return .orange
        } else {
            return .green
        }
    }

    private func recommendationRow(icon: String, title: String, detail: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .bold()

                Text(detail)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 3)
    }

    private func popularityLabel() -> String {
        let sales = totalSoldQuantity()

        if sales == 0 {
            return "No sales. Consider promotional actions."
        } else if sales < 5 {
            return "Low popularity. Consider reducing the price."
        } else if sales < 20 {
            return "Average popularity. Item sells steadily."
        } else {
            return "High popularity! Consider increasing stock."
        }
    }

    private func orderRecommendation() -> String {
        let sales = totalSoldQuantity()
        let stock = item.totalStock

        if sales == 0 {
            return "Too early for additional orders."
        } else if stock < item.lowStockThreshold {
            return "Urgent restock required!"
        } else if stock < sales / 2 {
            return "Recommended to order additional \(sales - stock) pcs."
        } else {
            return "Current stock is optimal."
        }
    }

    private func priceRecommendation() -> String {
        let sales = totalSoldQuantity()

        if sales == 0 {
            return "Consider temporary price reduction to stimulate sales."
        } else if sales > 30 && item.hasLowStock {
            return "High demand. Consider increasing price by 5-10%."
        } else if sales > 15 {
            return "Good demand. Current price is optimal."
        } else {
            return "Average demand. Maintain current price."
        }
    }
}