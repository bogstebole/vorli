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
            VStack(spacing: 24) {
                // Header Card - Merchant Info
                VStack(spacing: 12) {
                    Text(receipt.merchantName)
                        .font(.system(.title2, design: .monospaced, weight: .bold))
                        .multilineTextAlignment(.center)
                    
                    VStack(spacing: 4) {
                        Text(receipt.merchantAddress)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                        
                        if !receipt.merchantCity.isEmpty {
                            Text(receipt.merchantCity)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    
                    Divider()
                        .padding(.vertical, 4)
                    
                    Text(receipt.timestamp.asSerbianDateTime)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Articles Section
                VStack(alignment: .leading, spacing: 16) {
                    Text("АРТИКЛИ")
                        .font(.system(.caption, design: .monospaced, weight: .bold))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal)
                    
                    VStack(spacing: 12) {
                        ForEach(receipt.items) { item in
                            ArticleRowView(item: item)
                        }
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Totals Section
                VStack(spacing: 12) {
                    HStack {
                        Text("УКУПАН ИЗНОС:")
                            .font(.system(.headline, design: .monospaced))
                        Spacer()
                        Text(receipt.totalAmount.asRSD)
                            .font(.system(.title2, design: .monospaced, weight: .bold))
                            .foregroundStyle(.primary)
                    }
                    
                    Divider()
                    
                    HStack {
                        Text("ПДВ (20%):")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(receipt.totalTax.asRSD)
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    
                    HStack {
                        Text("Плаћање:")
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
                .background(.regularMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Receipt Number
                VStack(spacing: 4) {
                    if !receipt.receiptNumber.isEmpty {
                        Text("ПФР број: \(receipt.receiptNumber)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                    
                    if !receipt.cashRegisterNumber.isEmpty {
                        Text("ЕСИР: \(receipt.cashRegisterNumber)")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.quaternary)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .padding()
        }
        .navigationTitle("Рачун")
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
                        .font(.system(.caption, design: .monospaced))
                    Text("RSD")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                
                // Quantity
                HStack(spacing: 4) {
                    Text("×")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Text(formatQuantity(item.quantity))
                        .font(.system(.caption, design: .monospaced))
                }
                
                Spacer()
                
                // Line Total
                Text(item.lineTotal.asRSD)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 12))
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
            merchantAddress: "ЗАПЛАЊСКА 43",
            merchantCity: "Београд-Вождовац",
            timestamp: Date(),
            totalAmount: 2880.00,
            totalTax: 480.00,
            paymentMethod: "Безготовинско плаћање",
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
