//
//  ContentView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @Query(sort: \BudgetEntry.timestamp, order: .reverse) private var budgetEntries: [BudgetEntry]
    @Query private var fixedCosts: [FixedCost]
    @Query private var merchantCategories: [MerchantCategory]

    @Environment(AppNavigation.self) private var nav

    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showOnboarding = false

    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showSettings = false
    @State private var showVorli = false
    @State private var scannedReceipt: Receipt?
    @State private var pendingReceipt: ParsedReceipt?

    var body: some View {
        @Bindable var nav = nav
        return NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        SummaryHeaderCard(
                            month: nav.selectedMonth,
                            balance: currentMonthLeftoverBalance,
                            spent: currentMonthSpent,
                            spentToday: currentDaySpent,
                            categories: displayCategoryRows,
                            onSettings: { showSettings = true }
                        )

                        if filteredReceipts.isEmpty {
                            EmptyReceiptsView()
                                .padding(.top, 40)
                        } else {
                            receiptsSection
                        }
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
            .alert("Greška", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            // Full screen, not a sheet: the document scanner is always full
            // screen, so QR ↔ Račun stays frame-to-frame without the sheet
            // chrome jumping in between.
            .fullScreenCover(isPresented: $nav.showScanner) {
                QRScannerView { url in
                    Task { await processReceipt(from: url) }
                } onReceiptParsed: { parsed in
                    pendingReceipt = parsed
                }
            }
            .sheet(item: $pendingReceipt) { parsed in
                ReceiptConfirmView(parsed: parsed) { receipt in
                    scannedReceipt = receipt
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            // COMMENTED OUT FOR FIRST RELEASE - VORLI AI NOT SHIPPING YET
            // .fullScreenCover(isPresented: $showVorli) {
            //     VorliChatView()
            // }
            .navigationDestination(item: $scannedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView { startScanning in
                    onboardingCompleted = true
                    showOnboarding = false
                    if startScanning {
                        nav.showScanner = true
                    }
                }
            }
        }
        .task {
            migrateSavingsGoalsIfNeeded()
            backfillNormalizedItemNamesIfNeeded()
            autoAddMonthlyIncomeIfNeeded()
            if !onboardingCompleted {
                showOnboarding = true
            }
        }
        // Also react while running — lets the dev "show onboarding again"
        // button work without an app restart.
        .onChange(of: onboardingCompleted) { _, completed in
            if !completed {
                showOnboarding = true
            }
        }
    }

    // MARK: - Sections

    /// Every receipt of the month on screen, grouped by day. The day headers
    /// carry the structure — no section title above them.
    private var receiptsSection: some View {
        LazyVStack(spacing: 12) {
            ForEach(receiptsByDay, id: \.day) { group in
                dayHeader(day: group.day, total: group.total)
                    .padding(.top, 4)
                ForEach(group.receipts) { receipt in
                    receiptRow(receipt)
                }
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    // MARK: - Row builders

    @ViewBuilder
    private func receiptRow(_ receipt: Receipt) -> some View {
        NavigationLink {
            ReceiptDetailView(receipt: receipt)
        } label: {
            ReceiptCardView(receipt: receipt)
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button(role: .destructive) {
                deleteReceipt(receipt)
            } label: {
                Label {
                    Text("Obriši")
                } icon: {
                    TablerIcon("trash", size: 16)
                }
            }
        }
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMM"
        return f
    }()

    private func dayHeader(day: Date, total: Decimal) -> some View {
        HStack {
            // Only the weekday is capitalised — Serbian months are lowercase.
            Text(Self.dayHeaderFormatter.string(from: day).sentenceCased)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Text(MoneyFormat.grouped(total) + " RSD")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        // Match ReceiptCardView's inner padding so the header lines up with
        // the card's merchant name.
        .padding(.horizontal, 16)
    }

    // MARK: - Computed Properties

    /// The month's receipts grouped by calendar day, newest day first.
    private var receiptsByDay: [(day: Date, total: Decimal, receipts: [Receipt])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: filteredReceipts) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return groups.keys.sorted(by: >).map { day in
            let dayReceipts = (groups[day] ?? []).sorted { $0.timestamp > $1.timestamp }
            let total = dayReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
            return (day: day, total: total, receipts: dayReceipts)
        }
    }

    /// Spending per category for the month on screen, largest first. Includes
    /// fixed costs, so the rows add up to the header's "spent" figure.
    private var categoryRows: [CategorySpending.Row] {
        CategorySpending.rows(
            for: filteredReceipts,
            categories: merchantCategories,
            fixedCosts: fixedCostsTotal
        )
    }

    /// Bars for the chart: the biggest categories, then the folded remainder,
    /// then uncategorised spending.
    ///
    /// "Bez kategorije" always keeps its own bar. It is appended after sorting,
    /// so a plain top-N cut would swallow it into the remainder even when it is
    /// the largest bucket — and "how much haven't I labelled" is exactly what
    /// the user needs to see. The fold is named "+N drugih" rather than
    /// "Ostalo" so it can't collide with a category the user named that (equal
    /// x values make Swift Charts stack the bars on top of each other).
    private var displayCategoryRows: [CategorySpending.Row] {
        let maxBars = 5
        let rows = categoryRows
        let real = rows.filter { !$0.isUncategorized }
        let uncategorised = rows.filter(\.isUncategorized)

        let realSlots = maxBars - uncategorised.count
        let bars: [CategorySpending.Row]
        if real.count > realSlots {
            let folded = real.dropFirst(realSlots - 1)
            let foldRow = CategorySpending.Row(
                name: "+\(folded.count) drugih",
                total: folded.reduce(Decimal(0)) { $0 + $1.total },
                fraction: folded.reduce(0.0) { $0 + $1.fraction },
                isUncategorized: true
            )
            bars = Array(real.prefix(realSlots - 1)) + [foldRow] + uncategorised
        } else {
            bars = real + uncategorised
        }

        // Descending by amount so the chart is a clean staircase — the folded
        // and uncategorised buckets can easily outweigh a named category, and
        // parking them at the end made the bar heights jump around.
        return bars.sorted { $0.total > $1.total }
    }

    private var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter { receipt in
            calendar.isDate(receipt.timestamp, equalTo: nav.selectedMonth, toGranularity: .month)
        }
    }

    private var fixedCostsTotal: Decimal {
        fixedCosts.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.iznos }
    }

    private var currentMonthSpent: Decimal {
        let receiptsSpent = filteredReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
        return receiptsSpent + fixedCostsTotal
    }

    private var currentDaySpent: Decimal {
        let calendar = Calendar.current
        let today = Date()
        return filteredReceipts.filter { receipt in
            calendar.isDate(receipt.timestamp, inSameDayAs: today)
        }.reduce(Decimal(0)) { $0 + $1.totalAmount }
    }

    private var currentMonthLeftoverBalance: Decimal {
        let calendar = Calendar.current
        let monthBudgetEntries = budgetEntries.filter { entry in
            calendar.isDate(entry.timestamp, equalTo: nav.selectedMonth, toGranularity: .month)
        }
        let totalBudgetAdded = monthBudgetEntries.reduce(Decimal(0)) { $0 + $1.amount }
        return totalBudgetAdded - currentMonthSpent
    }

    // MARK: - Methods

    /// One-time migration of legacy SavingsGoal records into the new Wish model.
    private func migrateSavingsGoalsIfNeeded() {
        let flagKey = "savingsGoalsMigratedToWish"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let goals = (try? modelContext.fetch(FetchDescriptor<SavingsGoal>())) ?? []
        for goal in goals {
            let wish = Wish(naziv: goal.naziv, cilj: goal.ciljniIznos, rok: goal.rok)
            modelContext.insert(wish)
            modelContext.delete(goal)
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    /// One-time backfill of ReceiptItem.normalizedName. v2: recomputes ALL
    /// items (not just empty ones) because normalize() now transliterates
    /// Cyrillic — keys computed by the old version would not match.
    private func backfillNormalizedItemNamesIfNeeded() {
        let flagKey = "receiptItemNormalizedNamesBackfilled_v2"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }

        let items = (try? modelContext.fetch(FetchDescriptor<ReceiptItem>())) ?? []
        for item in items {
            item.normalizedName = PriceHistory.normalize(item.name)
        }
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    private func autoAddMonthlyIncomeIfNeeded() {
        guard let amount = MonthlyIncomeScheduler.shouldAutoAdd() else { return }
        let entry = BudgetEntry(amount: amount, timestamp: Date(), note: "mesecna_zarada")
        modelContext.insert(entry)
        MonthlyIncomeScheduler.recordAutoAdd()
    }

    private func processReceipt(from urlString: String) async {
        do {
            let service = ReceiptService(modelContext: modelContext)
            let receipt = try await service.processReceipt(from: urlString)
            scannedReceipt = receipt
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func processReceiptImage(_ image: UIImage) async {
        debugLog("📸 ContentView.processReceiptImage called with image: \(image.size)")
        do {
            let service = ReceiptService(modelContext: modelContext)
            debugLog("🔧 Calling service.processReceiptImage")
            let receipt = try await service.processReceiptImage(image)
            debugLog("✅ Receipt processed successfully: \(receipt.merchantName)")
            scannedReceipt = receipt
        } catch {
            debugLog("❌ Error in processReceiptImage: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteReceipt(_ receipt: Receipt) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.deleteReceipt(receipt)
    }

}

// MARK: - Custom Header

struct CustomHeader: View {
    @Binding var showSettings: Bool

    var body: some View {
        HStack {
            Text("Računi")
                .font(.system(.title3, design: .monospaced, weight: .regular))
                .foregroundStyle(.primary)

            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
}

// MARK: - Empty State

struct EmptyReceiptsView: View {
    var body: some View {
        VStack(spacing: 16) {
            TablerIcon("receipt", size: 60)
                .foregroundStyle(.tertiary)

            Text("Nema računa ovog meseca")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Skenirajte QR kod da dodate prvi račun")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .padding(.vertical, 40)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
        .environment(AppNavigation())
        .environment(PremiumStore())
}
