//
//  TransactionDetailView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//

import SwiftUI

struct TransactionDetailView: View {
    let record: FinanceRecord
    @State private var showShareSheet = false
    @State private var exportedPDF: Data?
    @State private var showAnimatedDetails = false

    private func categoryIcon(for category: String) -> String {
        switch category {
        case "Logistics": return "car.fill"
        case "Food": return "fork.knife"
        case "Equipment": return "guitars"
        case "Venue": return "building.2.fill"
        case "Promo": return "megaphone.fill"
        case "Other": return "ellipsis.circle.fill"
        case "Performance": return "music.note"
        case "Merch": return "tshirt.fill"
        case "Streaming": return "headphones"
        default: return "questionmark.circle"
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Title and amount with animation
                VStack(spacing: 8) {
                    Text("\(record.type == .income ? "+" : "-")\(String(format: "%.2f", record.amount)) \(record.currency)")
                        .font(.system(size: 38, weight: .bold))
                        .foregroundColor(record.type == .income ? .green : .red)
                        .padding(.top, 10)
                        .padding(.bottom, 2)

                    Text(formattedDate(record.date))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [
                                    record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2),
                                    Color.secondary.opacity(0.05)
                                ]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                )
                .overlay(
                    // Circular category indicator
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 60, height: 60)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)

                        ZStack {
                            Circle()
                                .fill(record.type == .income ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                .frame(width: 50, height: 50)

                            Image(systemName: categoryIcon(for: record.category))
                                .font(.system(size: 24))
                                .foregroundColor(record.type == .income ? .green : .red)
                        }
                    }
                    .offset(y: 55),
                    alignment: .bottom
                )
                .padding(.bottom, 30)

                // Transaction details with animation
                VStack(alignment: .leading, spacing: 20) {
                    // Transaction type
                    detailRow(
                        icon: record.type == .income ? "arrow.down.circle.fill" : "arrow.up.circle.fill",
                        iconColor: record.type == .income ? .green : .red,
                        title: "Type",
                        value: record.type == .income ? "Income" : "Expense"
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .offset(x: showAnimatedDetails ? 0 : -20)
                    .animation(.easeOut.delay(0.1), value: showAnimatedDetails)

                    Divider()

                    // Category
                    detailRow(
                        icon: categoryIcon(for: record.category),
                        iconColor: .blue,
                        title: "Category",
                        value: record.category
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .offset(x: showAnimatedDetails ? 0 : -20)
                    .animation(.easeOut.delay(0.2), value: showAnimatedDetails)

                    if !record.details.isEmpty {
                        Divider()

                        // Description
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "doc.text")
                                    .foregroundColor(.blue)
                                    .font(.title2)
                                    .frame(width: 28, height: 28)

                                Text("Description")
                                    .font(.headline)
                            }

                            Text(record.details)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.1))
                                )
                                .padding(.leading, 34)
                        }
                        .opacity(showAnimatedDetails ? 1 : 0)
                        .offset(x: showAnimatedDetails ? 0 : -20)
                        .animation(.easeOut.delay(0.3), value: showAnimatedDetails)
                    }

                    if record.isCached == true {
                        Divider()

                        detailRow(
                            icon: "cloud.slash",
                            iconColor: .orange,
                            title: "Status",
                            value: "Waiting for synchronization",
                            valueColor: .orange
                        )
                        .opacity(showAnimatedDetails ? 1 : 0)
                        .offset(x: showAnimatedDetails ? 0 : -20)
                        .animation(.easeOut.delay(0.4), value: showAnimatedDetails)
                    }
                }
                .padding(20)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(Color.secondary.opacity(0.05))
                )
                .shadow(color: Color.black.opacity(0.03), radius: 10, x: 0, y: 5)

                // Action buttons
                HStack(spacing: 16) {
                    actionButton(
                        icon: "square.and.arrow.up",
                        title: "Share",
                        action: {
                            createPDF()
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.5), value: showAnimatedDetails)

                    actionButton(
                        icon: "trash",
                        title: "Delete",
                        color: .red,
                        action: {
                            // In the future, a confirmation dialog can be added here
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.6), value: showAnimatedDetails)

                    actionButton(
                        icon: "arrow.triangle.2.circlepath",
                        title: "Repeat",
                        action: {
                            // In the future, functionality for repeating the transaction can be added here
                        }
                    )
                    .opacity(showAnimatedDetails ? 1 : 0)
                    .scaleEffect(showAnimatedDetails ? 1 : 0.8)
                    .animation(.spring(response: 0.4, dampingFraction: 0.7).delay(0.7), value: showAnimatedDetails)
                }
                .padding(.top, 10)
            }
            .padding()
        }
        .navigationTitle("Transaction Details")
        .sheet(isPresented: $showShareSheet) {
            if let pdf = exportedPDF {
                DocumentShareSheet(items: [pdf])
            }
        }
        .onAppear {
            // Start animation with a small delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                showAnimatedDetails = true
            }
        }
    }

    // Modular component for displaying details row
    private func detailRow(icon: String, iconColor: Color, title: String, value: String, valueColor: Color = .secondary) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(iconColor)
                .font(.title2)
                .frame(width: 28, height: 28)

            Text(title)
                .font(.headline)

            Spacer()

            Text(value)
                .foregroundColor(valueColor)
                .padding(.vertical, 4)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(valueColor.opacity(0.1))
                )
        }
    }

    // Modular component for action button
    private func actionButton(icon: String, title: String, color: Color = .blue, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                    .background(Color.secondary.opacity(0.05))
                    .cornerRadius(12)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }

    private func formattedDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateStyle = .medium
        return fmt.string(from: date)
    }

    // Create PDF for export - adding crash protection
    private func createPDF() {
        guard let pdf = generateSafePDF() else { return }
        self.exportedPDF = pdf
        self.showShareSheet = true
    }

    // Separate method for safe PDF creation
    private func generateSafePDF() -> Data? {
        let formatter = DateFormatter()
        formatter.dateStyle = .long

        do {
            let pdfData = NSMutableData()
            UIGraphicsBeginPDFContextToData(pdfData, CGRect(x: 0, y: 0, width: 595, height: 842), nil)
            UIGraphicsBeginPDFPage()

            let font = UIFont.systemFont(ofSize: 14)
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = .left

            let titleFont = UIFont.boldSystemFont(ofSize: 24)

            let titleAttributes: [NSAttributedString.Key: Any] = [
                .font: titleFont,
                .paragraphStyle: paragraphStyle
            ]

            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .paragraphStyle: paragraphStyle
            ]

            let title = "Financial Transaction"
            title.draw(in: CGRect(x: 50, y: 50, width: 495, height: 30), withAttributes: titleAttributes)

            var y = 100.0
            let lineHeight = 25.0

            let details = [
                "Type: \(record.type == .income ? "Income" : "Expense")",
                "Category: \(record.category)",
                "Amount: \(String(format: "%.2f", record.amount)) \(record.currency)",
                "Date: \(formatter.string(from: record.date))",
                "Description: \(record.details)"
            ]

            for detail in details {
                detail.draw(in: CGRect(x: 50, y: y, width: 495, height: lineHeight), withAttributes: attributes)
                y += lineHeight
            }

            UIGraphicsEndPDFContext()
            return pdfData as Data
        } catch {
            print("Error creating PDF: \(error)")
            return nil
        }
    }
}

// Fixing component for displaying ShareSheet
struct TransactionShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// Adding field to track synchronization status
extension FinanceRecord {
    var isCached: Bool {
        // Here you can add real logic to check caching status
        // For example, just return false
        return false
    }
}
