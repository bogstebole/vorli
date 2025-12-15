//
//  MonthBalanceCard.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct MonthBalanceCard: View {
    let month: String
    let currentBalance: Decimal
    let spent: Decimal
    
    var body: some View {
        VStack(spacing: 16) {
            // Month Title
            Text(month)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                .foregroundStyle(.secondary)
            
            // Current Balance
            VStack(spacing: 4) {
                Text("Current balance")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                
                Text(formatCurrency(currentBalance))
                    .font(.system(.title, design: .monospaced, weight: .bold))
                    .foregroundStyle(currentBalance >= 0 ? .primary : .red)
            }
            
            Divider()
                .padding(.horizontal, 20)
            
            // Spent This Month
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Spent")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    
                    Text(formatCurrency(spent))
                        .font(.system(.title3, design: .monospaced, weight: .semibold))
                        .foregroundStyle(.red)
                }
                
                Spacer()
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .frame(maxWidth: .infinity)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 20))
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
    MonthBalanceCard(
        month: "December 2025",
        currentBalance: 15420.00,
        spent: 8650.00
    )
    .padding()
}
