//
//  OCRTestView.swift
//  Receipt Tracker
//
//  Created for debugging OCR functionality
//

import SwiftUI
import PhotosUI

struct OCRTestView: View {
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var ocrText: String?
    @State private var parsedReceipt: ParsedReceipt?
    @State private var errorMessage: String?
    @State private var showingImagePicker = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Image Picker Button
                    Button {
                        showingImagePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                            Text("Select Receipt Image")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.gradient)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isProcessing)
                    
                    // Selected Image Preview
                    if let image = selectedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 5)
                    }
                    
                    // Processing Indicator
                    if isProcessing {
                        ProgressView("Processing OCR...")
                            .padding()
                    }
                    
                    // Error Display
                    if let error = errorMessage {
                        Text("❌ Error")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    
                    // OCR Text Display
                    if let text = ocrText {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("📝 Extracted Text")
                                .font(.headline)
                            
                            ScrollView {
                                Text(text)
                                    .font(.system(.caption, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(maxHeight: 200)
                            .padding()
                            .background(Color.gray.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    
                    // Parsed Receipt Display
                    if let receipt = parsedReceipt {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("✅ Parsed Receipt")
                                .font(.headline)
                            
                            Group {
                                InfoRow(label: "Merchant", value: receipt.merchantName)
                                InfoRow(label: "Address", value: receipt.merchantAddress)
                                InfoRow(label: "City", value: receipt.merchantCity)
                                InfoRow(label: "Total", value: "\(receipt.totalAmount)")
                                InfoRow(label: "Tax", value: "\(receipt.totalTax)")
                                InfoRow(label: "Payment", value: receipt.paymentMethod)
                                InfoRow(label: "Items", value: "\(receipt.items.count)")
                            }
                            .padding(.horizontal)
                            
                            if !receipt.items.isEmpty {
                                Text("Items:")
                                    .font(.subheadline)
                                    .padding(.horizontal)
                                
                                ForEach(Array(receipt.items.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\(index + 1). \(item.name)")
                                            .font(.caption)
                                        HStack {
                                            Text("Qty: \(item.quantity, specifier: "%.2f")")
                                            Spacer()
                                            Text("Price: \(item.unitPrice)")
                                            Spacer()
                                            Text("Total: \(item.lineTotal)")
                                        }
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                    }
                                    .padding(8)
                                    .background(Color.gray.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                .padding(.horizontal)
                            }
                        }
                        .padding()
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("OCR Test")
            .sheet(isPresented: $showingImagePicker) {
                ImagePicker(image: $selectedImage) { image in
                    processImage(image)
                }
            }
        }
    }
    
    private func processImage(_ image: UIImage) {
        isProcessing = true
        ocrText = nil
        parsedReceipt = nil
        errorMessage = nil
        
        Task {
            do {
                // First, just get the OCR text
                print("🔍 Starting OCR...")
                let text = try await ReceiptOCRParser.performOCRTest(on: image)
                await MainActor.run {
                    ocrText = text
                    print("✅ OCR completed: \(text.count) characters")
                }
                
                // Then try to parse it
                print("🔧 Parsing receipt...")
                let receipt = try await ReceiptOCRParser.parseReceipt(from: image)
                await MainActor.run {
                    parsedReceipt = receipt
                    print("✅ Parsing completed!")
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    print("❌ Error: \(error)")
                }
            }
            
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

struct InfoRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label + ":")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .textSelection(.enabled)
        }
    }
}

// Simple image picker
struct ImagePicker: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    var onImageSelected: (UIImage) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .photoLibrary
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ImagePicker
        
        init(_ parent: ImagePicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onImageSelected(image)
            }
            picker.dismiss(animated: true)
        }
    }
}

#Preview {
    OCRTestView()
}
