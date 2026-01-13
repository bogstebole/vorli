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
                // Date and Time
                HStack(spacing: 6) {
                    Text(receipt.timestamp, style: .date)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    Text("•")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    
                    Text(receipt.timestamp, style: .time)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.04), radius: 1.5, x: 0, y: 1)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.03), radius: 3, x: 0, y: 6)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.02), radius: 4, x: 0, y: 13)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.01), radius: 4.5, x: 0, y: 24)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0), radius: 5, x: 0, y: 37)
    }
    
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
