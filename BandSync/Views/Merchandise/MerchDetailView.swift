import SwiftUI
import UIKit

struct MerchDetailView: View {
    let item: MerchItem
    @State private var showSell = false
    @State private var merchImage: UIImage?
    @State private var isLoadingImage = false
    @State private var showEditSheet = false
    @State private var showDeleteConfirmation = false
    @State private var showSalesHistory = false
    @Environment(\.presentationMode) var presentationMode

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Item image
                imageSection

                // Main information
                detailsSection

                // Stock by size
                stockSection

                // Add sales history button
                Button("Sales history") {
                    showSalesHistory = true
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue.opacity(0.2))
                .foregroundColor(.blue)
                .cornerRadius(10)

                // Sell button
                sellButton
            }
            .padding()
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if AppState.shared.hasEditPermission(for: .merchandise) {
                        Menu {
                            Button {
                                showEditSheet = true
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }

                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                        }
                    }
                }
            }
        }
        .onAppear {
            loadImage()
        }
        .sheet(isPresented: $showSell) {
            SellMerchView(item: item)
        }
        .sheet(isPresented: $showEditSheet) {
            EditMerchView(item: item)
        }
        .sheet(isPresented: $showSalesHistory) {
            SalesHistoryView(item: item)
        }
        .alert("Delete item?", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                deleteItem()
            }
        } message: {
            Text("Are you sure you want to delete item '\(item.name)'? This action cannot be undone.")
        }
    }

    // Image section
    private var imageSection: some View {
        Group {
            if isLoadingImage {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 250)
            } else if let merchImage = merchImage {
                Image(uiImage: merchImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, minHeight: 250)
                    .cornerRadius(12)
            } else {
                Image(systemName: "photo")
                    .resizable()
                    .scaledToFit()
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity, minHeight: 250)
            }
        }
    }

    // Details section
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.description)
                .font(.body)

            HStack {
                Text("Category:")
                Spacer()
                Text(item.category.rawValue)
            }

            if let subcategory = item.subcategory {
                HStack {
                    Text("Subcategory:")
                    Spacer()
                    Text(subcategory.rawValue)
                }
            }

            HStack {
                Text("Price:")
                Spacer()
                Text("\(Int(item.price)) EUR")
                    .bold()
            }
        }
    }

    // Stock section
    private var stockSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if item.category == .clothing {
                Text("Stock by sizes")
                    .font(.headline)

                HStack {
                    Text("S:")
                    Spacer()
                    Text("\(item.stock.S)")
                }
                HStack {
                    Text("M:")
                    Spacer()
                    Text("\(item.stock.M)")
                }
                HStack {
                    Text("L:")
                    Spacer()
                    Text("\(item.stock.L)")
                }
                HStack {
                    Text("XL:")
                    Spacer()
                    Text("\(item.stock.XL)")
                }
                HStack {
                    Text("XXL:")
                    Spacer()
                    Text("\(item.stock.XXL)")
                }
            } else {
                Text("Quantity:")
                    .font(.headline)
                Text("\(item.totalStock)")
                    .font(.title3)
            }
        }
    }

    // Sell button
    private var sellButton: some View {
        Button("Sell item") {
            showSell = true
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.blue)
        .foregroundColor(.white)
        .cornerRadius(10)
    }

    // Load image
    private func loadImage() {
        guard let imageURLString = item.imageURL else { return }

        isLoadingImage = true
        MerchImageManager.shared.downloadImage(from: imageURLString) { image in
            DispatchQueue.main.async {
                self.merchImage = image
                self.isLoadingImage = false
            }
        }
    }

    // Delete item
    private func deleteItem() {
        MerchService.shared.deleteItem(item) { success in
            if success {
                presentationMode.wrappedValue.dismiss()
            }
        }
    }
}
