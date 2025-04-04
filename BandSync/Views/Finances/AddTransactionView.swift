import SwiftUI
import VisionKit

struct AddTransactionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var type: FinanceType = .expense
    @State private var category: FinanceCategory = .logistics
    @State private var amount: String = ""
    @State private var currency: String = "EUR"
    @State private var details: String = ""
    @State private var date = Date()

    // Состояния для сканера чеков
    @State private var showReceiptScanner = false
    @State private var scannedText = ""
    @State private var extractedFinanceRecord: FinanceRecord?
    @State private var recognizedItems: [ReceiptItem] = []
    @State private var isLoadingTransaction = false

    // Валидация полей
    private var isAmountValid: Bool {
        guard !amount.isEmpty else { return true }
        return Double(amount.replacingOccurrences(of: ",", with: ".")) != nil
    }

    private var formIsValid: Bool {
        return isAmountValid &&
               (!amount.isEmpty || extractedFinanceRecord != nil) &&
               !currency.isEmpty
    }

    private var currencies = ["EUR", "USD", "RUB"]

    var body: some View {
        NavigationView {
            Form {
                // Переключатель типа операции
                Section {
                    Picker("Тип", selection: $type) {
                        Text("Доход").tag(FinanceType.income)
                        Text("Расход").tag(FinanceType.expense)
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: type) { newType in
                        // Сбрасываем категорию при смене типа
                        category = FinanceCategory.forType(newType).first ?? .logistics
                    }
                }

                // Picker категорий
                Section {
                    Picker("Категория", selection: $category) {
                        ForEach(FinanceCategory.forType(type)) { cat in
                            HStack {
                                Image(systemName: categoryIcon(for: cat))
                                    .foregroundColor(categoryColor(for: cat))
                                Text(cat.rawValue)
                            }
                            .tag(cat)
                        }
                    }
                    .pickerStyle(.navigationLink)
                }

                // Поля для ввода
                Section {
                    HStack {
                        TextField("Сумма", text: $amount)
                            .keyboardType(.decimalPad)

                        Picker("Валюта", selection: $currency) {
                            ForEach(currencies, id: \.self) { curr in
                                Text(curr).tag(curr)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 80)
                    }

                    if !isAmountValid {
                        Text("Введите корректную сумму")
                            .foregroundColor(.red)
                            .font(.caption)
                    }

                    TextField("Описание", text: $details)

                    DatePicker("Дата", selection: $date, displayedComponents: [.date])
                }

                // Кнопка сканирования чека
                Section {
                    Button(action: {
                        showReceiptScanner = true
                    }) {
                        HStack {
                            Image(systemName: "camera.viewfinder")
                                .foregroundColor(.blue)
                            Text("Сканировать чек")
                        }
                    }
                }

                // Отображение распознанного текста
                if !scannedText.isEmpty {
                    Section(header: Text("Текст чека")) {
                        Text(scannedText)
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                }

                // Если есть распознанная финансовая запись
                if let record = extractedFinanceRecord {
                    Section(header: Text("Распознанные данные")) {
                        HStack {
                            Text("Сумма:")
                            Spacer()
                            Text("\(String(format: "%.2f", record.amount)) \(record.currency)")
                                .foregroundColor(record.type == .income ? .green : .red)
                        }

                        HStack {
                            Text("Категория:")
                            Spacer()
                            Text(record.category)
                        }

                        HStack {
                            Text("Дата:")
                            Spacer()
                            Text(formattedDate(record.date))
                        }

                        Button(action: {
                            // Применить распознанные данные к форме
                            amount = String(format: "%.2f", record.amount)
                            currency = record.currency
                            type = record.type
                            date = record.date
                            details = record.details

                            if let cat = FinanceCategory.allCases.first(where: { $0.rawValue == record.category }) {
                                category = cat
                            }
                        }) {
                            Label("Использовать данные", systemImage: "checkmark.circle.fill")
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
            .navigationTitle("Новая запись")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Сохранить") {
                        isLoadingTransaction = true
                        saveRecord()
                    }
                    .disabled(!formIsValid || isLoadingTransaction)
                }

                ToolbarItem(placement: .cancellationAction) {
                    Button("Отмена", role: .cancel) {
                        dismiss()
                    }
                }
            }
            .overlay {
                if isLoadingTransaction {
                    Color.black.opacity(0.3)
                        .edgesIgnoringSafeArea(.all)
                    ProgressView("Сохранение...")
                        .padding()
                        .background(Color.systemBackground)
                        .cornerRadius(10)
                        .shadow(radius: 5)
                }
            }
            .sheet(isPresented: $showReceiptScanner) {
                ReceiptScannerView(
                    recognizedText: $scannedText,
                    extractedFinanceRecord: $extractedFinanceRecord
                )
            }
        }
    }

    private func saveRecord() {
        // Приоритет отдается ручному вводу, затем распознанным данным
        guard let groupId = AppState.shared.user?.groupId else { return }

        let recordToSave: FinanceRecord

        if let amountValue = Double(amount.replacingOccurrences(of: ",", with: ".")), !amount.isEmpty {
            // Приоритет ручному вводу
            recordToSave = FinanceRecord(
                type: type,
                amount: amountValue,
                currency: currency.uppercased(),
                category: category.rawValue,
                details: details,
                date: date,
                receiptUrl: nil,
                groupId: groupId
            )
        } else if let extractedRecord = extractedFinanceRecord {
            // Используем распознанную запись
            recordToSave = extractedRecord
        } else {
            // Недостаточно данных
            isLoadingTransaction = false
            return
        }

        // Заменяем FinanceValidator.isValid на базовую проверку
        guard recordToSave.amount > 0 && !recordToSave.currency.isEmpty else {
            isLoadingTransaction = false
            return
        }

        FinanceService.shared.add(recordToSave) { success in
            isLoadingTransaction = false
            if success {
                // Сохраняем локально для офлайн-доступа
                OfflineFinanceManager.shared.cacheRecord(recordToSave)
                dismiss()
            }
        }
    }

    // Вспомогательный метод форматирования даты
    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    // Иконки для категорий
    private func categoryIcon(for category: FinanceCategory) -> String {
        switch category {
        case .logistics: return "car.fill"
        case .food: return "fork.knife"
        case .gear: return "guitars"
        case .promo: return "megaphone.fill"
        case .other: return "ellipsis.circle.fill"
        case .performance: return "music.note"
        case .merch: return "tshirt.fill"
        case .accommodation: return "house.fill"
        case .royalties: return "music.quarternote.3"
        case .sponsorship: return "dollarsign.circle"
        }
    }

    // Цвета для категорий
    private func categoryColor(for category: FinanceCategory) -> Color {
        switch category {
        case .logistics: return .blue
        case .food: return .orange
        case .gear: return .purple
        case .promo: return .green
        case .other: return .secondary
        case .performance: return .red
        case .merch: return .indigo
        case .accommodation: return .teal
        case .royalties: return .purple
        case .sponsorship: return .green
        }
    }
}

// Расширение для Color, добавляющее системные цвета
extension Color {
    static let systemBackground = Color(UIColor.systemBackground)
}
