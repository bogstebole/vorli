//
//  ReceiptCardView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct ReceiptCardView: View {
    let receipt: Receipt
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Company Name
            HStack(alignment: .top, spacing: 16) {
                Text(receipt.merchantName)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                
                Spacer()
                
                // Amount
                Text(formatCurrency(receipt.totalAmount))
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .padding(0)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            
            
            HStack {
                // Date and Time — Serbian, not the device locale
                HStack(spacing: 6) {
                    Text(Self.dateFormatter.string(from: receipt.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)

                    Text("•")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Text(Self.timeFormatter.string(from: receipt.timestamp))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "d. MMM yyyy"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "HH:mm"
        return f
    }()

    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RSD"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: amount as NSDecimalNumber) ?? "0 RSD"
    }
}

#Preview {
    ReceiptCardView(receipt: Receipt(
        url: "https://example.com",
        merchantName: "FINEST FOOD",
        merchantAddress: "ZAPLANJSKA 43",
        merchantCity: "Beograd-Vozdovac",
        timestamp: Date(),
        totalAmount: 2880.00,
        totalTax: 480.00,
        paymentMethod: "Bezgotovinsko placanje",
        receiptNumber: "S8SMA9VT-C38FDVO0-36894",
        cashRegisterNumber: "1099/1.0.0"
    ))
    .padding()
}
