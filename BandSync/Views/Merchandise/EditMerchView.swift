import SwiftUI
import PhotosUI

struct EditMerchView: View {
    @Environment(\.dismiss) var dismiss
    let item: MerchItem

    @State private var name: String
    @State private var description: String
    @State private var price: String
    @State private var category: MerchCategory
    @State private var subcategory: MerchSubcategory?
    @State private var stock: MerchSizeStock
    @State private var selectedImage: PhotosPickerItem?
    @State private var merchImage: UIImage?
    @State private var isUploading = false
    @State private var lowStockThreshold: String

    init(item: MerchItem) {
        self.item = item
        _name = State(initialValue: item.name)
        _description = State(initialValue: item.description)
        _price = State(initialValue: String(item.price))
        _category = State(initialValue: item.category)
        _subcategory = State(initialValue: item.subcategory)
        _stock = State(initialValue: item.stock)
        _lowStockThreshold = State(initialValue: String(item.lowStockThreshold))
    }

    var body: some View {
        NavigationView {
            Form {
                // Item image
                Section(header: Text("Image")) {
                    PhotosPicker(selection: $selectedImage, matching: .images) {
                        HStack {
                            if let merchImage = merchImage {
                                Image(uiImage: merchImage)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(height: 200)
                                    .cornerRadius(8)
                            } else if let imageURL = item.imageURL {
                                AsyncImage(url: URL(string: imageURL)) { phase in
                                    if let image = phase.image {
                                        image
                                            .resizable()
                                            .scaledToFit()
                                            .frame(height: 200)
                                            .cornerRadius(8)
                                    } else if phase.error != nil {
                                        Label("Error loading image", systemImage: "exclamationmark.triangle")
                                            .foregroundColor(.orange)
                                    } else {
                                        ProgressView()
                                    }
                                }
                            } else {
                                Label("Select image", systemImage: "photo.on.rectangle")
                            }
                        }
                    }
                    .onChange(of: selectedImage) { newItem in
                        Task {
                            if let data = try? await newItem?.loadTransferable(type: Data.self) {
                                if let uiImage = UIImage(data: data) {
                                    merchImage = uiImage
                                }
                            }
                        }
                    }
                }

                // Basic information
                Section(header: Text("Item information")) {
                    TextField("Name", text: $name)
                    TextField("Description", text: $description)
                    TextField("Price", text: $price)
                        .keyboardType(.decimalPad)
                    TextField("Low stock threshold", text: $lowStockThreshold)
                        .keyboardType(.numberPad)
                }

                // Category and subcategory
                Section(header: Text("Category")) {
                    Picker("Category", selection: $category) {
                        ForEach(MerchCategory.allCases) {
                            Text($0.rawValue).tag($0)
                        }
                    }
                    .onChange(of: category) { newCategory in
                        // If new category is different from old one and subcategory doesn't belong to new category
                        if newCategory != item.category,
                           let currentSubcategory = subcategory,
                           !MerchSubcategory.subcategories(for: newCategory).contains(currentSubcategory) {
                            subcategory = nil
                        }
                    }

                    Picker("Subcategory", selection: $subcategory) {
                        Text("Not selected").tag(Optional<MerchSubcategory>.none)
                        ForEach(MerchSubcategory.subcategories(for: category), id: \.self) {
                            Text($0.rawValue).tag(Optional<MerchSubcategory>.some($0))
                        }
                    }
                }

                // Stock by sizes or quantity
                Section(header: Text(category == .clothing ? "Stock by sizes" : "Item quantity")) {
                    if category == .clothing {
                        Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                        Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                        Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                        Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                        Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                    } else {
                        Stepper("Quantity: \(stock.total)", value: $stock.S, in: 0...999)
                        // Removing reference to catalogNumber variable which doesn't exist
                    }
                }
            }
            .navigationTitle("Edit Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .disabled(isUploading || !isFormValid)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay(
                Group {
                    if isUploading {
                        ProgressView("Saving...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
        .onAppear {
            loadImage()
        }
    }

    // Form validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0 &&
        Int(lowStockThreshold) != nil &&
        (lowStockThreshold as NSString).integerValue >= 0
    }

    // Load current image
    private func loadImage() {
        guard let imageURL = item.imageURL, let url = URL(string: imageURL) else { return }

        URLSession.shared.dataTask(with: url) { data, response, error in
            if let data = data, let image = UIImage(data: data) {
                DispatchQueue.main.async {
                    self.merchImage = image
                }
            }
        }.resume()
    }

    // Save changes
    private func saveChanges() {
        guard let priceValue = Double(price),
              let thresholdValue = Int(lowStockThreshold) else { return }

        isUploading = true

        // Create updated item
        var updatedItem = item
        updatedItem.name = name
        updatedItem.description = description
        updatedItem.price = priceValue
        updatedItem.category = category
        updatedItem.subcategory = subcategory

        // Update stock depending on category
        if category == .clothing {
            // For clothing save all sizes
            updatedItem.stock = stock
        } else {
            // For other categories save total quantity in S, other sizes = 0
            updatedItem.stock = MerchSizeStock(S: stock.S, M: 0, L: 0, XL: 0, XXL: 0)
        }

        updatedItem.lowStockThreshold = thresholdValue

        // If new image selected, upload it
        if let newImage = merchImage, selectedImage != nil {
            MerchImageManager.shared.uploadImage(newImage, for: updatedItem) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        updatedItem.imageURL = url.absoluteString
                        saveItemToDatabase(updatedItem)

                    case .failure(let error):
                        print("Error uploading image: \(error)")
                        isUploading = false
                    }
                }
            }
        } else {
            // Otherwise save only data
            saveItemToDatabase(updatedItem)
        }
    }

    private func saveItemToDatabase(_ item: MerchItem) {
        MerchService.shared.updateItem(item) { success in
            isUploading = false
            if success {
                dismiss()
            }
        }
    }
}
