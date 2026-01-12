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
    
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Year Header with swipe indicators
                    VStack(spacing: 12) {
                        HStack(spacing: 16) {
                            Image(systemName: "chevron.left")
                                .font(.system(.title3, weight: .semibold))
                                .foregroundStyle(.secondary)
                            
                            Text(String(format: "%d", selectedYear))
                                .font(.system(.largeTitle, design: .default, weight: .bold))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())
                            
                            Image(systemName: "chevron.right")
                                .font(.system(.title3, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        
                        // Legend
                        HStack(spacing: 20) {
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 8, height: 8)
                                
                                Text("Left over balance")
                                    .font(.system(.caption, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                
                                Text("Spent")
                                    .font(.system(.caption, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.top, 8)
                    
                    // Monthly Grid
                    LazyVGrid(columns: [
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12),
                        GridItem(.flexible(), spacing: 12)
                    ], spacing: 12) {
                        ForEach(monthlyDataForYear, id: \.monthIndex) { data in
                            MonthTileView(
                                month: data.monthName,
                                receiptCount: data.receiptCount,
                                leftOverBalance: data.leftOverBalance,
                                spent: data.spent
                            )
                            .onTapGesture {
                                onMonthSelected(data.month)
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .gesture(
                DragGesture(minimumDistance: 50)
                    .onEnded { value in
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                            if value.translation.width > 0 {
                                // Swipe right - go to previous year
                                selectedYear -= 1
                            } else {
                                // Swipe left - go to next year
                                selectedYear += 1
                            }
                        }
                    }
            )
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
    }
    
    // MARK: - Computed Properties
    
    // Calculate monthly data for all 12 months of the selected year
    private var monthlyDataForYear: [MonthData] {
        let calendar = Calendar.current
        
        // Get all months for the selected year
        var allMonths: [MonthData] = []
        
        for monthIndex in 1...12 {
            guard let monthDate = calendar.date(from: DateComponents(year: selectedYear, month: monthIndex, day: 1)) else {
                continue
            }
            
            // Filter receipts for this specific month
            let monthReceipts = receipts.filter { receipt in
                calendar.isDate(receipt.timestamp, equalTo: monthDate, toGranularity: .month)
            }
            
            // Calculate spent amount
            let spent = monthReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
            
            // For demonstration, we'll use a placeholder for leftOverBalance
            // In a real app, you'd calculate this from Budget history or other data
            let leftOverBalance = calculateLeftOverBalance(for: monthDate, spent: spent)
            
            allMonths.append(MonthData(
                month: monthDate,
                monthIndex: monthIndex,
                monthName: formatMonthName(monthDate),
                spent: spent,
                leftOverBalance: leftOverBalance,
                receiptCount: monthReceipts.count
            ))
        }
        
        return allMonths
    }
    
    // MARK: - Helper Methods
    
    private func formatMonthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "en_US")
        return formatter.string(from: date)
    }
    
    private func calculateLeftOverBalance(for date: Date, spent: Decimal) -> Decimal {
        // Return 0 if there's no budget data
        // In the future, you can integrate with actual budget tracking
        return 0
    }
}

// MARK: - Month Data Model

struct MonthData {
    let month: Date
    let monthIndex: Int
    let monthName: String
    let spent: Decimal
    let leftOverBalance: Decimal
    let receiptCount: Int
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
                totalAmount: 63250,
                totalTax: 10000,
                paymentMethod: "Card",
                receiptNumber: "123",
                cashRegisterNumber: "456"
            ),
            Receipt(
                url: "https://example.com",
                merchantName: "Store 2",
                merchantAddress: "Address",
                merchantCity: "City",
                timestamp: Calendar.current.date(byAdding: .month, value: -1, to: Date())!,
                totalAmount: 56500,
                totalTax: 9000,
                paymentMethod: "Card",
                receiptNumber: "124",
                cashRegisterNumber: "456"
            )
        ],
        onMonthSelected: { _ in }
    )
}
