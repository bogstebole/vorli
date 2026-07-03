// Debug-only screen — compiled out of release builds.
#if DEBUG
//
//  DebugParserView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

/// Debug view to test parser output
struct DebugParserView: View {
    @State private var isLoading = false
    @State private var parsedReceipt: ParsedReceipt?
    @State private var errorMessage: String?
    
    private let testURL = "https://suf.purs.gov.rs/v/?vl=AzRUOUpOOVZHNFQ5Sk45VkcWxgAA7qwAABCHPQgAAAAAAAABmqbMEogAAABdMzXT8/YZwZB1Ik5vOgoMg+PdpM6Ylru25/vnBD5zKf1ZV/d6qah8NlQf1kEzXglOqc5y7A/37F6E3UO5xPMCKMAg5/tWDRubiMaDaPLK9Fv/DXY6ED/H4TY2pi0sacHTUB30WXX1R5bqQ+4TExniiQRq5CyPFRVrJkBqaP7TEasM6rgFnYNzhKyLljOMa6xHkS3LwqQMIqKvSwuxw3qR3y71b2mOaxrwSC1wN0pDVRfVt7HB1XWEOaK6qOgJw/N5tfRXu6wiiBW/WgIzF364QMUu4vHW3JidwUpxkNcsyuOHboXIk/Q8x1BN1b5SxezE98ycxbhbj2Wicmg+bJVwPdo7vqpM0q7oIyt8gx4N37B0FYi7iYJ0gIXIO9AppmffqmpNSrmZp+aT+SkROHwOIVYIUytcCytaxr3imSlpcTp/BLdhlgugEZ54nNK9eAwfx/PnfwBk8tTSqLj/d0z+HP6H2zeGKQh9qgIfqQSuavmOCuGQqQr4vCHHdwVD6rnCSu56Dw3yscp0+vnexhXenDMvyrVqCrjUDFFTiP068pV4BbW7QCaZPJb3HGW/SI9MgOf/GycOetfEsJyyrPMaVhSKXFBMQBpwo5ggtSy07XxpiULpBf/jExtPtHQc+Gj66duVN99i+G7805twEA7+1SYq2rHB6l6OCks9Cdm21uT5/xKFZJ6UZeibOht1cv4%3D"
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Parse Button
                    Button {
                        Task {
                            await parseReceipt()
                        }
                    } label: {
                        HStack {
                            if isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Image(systemName: "arrow.down.doc")
                            }
                            Text("Parse Test Receipt")
                                .font(.system(.body, design: .monospaced))
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue.gradient)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                    }
                    .disabled(isLoading)
                    
                    // Error Message
                    if let error = errorMessage {
                        Text("❌ Error: \(error)")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.red)
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.red.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Parsed Data Display
                    if let receipt = parsedReceipt {
                        VStack(alignment: .leading, spacing: 16) {
                            // Merchant Info
                            SectionView(title: "🏪 Merchant Info") {
                                DataRow(label: "Name", value: receipt.merchantName)
                                DataRow(label: "Address", value: receipt.merchantAddress)
                                DataRow(label: "City", value: receipt.merchantCity)
                            }
                            
                            // Transaction Info
                            SectionView(title: "📅 Transaction") {
                                DataRow(label: "Date/Time", value: receipt.timestamp.asSerbianDateTime)
                                DataRow(label: "Receipt #", value: receipt.receiptNumber)
                                DataRow(label: "Cash Register", value: receipt.cashRegisterNumber)
                                DataRow(label: "Payment", value: receipt.paymentMethod)
                            }
                            
                            // Totals
                            SectionView(title: "💰 Totals") {
                                DataRow(label: "Total Amount", value: receipt.totalAmount.asRSD)
                                DataRow(label: "Total Tax", value: receipt.totalTax.asRSD)
                            }
                            
                            // Articles
                            SectionView(title: "🛒 Articles (\(receipt.items.count))") {
                                ForEach(Array(receipt.items.enumerated()), id: \.offset) { index, item in
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("\(index + 1). \(item.name)")
                                            .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                                        
                                        HStack {
                                            Text("Price: \(item.unitPrice.asSerbianNumber) RSD")
                                                .font(.system(.caption, design: .monospaced))
                                            Spacer()
                                            Text("Qty: \(formatQuantity(item.quantity))")
                                                .font(.system(.caption, design: .monospaced))
                                            Spacer()
                                            Text("Total: \(item.lineTotal.asRSD)")
                                                .font(.system(.caption, design: .monospaced, weight: .medium))
                                        }
                                        .foregroundStyle(.secondary)
                                    }
                                    .padding()
                                    .background(.quaternary.opacity(0.3))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Parser Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func parseReceipt() async {
        isLoading = true
        errorMessage = nil
        parsedReceipt = nil
        
        do {
            let receipt = try await ReceiptParser.parseReceipt(from: testURL)
            parsedReceipt = receipt
        } catch {
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }
}

// MARK: - Helper Views

struct SectionView<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.primary)
            
            VStack(alignment: .leading, spacing: 8) {
                content
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

struct DataRow: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
    }
}

#Preview {
    DebugParserView()
}
#endif
