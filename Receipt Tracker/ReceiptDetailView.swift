//
//  ReceiptDetailView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

struct ReceiptDetailView: View {
    let receipt: Receipt
    @Environment(\.dismiss) private var dismiss
    @Environment(PremiumStore.self) private var premiumStore
    @Query private var allReceipts: [Receipt]
    @Query private var merchantCategories: [MerchantCategory]
    @State private var historyItem: ReceiptItem?
    @State private var showCategoryPicker = false
    @State private var showPaywall = false

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header Card - Merchant Info
                VStack(spacing: 12) {
                    // Category chip — assigned by the user, per merchant.
                    Button {
                        showCategoryPicker = true
                    } label: {
                        if let category {
                            Text(category.name)
                                .font(.system(.caption, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.5))
                                .clipShape(Capsule())
                        } else {
                            Label {
                                Text("Kategorija")
                            } icon: {
                                TablerIcon("plus", size: 12)
                            }
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                                .background(.quaternary.opacity(0.5))
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)

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
                            let history = PriceHistory.history(for: item, in: allReceipts)
                            ArticleRowView(
                                item: item,
                                change: PriceHistory.change(for: item, in: allReceipts),
                                hasHistory: history.count >= 2
                            ) {
                                // Change badge is the free teaser; the full
                                // price history is premium.
                                if premiumStore.isPremium {
                                    historyItem = item
                                } else {
                                    showPaywall = true
                                }
                            }
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
        .monoNavigationTitle("Racun")
        .sheet(item: $historyItem) { item in
            PriceHistorySheet(item: item)
        }
        .sheet(isPresented: $showCategoryPicker) {
            CategoryPickerSheet(merchantName: receipt.merchantName)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        // Share button removed until sharing is actually implemented —
        // non-functional controls are an App Review rejection risk.
    }

    /// User-assigned category for this receipt's merchant, if any.
    private var category: MerchantCategory? {
        let key = PriceHistory.merchantKey(receipt.merchantName)
        return merchantCategories.first { $0.merchantKey == key }
    }
}

// MARK: - Article Row View

struct ArticleRowView: View {
    let item: ReceiptItem
    var change: PriceHistory.Change? = nil
    var hasHistory: Bool = false
    var onHistoryTap: () -> Void = {}

    var body: some View {
        Button(action: { if hasHistory { onHistoryTap() } }) {
            VStack(alignment: .leading, spacing: 8) {
                // Article Name + price change vs previous purchase
                HStack(alignment: .top, spacing: 8) {
                    Text(item.name)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    Spacer()

                    if let change {
                        PriceChangeBadge(change: change)
                    }
                }

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

                    if hasHistory {
                        TablerIcon("chevron-right", size: 12)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding()
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func formatQuantity(_ quantity: Double) -> String {
        if quantity.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", quantity)
        } else {
            return String(format: "%.2f", quantity)
        }
    }
}

// MARK: - Price Change Badge

struct PriceChangeBadge: View {
    let change: PriceHistory.Change

    private var tint: Color { change.isIncrease ? .orange : .green }

    var body: some View {
        Text("\(change.isIncrease ? "▲ +" : "▼ −")\(change.percentText)%")
            .font(.system(.caption2, design: .monospaced, weight: .semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
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
