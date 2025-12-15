//
//  DashboardSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct DashboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    let receipts: [Receipt]
    let onMonthSelected: (Date) -> Void
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Summary Card
                    VStack(spacing: 12) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.blue.gradient)
                        
                        Text("Monthly Overview")
                            .font(.system(.title3, design: .monospaced, weight: .bold))
                        
                        Text("Tap a month to view details")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Monthly breakdown
                    ForEach(monthlyData, id: \.month) { data in
                        MonthlyChartCard(
                            month: data.monthName,
                            spent: data.totalSpent,
                            receiptCount: data.receiptCount
                        )
                        .onTapGesture {
                            onMonthSelected(data.month)
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    // Calculate monthly data from receipts
    private var monthlyData: [MonthData] {
        let calendar = Calendar.current
        
        // Group receipts by month
        let grouped = Dictionary(grouping: receipts) { receipt in
            calendar.startOfMonth(for: receipt.timestamp)
        }
        
        // Create monthly data and sort by date descending
        return grouped.map { month, receipts in
            MonthData(
                month: month,
                monthName: formatMonthYear(month),
                totalSpent: receipts.reduce(Decimal(0)) { $0 + $1.totalAmount },
                receiptCount: receipts.count
            )
        }
        .sorted { $0.month > $1.month } // Most recent first
    }
    
    private func formatMonthYear(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: date)
    }
}

// MARK: - Month Data Model

struct MonthData {
    let month: Date
    let monthName: String
    let totalSpent: Decimal
    let receiptCount: Int
}

// MARK: - Monthly Chart Card

struct MonthlyChartCard: View {
    let month: String
    let spent: Decimal
    let receiptCount: Int
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                Text(month)
                    .font(.system(.headline, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "cart.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        
                        Text("\(receiptCount) receipts")
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatCurrency(spent))
                    .font(.system(.title3, design: .monospaced, weight: .bold))
                    .foregroundStyle(.red)
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
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

// MARK: - Calendar Extension

extension Calendar {
    func startOfMonth(for date: Date) -> Date {
        let components = dateComponents([.year, .month], from: date)
        return self.date(from: components) ?? date
    }
}

#Preview {
    DashboardSheet(
        receipts: [
            Receipt(
                url: "https://example.com",
                merchantName: "Store 1",
                merchantAddress: "Address",
                merchantCity: "City",
                timestamp: Date(),
                totalAmount: 1000,
                totalTax: 100,
                paymentMethod: "Card",
                receiptNumber: "123",
                cashRegisterNumber: "456"
            )
        ],
        onMonthSelected: { _ in }
    )
}
