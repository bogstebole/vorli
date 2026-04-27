//
//  ReceiptDetailView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header Card - Merchant Info
                VStack(spacing: 12) {
                    Text(receipt.merchantName)
                        .font(.system(.body, design: .monospaced, weight: .medium))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 4) {
                        Text(receipt.merchantAddress)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.primary)
                        
                        if !receipt.merchantCity.isEmpty {
                            Text(receipt.merchantCity)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }

                    
                    Text(receipt.timestamp.asSerbianDateTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    
                    Divider()
                    
                    // Totals Section
                    VStack(spacing: 12) {
                        HStack {
                            Text("Ukupan iznos:")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(receipt.totalAmount.asRSD)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        
                        HStack {
                            Text("PDV (20%):")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text(receipt.totalTax.asRSD)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.primary)
                        }
                        
                        HStack {
                            Text("Način plaćanja:")
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            Text(receipt.paymentMethod)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                }
                .frame(maxWidth: .infinity)
                
            
                // Articles Section
                VStack(alignment: .leading, spacing: 8) {
                    SectionDivider(title: "Artikli")
                        
                    
                    VStack(spacing: 0) {
                        ForEach(receipt.items) { item in
                            ArticleRowView(item: item)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                
                
                // Receipt Number
                VStack(spacing: 4) {
                    if !receipt.receiptNumber.isEmpty {
                        Text("PFR broj: \(receipt.receiptNumber)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    
                    if !receipt.cashRegisterNumber.isEmpty {
                        Text("ESIR: \(receipt.cashRegisterNumber)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Racun")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    shareReceipt()
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }
        }
    }
    
    private func shareReceipt() {
        // TODO: Implement sharing functionality
        print("Share receipt: \(receipt.receiptNumber)")
    }
}

// MARK: - Article Row View

struct ArticleRowView: View {
    let item: ReceiptItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Article Name
            Text(item.name)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .lineLimit(2)
            
            // Price Info
            HStack(spacing: 16) {
                // Unit Price
                HStack(spacing: 4) {
                    Text(item.unitPrice.asSerbianNumber)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text("RSD")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                // Quantity
                HStack(spacing: 4) {
                    Text("×")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(formatQuantity(item.quantity))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                // Line Total
                Text(item.lineTotal.asRSD)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
            }
        }
        .padding()

    }
    
    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }
}

#Preview {
    NavigationStack {
        ReceiptDetailView(receipt: Receipt(
            url: "https://example.com",
            merchantName: "FINEST FOOD",
            merchantAddress: "ZAPLANJSKA 43",
            merchantCity: "Beograd-Vozdovac",
            timestamp: Date(),
            totalAmount: 2880.00,
            totalTax: 480.00,
            paymentMethod: "Bezgotovinsko placanje",
            receiptNumber: "S8SMA9VT-C38FDVO0-36894",
            cashRegisterNumber: "1099/1.0.0",
            items: [
                ReceiptItem(name: "Chicken cheese fries - Standard", quantity: 1, unitPrice: 620.00, lineTotal: 620.00),
                ReceiptItem(name: "Strips 5 komada - Standard", quantity: 1, unitPrice: 860.00, lineTotal: 860.00),
                ReceiptItem(name: "Pohovano belo meso 1", quantity: 1, unitPrice: 520.00, lineTotal: 520.00),
            ]
        ))
    }
}
