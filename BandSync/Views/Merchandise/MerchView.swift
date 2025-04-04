//
//  MerchView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


import SwiftUI

struct MerchView: View {
    @StateObject private var merchService = MerchService.shared
    @State private var showAdd = false
    @State private var showAnalytics = false
    @State private var selectedCategory: MerchCategory? = nil
    @State private var searchText = ""
    @State private var showLowStockAlert = false

    // Filtered items based on search and categories
    private var filteredItems: [MerchItem] {
        var items = merchService.items

        // Filter by category
        if let category = selectedCategory {
            items = items.filter { $0.category == category }
        }

        // Filter by search query
        if !searchText.isEmpty {
            items = items.filter { item in
                item.name.lowercased().contains(searchText.lowercased()) ||
                item.description.lowercased().contains(searchText.lowercased()) ||
                item.category.rawValue.lowercased().contains(searchText.lowercased()) ||
                (item.subcategory?.rawValue.lowercased() ?? "").contains(searchText.lowercased())
            }
        }

        return items
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Product categories
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        categoryButton(title: "All", icon: "tshirt.fill", category: nil)

                        ForEach(MerchCategory.allCases) { category in
                            categoryButton(
                                title: category.rawValue,
                                icon: category.icon,
                                category: category
                            )
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .background(Color.gray.opacity(0.1))

                // Item counter and low stock
                HStack {
                    VStack(alignment: .leading) {
                        Text("Items")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text("\(filteredItems.count)")
                            .font(.headline)
                    }

                    Spacer()

                    if !merchService.lowStockItems.isEmpty {
                        // Low stock items information
                        Button {
                            showLowStockItems()
                        } label: {
                            HStack {
                                VStack(alignment: .trailing) {
                                    Text("Low stock")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                    Text("\(merchService.lowStockItems.count)")
                                        .font(.headline)
                                        .foregroundColor(.orange)
                                }

                                Image(systemName: "exclamationmark.triangle")
                                    .foregroundColor(.orange)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.orange.opacity(0.1))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.orange, lineWidth: 1)
                            )
                        }
                    } else {
                        // Stock normal information
                        HStack {
                            VStack(alignment: .trailing) {
                                Text("Stock normal")
                                    .font(.caption)
                                    .foregroundColor(.green)
                                Text("\(merchService.items.count)")
                                    .font(.headline)
                                    .foregroundColor(.green)
                            }

                            Image(systemName: "checkmark.circle")
                                .foregroundColor(.green)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)

                if merchService.isLoading {
                    // Loading indicator
                    ProgressView()
                        .padding()
                } else if filteredItems.isEmpty {
                    // Empty list state
                    VStack(spacing: 20) {
                        Image(systemName: "bag")
                            .font(.system(size: 64))
                            .foregroundColor(.gray)

                        Text(searchText.isEmpty
                            ? "No items in selected category"
                            : "No items matching '\(searchText)'")
                        .foregroundColor(.gray)

                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button("Add item") {
                                showAdd = true
                            }
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Items list
                    List {
                        ForEach(filteredItems) { item in
                            NavigationLink(destination: MerchDetailView(item: item)) {
                                MerchItemRow(item: item)
                            }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
            }
            .navigationTitle("Merch")
            .searchable(text: $searchText, prompt: "Search items")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        if AppState.shared.hasEditPermission(for: .merchandise) {
                            Button {
                                showAdd = true
                            } label: {
                                Label("Add item", systemImage: "plus")
                            }
                        }

                        Button {
                            showAnalytics = true
                        } label: {
                            Label("Sales analytics", systemImage: "chart.bar")
                        }

                        if !merchService.lowStockItems.isEmpty {
                            Button {
                                showLowStockItems()
                            } label: {
                                Label("Show low stock items", systemImage: "exclamationmark.triangle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                }
            }
            .onAppear {
                if let groupId = AppState.shared.user?.groupId {
                    merchService.fetchItems(for: groupId)
                    merchService.fetchSales(for: groupId)
                }
            }
            .sheet(isPresented: $showAdd) {
                AddMerchView()
            }
            .sheet(isPresented: $showAnalytics) {
                MerchSalesAnalyticsView()
            }
            .alert("Low stock items", isPresented: $showLowStockAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("There are \(merchService.lowStockItems.count) items with stock below threshold.")
            }
        }
    }

    // Category button
    private func categoryButton(title: String, icon: String, category: MerchCategory?) -> some View {
        Button {
            withAnimation {
                selectedCategory = category
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 16))

                Text(title)
                    .font(.caption)
            }
            .foregroundColor(selectedCategory == category ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedCategory == category ? Color.blue : Color.gray.opacity(0.2))
            .cornerRadius(10)
        }
    }

    // Show low stock items
    private func showLowStockItems() {
        // Create temporary list for comparison
        let lowStockItemIds = Set(merchService.lowStockItems.compactMap { $0.id })

        // Determine low stock items in current view
        let lowStockItemsInCurrentView = filteredItems.filter { item in
            if let id = item.id {
                return lowStockItemIds.contains(id)
            }
            return false
        }

        // If no low stock items in current view,
        // show separate alert with information
        if lowStockItemsInCurrentView.isEmpty {
            showLowStockAlert = true
        } else {
            // Otherwise reset filters and set new search to display only low stock items
            selectedCategory = nil
            searchText = "low_stock_filter"

            // Delay for applying filters
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.searchText = ""  // Reset search query
            }
        }
    }
}

// MARK: - Structure for item row

struct MerchItemRow: View {
    let item: MerchItem

    var body: some View {
        HStack {
            // Item image or category icon
            if let firstImageUrl = item.imageUrls?.first,
               let url = URL(string: firstImageUrl) {
                AsyncImage(url: url) { phase in
                    if let image = phase.image {
                        image
                            .resizable()
                            .scaledToFill()
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else if phase.error != nil {
                        Image(systemName: item.category.icon)
                            .font(.system(size: 30))
                            .frame(width: 60, height: 60)
                            .foregroundColor(.gray)
                    } else {
                        ProgressView()
                            .frame(width: 60, height: 60)
                    }
                }
            } else {
                Image(systemName: item.category.icon)
                    .font(.system(size: 30))
                    .frame(width: 60, height: 60)
                    .foregroundColor(.gray)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            // Item information
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(item.name)
                        .font(.headline)

                    if item.hasLowStock {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.caption)
                    }
                }

                Text("\(item.category.rawValue) \(item.subcategory != nil ? "• \(item.subcategory!.rawValue)" : "")")
                    .font(.caption)
                    .foregroundColor(.gray)

                // Stock indicator - show depending on category
                if item.category == .clothing {
                    // For clothing show sizes
                    HStack(spacing: 5) {
                        Text("Sizes:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        sizeIndicator("S", quantity: item.stock.S, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("M", quantity: item.stock.M, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("L", quantity: item.stock.L, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("XL", quantity: item.stock.XL, lowThreshold: item.lowStockThreshold)
                        sizeIndicator("XXL", quantity: item.stock.XXL, lowThreshold: item.lowStockThreshold)
                    }
                } else {
                    // For other categories show total quantity
                    HStack(spacing: 5) {
                        Text("Quantity:")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        // Use sizeIndicator to display quantity with same style
                        Text("\(item.totalStock)")
                            .font(.caption2)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(
                                item.totalStock == 0 ? Color.gray.opacity(0.3) :
                                    item.totalStock <= item.lowStockThreshold ? Color.orange.opacity(0.3) :
                                        Color.green.opacity(0.3)
                            )
                            .foregroundColor(
                                item.totalStock == 0 ? .gray :
                                    item.totalStock <= item.lowStockThreshold ? .orange :
                                        .green
                            )
                            .cornerRadius(3)
                    }
                }
            }

            Spacer()

            // Price
            VStack(alignment: .trailing) {
                Text("\(Int(item.price)) EUR")
                    .font(.headline)
                    .bold()

                Text("Total: \(item.totalStock)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    // Size availability indicator
    private func sizeIndicator(_ size: String, quantity: Int, lowThreshold: Int) -> some View {
        Text(size)
            .font(.caption2)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(
                quantity == 0 ? Color.gray.opacity(0.3) :
                    quantity <= lowThreshold ? Color.orange.opacity(0.3) :
                        Color.green.opacity(0.3)
            )
            .foregroundColor(
                quantity == 0 ? .gray :
                    quantity <= lowThreshold ? .orange :
                        .green
            )
            .cornerRadius(3)
    }
}
