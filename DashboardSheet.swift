//
//  DashboardSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

struct DashboardSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumStore.self) private var premiumStore
    let receipts: [Receipt]
    let onMonthSelected: (Date) -> Void

    @Query private var merchantCategories: [MerchantCategory]
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())
    @State private var budgetEntries: [BudgetEntry] = []
    @State private var showPaywall = false
    
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
                                
                                Text("Preostalo stanje")
                                    .font(.system(.caption, design: .default))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                
                                Text("Potrošeno")
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
                            let unlocked = PremiumStore.isMonthUnlocked(data.month, isPremium: premiumStore.isPremium)
                            MonthTileView(
                                month: data.monthName,
                                receiptCount: data.receiptCount,
                                leftOverBalance: data.leftOverBalance,
                                spent: data.spent
                            )
                            .overlay(alignment: .topTrailing) {
                                if !unlocked {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                }
                            }
                            .onTapGesture {
                                if unlocked {
                                    onMonthSelected(data.month)
                                    dismiss()
                                } else {
                                    showPaywall = true
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Spending by category for the selected year (premium)
                    if !categoryBreakdown.isEmpty && !premiumStore.isPremium {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionDivider(title: "Po kategorijama")
                            Button {
                                showPaywall = true
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: "lock.fill")
                                        .foregroundStyle(.secondary)
                                    Text("Raščlamba po kategorijama je deo Premium-a")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(14)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal)
                    } else if !categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionDivider(title: "Po kategorijama")

                            ForEach(categoryBreakdown, id: \.name) { row in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(row.name)
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundStyle(row.isUncategorized ? .secondary : .primary)
                                        Spacer()
                                        Text(MoneyFormat.grouped(row.total) + " RSD")
                                            .font(.system(.subheadline, design: .monospaced))
                                            .foregroundStyle(.secondary)
                                    }
                                    // Same bar style as the month tiles: 8pt
                                    // high, 4pt radius, solid fill.
                                    GeometryReader { geometry in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(Color(uiColor: .secondarySystemBackground))
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(row.isUncategorized ? Color.gray : Color.purple)
                                                .frame(width: geometry.size.width * row.fraction)
                                        }
                                    }
                                    .frame(height: 8)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 20)
            }
            .navigationTitle("Kontrolna tabla")
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
            .task {
                loadBudgetEntries()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
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
    
    // MARK: - Category breakdown

    private struct CategoryRow {
        let name: String
        let total: Decimal
        let fraction: Double
        let isUncategorized: Bool
    }

    /// Spending per user-assigned category for the selected year. Merchants
    /// without a category are grouped under "Bez kategorije" at the end.
    private var categoryBreakdown: [CategoryRow] {
        let calendar = Calendar.current
        let yearReceipts = receipts.filter {
            calendar.component(.year, from: $0.timestamp) == selectedYear
        }
        guard !yearReceipts.isEmpty else { return [] }

        let categoryByMerchant = Dictionary(
            merchantCategories.map { ($0.merchantKey, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        var totals: [String: Decimal] = [:]
        var uncategorized: Decimal = 0
        for receipt in yearReceipts {
            let key = PriceHistory.merchantKey(receipt.merchantName)
            if let category = categoryByMerchant[key] {
                totals[category, default: 0] += receipt.totalAmount
            } else {
                uncategorized += receipt.totalAmount
            }
        }
        // Only worth showing once at least one category is assigned.
        guard !totals.isEmpty else { return [] }

        let grandTotal = totals.values.reduce(uncategorized, +)
        let grandTotalD = (grandTotal as NSDecimalNumber).doubleValue
        guard grandTotalD > 0 else { return [] }

        func fraction(_ value: Decimal) -> Double {
            (value as NSDecimalNumber).doubleValue / grandTotalD
        }

        var rows = totals
            .map { CategoryRow(name: $0.key, total: $0.value, fraction: fraction($0.value), isUncategorized: false) }
            .sorted { $0.total > $1.total }
        if uncategorized > 0 {
            rows.append(CategoryRow(name: "Bez kategorije", total: uncategorized,
                                    fraction: fraction(uncategorized), isUncategorized: true))
        }
        return rows
    }

    // MARK: - Helper Methods

    private func loadBudgetEntries() {
        let service = ReceiptService(modelContext: modelContext)
        budgetEntries = (try? service.fetchBudgetEntries()) ?? []
    }
    
    private func formatMonthName(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        return formatter.string(from: date)
    }
    
    private func calculateLeftOverBalance(for date: Date, spent: Decimal) -> Decimal {
        let calendar = Calendar.current
        
        // Get the start and end of the month
        guard let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
              let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else {
            return 0
        }
        
        // Get all budget entries for this month
        let monthBudgetEntries = budgetEntries.filter { entry in
            calendar.isDate(entry.timestamp, equalTo: date, toGranularity: .month)
        }
        
        // Sum all budget entries added in this month
        let totalBudgetAdded = monthBudgetEntries.reduce(Decimal(0)) { $0 + $1.amount }
        
        // Leftover balance = budget added this month - spent this month
        let leftOver = totalBudgetAdded - spent
        
        return max(leftOver, 0) // Don't show negative values in the chart
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
