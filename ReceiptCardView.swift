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
        VStack(alignment: .leading, spacing: 12) {
            // Company Name
            Text(receipt.merchantName)
                .font(.system(.headline, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            HStack {
                // Date and Time
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    
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
                
                Spacer()
                
                // Amount
                Text(formatCurrency(receipt.totalAmount))
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(.primary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
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
        merchantAddress: "ЗАПЛАЊСКА 43",
        merchantCity: "Београд-Вождовац",
        timestamp: Date(),
        totalAmount: 2880.00,
        totalTax: 480.00,
        paymentMethod: "Безготовинско плаћање",
        receiptNumber: "S8SMA9VT-C38FDVO0-36894",
        cashRegisterNumber: "1099/1.0.0"
    ))
    .padding()
}
