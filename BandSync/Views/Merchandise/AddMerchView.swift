import SwiftUI
import PhotosUI

struct AddMerchView: View {
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var description = ""
    @State private var price = ""
    @State private var category: MerchCategory = .clothing
    @State private var subcategory: MerchSubcategory?
    @State private var stock = MerchSizeStock()
    @State private var selectedImage: PhotosPickerItem?
    @State private var merchImage: UIImage?
    @State private var isUploading = false


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

                TextField("Name", text: $name)
                TextField("Description", text: $description)
                TextField("Price", text: $price)
                    .keyboardType(.decimalPad)

                // Category and subcategory
                Picker("Category", selection: $category) {
                    ForEach(MerchCategory.allCases) {
                        Text($0.rawValue).tag($0)
                    }
                }
                .onChange(of: category) { _ in
                    // Reset subcategory when changing category
                    subcategory = nil
                }

                // Dynamic subcategory selection
                Picker("Subcategory", selection: $subcategory) {
                    Text("Not selected").tag(Optional<MerchSubcategory>.none)
                    ForEach(MerchSubcategory.subcategories(for: category), id: \.self) {
                        Text($0.rawValue).tag(Optional<MerchSubcategory>.some($0))
                    }
                }

                Section(header: Text(category == .clothing ? "Stock by sizes" : "Item quantity")) {
                    if category == .clothing {
                        Stepper("S: \(stock.S)", value: $stock.S, in: 0...999)
                        Stepper("M: \(stock.M)", value: $stock.M, in: 0...999)
                        Stepper("L: \(stock.L)", value: $stock.L, in: 0...999)
                        Stepper("XL: \(stock.XL)", value: $stock.XL, in: 0...999)
                        Stepper("XXL: \(stock.XXL)", value: $stock.XXL, in: 0...999)
                    } else {
                        Stepper("Quantity: \(stock.S)", value: $stock.S, in: 0...999)
                    }
                }
            }
            .navigationTitle("Add Item")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveItem()
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
                        ProgressView("Uploading...")
                            .progressViewStyle(CircularProgressViewStyle())
                            .padding()
                            .background(Color.white.opacity(0.8))
                            .cornerRadius(10)
                    }
                }
            )
        }
    }

    // Form validation
    private var isFormValid: Bool {
        !name.isEmpty &&
        !price.isEmpty &&
        Double(price) != nil &&
        (price as NSString).doubleValue > 0
    }

    // Save item
    private func saveItem() {
        guard let priceValue = Double(price),
              let groupId = AppState.shared.user?.groupId else { return }

        isUploading = true

        // Create base item object
        let baseItem = MerchItem(
            name: name,
            description: description,
            price: priceValue,
            category: category,
            subcategory: subcategory,
            stock: stock,
            groupId: groupId
        )

        // If there's an image, upload it
        if let merchImage = merchImage {
            MerchImageManager.shared.uploadImage(merchImage, for: baseItem) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let url):
                        // Create item with image URL
                        var item = baseItem
                        item.imageURL = url.absoluteString

                        MerchService.shared.addItem(item) { success in
                            self.isUploading = false
                            if success {
                                self.dismiss()
                            }
                        }
                    case .failure(let error):
                        print("Error uploading image: \(error)")
                        self.isUploading = false
                    }
                }
            }
        } else {
            // Create item without image
            MerchService.shared.addItem(baseItem) { success in
                self.isUploading = false
                if success {
                    self.dismiss()
                }
            }
        }
    }
}
