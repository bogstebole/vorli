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
            // Month Title with different colors for month and year
            HStack(spacing: 4) {
                Text(monthName)
                    .font(.system(.title, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
                
                Text(yearString)
                    .font(.system(.title, design: .monospaced, weight: .regular))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 6)
            
            // Current Balance
            HStack(spacing: 4) {
                Text("Current balance:")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(currentBalance))
                    .font(.system(.body, design: .monospaced, weight: .regular))
                    .foregroundStyle(currentBalance >= 0 ? .primary : .primary)
            }
            
            // Spent This Month
            HStack(spacing: 4) {
                Text("Spent:")
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(.secondary)
                
                Text(formatCurrency(spent))
                    .font(.system(.body, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
            }
            
            Spacer()
        }
        .padding(.top, 16)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Computed Properties
    
    private var monthName: String {
        // Extract month name from the month string (e.g., "December" from "December 2025")
        let components = month.components(separatedBy: " ")
        return components.first ?? month
    }
    
    private var yearString: String {
        // Extract year from the month string (e.g., "2025" from "December 2025")
        let components = month.components(separatedBy: " ")
        return components.count > 1 ? components.last ?? "" : ""
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = ","
        formatter.decimalSeparator = "."
        let formattedNumber = formatter.string(from: amount as NSDecimalNumber) ?? "0.00"
        return "\(formattedNumber) RSD"
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
