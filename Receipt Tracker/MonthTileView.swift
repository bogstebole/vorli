//
//  MonthTileView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 20. 12. 2025..
//

import SwiftUI

struct MonthTileView: View {
    let month: String
    let receiptCount: Int
    let leftOverBalance: Decimal
    let spent: Decimal
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Month Name
            Text(month.uppercased())
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            
            // Receipt Count
            Text("\(receiptCount) \(receiptCount % 10 == 1 && receiptCount % 100 != 11 ? "račun" : "računa")")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.secondary)
            
            // Visual Bar Chart
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left over balance bar (cyan)
                    Rectangle()
                        .fill(Color.cyan)
                        .frame(width: barWidth(for: leftOverBalance, in: geometry.size.width))
                    
                    // Spent bar (purple)
                    Rectangle()
                        .fill(Color.purple)
                        .frame(width: barWidth(for: spent, in: geometry.size.width))
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            .frame(height: 8)
            .padding(.vertical, 4)
            
            // Left Over Balance
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.cyan)
                    .frame(width: 6, height: 6)
                
                Text(formatCurrency(leftOverBalance))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            // Spent Amount
            HStack(spacing: 4) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 6, height: 6)
                
                Text(formatCurrency(spent))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
    
    // MARK: - Helper Methods
    
    private func barWidth(for amount: Decimal, in totalWidth: CGFloat) -> CGFloat {
        let total = leftOverBalance + spent
        guard total > 0 else { return 0 }
        
        let percentage = CGFloat(truncating: amount as NSDecimalNumber) / CGFloat(truncating: total as NSDecimalNumber)
        return totalWidth * percentage
    }
    
    private func formatCurrency(_ amount: Decimal) -> String {
        // Serbian grouping (45.000), consistent with the rest of the app.
        MoneyFormat.grouped(amount) + " RSD"
    }
}

#Preview {
    VStack(spacing: 12) {
        MonthTileView(
            month: "January",
            receiptCount: 6,
            leftOverBalance: 45000,
            spent: 63250
        )
        
        MonthTileView(
            month: "February",
            receiptCount: 6,
            leftOverBalance: 52000,
            spent: 56500
        )
        
        MonthTileView(
            month: "March",
            receiptCount: 6,
            leftOverBalance: 48500,
            spent: 59750
        )
    }
    .padding()
}
