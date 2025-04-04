//
//  SetlistExportView.swift
//  BandSync
//
//  Created by Oleksandr Kuziakin on 31.03.2025.
//


//
//  SetlistExportView.swift
//  BandSync
//
//  Created by Claude AI on 31.03.2025.
//

import SwiftUI
import PDFKit

struct SetlistExportView: View {
    let setlist: Setlist
    @State private var pdfData: Data?
    @State private var isExporting = false
    @State private var showShareSheet = false
    @State private var errorMessage: String?
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        VStack {
            if let pdfData = pdfData, let pdfDocument = PDFDocument(data: pdfData) {
                PDFPreviewView(document: pdfDocument)
                    .padding()
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "doc.text")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 100, height: 100)
                        .foregroundColor(.gray)
                    
                    Text("PDF Preview")
                        .font(.title2)
                    
                    Text("Setlist: \(setlist.name)")
                        .font(.headline)
                    
                    Text("\(setlist.songs.count) songs • \(setlist.formattedTotalDuration)")
                        .foregroundColor(.secondary)
                }
                .padding()
            }
            
            Spacer()
            
            // Action buttons
            VStack(spacing: 16) {
                Button {
                    generatePDF()
                } label: {
                    Label("Create PDF", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                
                Button {
                    showShareSheet = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(pdfData == nil ? Color.gray : Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                }
                .disabled(pdfData == nil)
            }
            .padding()
            
            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .padding()
            }
        }
        .navigationTitle("Export Setlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("Close") {
                    dismiss()
                }
            }
        }
        .overlay(Group {
            if isExporting {
                VStack {
                    ProgressView()
                    Text("Generating PDF...")
                }
                .padding()
                .background(Color.white.opacity(0.9))
                .cornerRadius(10)
                .shadow(radius: 5)
            }
        })
        .onAppear {
            generatePDF()
        }
        .sheet(isPresented: $showShareSheet) {
            if let pdfData = pdfData {
                ShareSheet(items: [pdfData])
            }
        }
    }
    
    // PDF Generation
    private func generatePDF() {
        isExporting = true
        errorMessage = nil
        
        DispatchQueue.global(qos: .userInitiated).async {
            let generatedPDF = SetlistPDFExporter.export(setlist: setlist)
            
            DispatchQueue.main.async {
                isExporting = false
                
                if let pdf = generatedPDF {
                    pdfData = pdf
                } else {
                    errorMessage = "Failed to create PDF. Please try again."
                }
            }
        }
    }
}

// PDF Preview View
struct PDFPreviewView: UIViewRepresentable {
    let document: PDFDocument
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}

// Share Sheet View
struct ShareSheet: UIViewControllerRepresentable {
    var items: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}