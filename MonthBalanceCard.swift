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
        VStack(alignment: .leading, spacing: 12) {
            // Month Title
            Text(month)
                .font(.system(.title, design: .monospaced, weight: .regular))
                .foregroundStyle(.primary)
                .padding(.bottom, 8)
            
            // Current Balance
            HStack(spacing: 4) {
                Text("Current balance")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(currentBalance))
                    .font(.system(.body, design: .monospaced, weight: .regular))
                    .foregroundStyle(currentBalance >= 0 ? .primary : .primary)
            }
            
            // Spent This Month
            HStack(spacing: 4) {
                Text("Spent")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(spent))
                    .font(.system(.body, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
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
