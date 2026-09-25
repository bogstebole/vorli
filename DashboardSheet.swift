//
//  DashboardSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(PremiumStore.self) private var premiumStore
    @Environment(AppNavigation.self) private var nav

    @Query(sort: \Receipt.timestamp, order: .reverse) private var receipts: [Receipt]
    @Query private var merchantCategories: [MerchantCategory]
    @Query private var fixedCosts: [FixedCost]
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
                            Button {
                                changeYear(by: -1)
                            } label: {
                                TablerIcon("chevron-left", size: 20)
                                    .foregroundStyle(canGoBack ? .secondary : .quaternary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canGoBack)

                            Text(String(format: "%d", selectedYear))
                                .font(.system(.largeTitle, design: .monospaced, weight: .medium))
                                .foregroundStyle(.primary)
                                .contentTransition(.numericText())

                            Button {
                                changeYear(by: 1)
                            } label: {
                                TablerIcon("chevron-right", size: 20)
                                    .foregroundStyle(canGoForward ? .secondary : .quaternary)
                                    .frame(width: 44, height: 44)
                                    .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .disabled(!canGoForward)
                        }

                        // Total spent in the selected year
                        VStack(spacing: 2) {
                            Text(MoneyFormat.grouped(yearTotalSpent) + " RSD")
                                .font(.system(.subheadline, design: .monospaced, weight: .medium))
                                .contentTransition(.numericText())
                            Text("ukupno potrošeno")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }

                        // Legend
                        HStack(spacing: 20) {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.cyan)
                                    .frame(width: 8, height: 8)
                                
                                Text("Preostalo stanje")
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                            
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purple)
                                    .frame(width: 8, height: 8)
                                
                                Text("Potrošeno")
                                    .font(.system(.caption, design: .monospaced))
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
                                    TablerIcon("lock", size: 12)
                                        .foregroundStyle(.secondary)
                                        .padding(8)
                                }
                            }
                            .onTapGesture {
                                if unlocked {
                                    nav.selectedMonth = data.month
                                    nav.selectedTab = .home
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
                                HStack(spacing: 12) {
                                    TablerIcon("lock", size: 16)
                                        .foregroundStyle(.secondary)
                                    Text("Raščlamba po kategorijama je deo Premium-a")
                                        .font(.system(.caption, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                    TablerIcon("chevron-right", size: 12)
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(16)
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
                                VStack(alignment: .leading, spacing: 8) {
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
            .monoNavigationTitle("Kontrolna tabla")
            // simultaneousGesture so the vertical ScrollView doesn't swallow
            // the swipe; the dominance check keeps diagonal scrolls from
            // accidentally flipping the year.
            .simultaneousGesture(
                DragGesture(minimumDistance: 30)
                    .onEnded { value in
                        let horizontal = value.translation.width
                        let vertical = value.translation.height
                        guard abs(horizontal) > 60, abs(horizontal) > abs(vertical) * 1.5 else { return }
                        // Swipe right = previous year, swipe left = next.
                        changeYear(by: horizontal > 0 ? -1 : 1)
                    }
            )
            .task {
                loadBudgetEntries()
            }
            .sheet(isPresented: $showPaywall) {
                PaywallSheet()
            }
        }
    }
    
    // MARK: - Year navigation

    /// Navigable range: from the oldest year with a receipt up to the current
    /// year — no wandering into empty future or pre-data years.
    private var yearRange: ClosedRange<Int> {
        let calendar = Calendar.current
        let current = calendar.component(.year, from: Date())
        let oldest = receipts.map { calendar.component(.year, from: $0.timestamp) }.min() ?? current
        return min(oldest, current)...current
    }

    private var canGoBack: Bool { selectedYear > yearRange.lowerBound }
    private var canGoForward: Bool { selectedYear < yearRange.upperBound }

    /// Spent in the selected year — the month tiles added up, fixed costs
    /// included.
    private var yearTotalSpent: Decimal {
        monthlyDataForYear.reduce(Decimal(0)) { $0 + $1.spent }
    }

    private func changeYear(by delta: Int) {
        let target = selectedYear + delta
        guard yearRange.contains(target) else { return }
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            selectedYear = target
        }
    }

    // MARK: - Computed Properties

    /// The same month figures Home shows — receipts plus fixed costs against
    /// the month's income — so a tile never disagrees with its Home page.
    private var monthIndex: MonthIndex {
        MonthIndex(
            receipts: receipts,
            budgetEntries: budgetEntries,
            fixedCosts: FinanceCalculator.activeFixedTotal(fixedCosts),
            including: Date()
        )
    }

    // Calculate monthly data for all 12 months of the selected year
    private var monthlyDataForYear: [MonthData] {
        let calendar = Calendar.current
        let index = monthIndex
        // Home's range: first month on record through the current one. Months
        // outside it have nothing yet, fixed costs included.
        let onRecord = Set(index.months)

        var allMonths: [MonthData] = []

        for monthIndex in 1...12 {
            guard let monthDate = calendar.date(from: DateComponents(year: selectedYear, month: monthIndex, day: 1)) else {
                continue
            }

            let receiptCount = receipts.filter { receipt in
                calendar.isDate(receipt.timestamp, equalTo: monthDate, toGranularity: .month)
            }.count

            var spent: Decimal = 0
            var leftOverBalance: Decimal = 0
            if onRecord.contains(monthDate) {
                let figures = index.figures(for: monthDate)
                spent = figures.spent
                // Don't show negative values in the chart
                leftOverBalance = max(figures.income - figures.spent, 0)
            }

            allMonths.append(MonthData(
                month: monthDate,
                monthIndex: monthIndex,
                monthName: formatMonthName(monthDate),
                spent: spent,
                leftOverBalance: leftOverBalance,
                receiptCount: receiptCount
            ))
        }

        return allMonths
    }

    /// Fixed costs for the selected year: one month's worth for every month
    /// on record in it, as the tiles count them.
    private var yearFixedCosts: Decimal {
        let perMonth = FinanceCalculator.activeFixedTotal(fixedCosts)
        let calendar = Calendar.current
        let months = monthIndex.months.filter { calendar.component(.year, from: $0) == selectedYear }
        return perMonth * Decimal(months.count)
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
        // Same row the month's category breakdown has.
        if yearFixedCosts > 0 {
            totals["Fiksni troškovi"] = yearFixedCosts
        }
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
    DashboardView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
        .environment(AppNavigation())
        .environment(PremiumStore())
}
