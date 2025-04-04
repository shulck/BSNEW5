import SwiftUI
import VisionKit
// Добавляем необходимые импорты
import Vision

struct ReceiptScannerView: UIViewControllerRepresentable {
    @Binding var recognizedText: String
    @Binding var extractedFinanceRecord: FinanceRecord?
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let controller = VNDocumentCameraViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var parent: ReceiptScannerView

        init(_ parent: ReceiptScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Обработка сканирования
            let image = scan.imageOfPage(at: 0)

            // Распознавание текста из изображения
            recognizeText(from: image)

            controller.dismiss(animated: true)
        }

        private func recognizeText(from image: UIImage) {
            guard let cgImage = image.cgImage else { return }

            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            let request = VNRecognizeTextRequest { [weak self] (request: VNRequest, error: Error?) in
                guard let observations = request.results as? [VNRecognizedTextObservation],
                      error == nil else {
                    return
                }

                let text = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")

                DispatchQueue.main.async {
                    self?.parent.recognizedText = text
                    // После распознавания текста пытаемся извлечь данные чека
                    self?.extractReceiptData(from: text)
                }
            }

            // Исправляем настройку уровня распознавания
            request.recognitionLevel = .accurate

            do {
                try requestHandler.perform([request])
            } catch {
                print("Ошибка распознавания текста: \(error)")
            }
        }

        private func extractReceiptData(from text: String) {
            // Используем ReceiptAnalyzer для извлечения данных
            let receiptData = ReceiptAnalyzer.analyze(text: text)

            // Если есть сумма, создаем финансовую запись
            if let amount = receiptData.amount,
               let groupId = AppState.shared.user?.groupId {

                let category = receiptData.category.flatMap { categoryName in
                    FinanceCategory.allCases.first { $0.rawValue == categoryName }
                } ?? .other

                let record = FinanceRecord(
                    type: .expense, // По умолчанию чеки это расходы
                    amount: amount,
                    currency: "EUR", // Используем EUR по умолчанию
                    category: category,
                    details: receiptData.merchantName ?? "",
                    date: receiptData.date ?? Date(),
                    groupId: groupId
                )

                DispatchQueue.main.async {
                    self.parent.extractedFinanceRecord = record
                }
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true)
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Document scanner error: \(error)")
            controller.dismiss(animated: true)
        }
    }
}
