//
//  ContentView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//
//  Home is one month at a time, and nothing else: the month's figures centred
//  on an otherwise empty screen (see `MonthSummaryView`), with the receipts and
//  the category split behind their two buttons. Months are a horizontal pager —
//  swiping left and right walks the months that actually have data, oldest to
//  the current one.
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

    /// Which month the pager is parked on. Kept in step with
    /// `nav.selectedMonth` in both directions: the Dashboard tab writes that
    /// to jump Home to a month, and swiping writes it back.
    @State private var pagedMonth: Date?
    /// The pager's continuous position (2.4 = 40% of the way from the third
    /// month to the fourth). The indicator and each page's depth effect are
    /// driven by this, not by the settled index — that is what makes the
    /// swipe read as a physical drag rather than a slide show.
    @State private var pageProgress: Double = 0
    /// True while a day is being read off a chart. The pager is frozen for the
    /// duration so the scrubbing finger doesn't also turn the page.
    @State private var isScrubbing = false

    /// Sheets hung off the month buttons.
    @State private var showReceipts = false
    @State private var showCategories = false

    /// A receipt from the OCR flow, waiting for the confirm sheet to finish
    /// going away before it is pushed. Pushing mid-dismissal leaves the detail
    /// view without its navigation-bar inset — its content ends up underneath
    /// the bar. (The QR flow does not need this: the scanner holds itself open
    /// until the push is done, so there is no dismissal to collide with.)
    @State private var stagedReceipt: Receipt?
    /// True from the moment the confirm sheet appears until its dismissal
    /// *animation* completes — the binding flips to false too early to use.
    @State private var confirmVisible = false

    var body: some View {
        @Bindable var nav = nav
        return NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                MonthPagerIndicator(months: availableMonths, progress: pageProgress)
                Spacer().frame(height: 24)
                monthPager
                    .frame(height: MonthSummaryView.pageHeight)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .overlay(alignment: .topTrailing) { settingsButton }
            // Scoped to this screen. The old `.navigationBarHidden(true)` drove
            // the shared UINavigationController's hidden state, so every push
            // had to unhide the bar mid-transition — the pushed screen laid out
            // without the bar's inset and its header ended up underneath it.
            .toolbar(.hidden, for: .navigationBar)
            .alert("Greška", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            // The scanner is its own tab now, so nothing is presented here.
            // It hands its results over through `AppNavigation`.
            .sheet(item: $nav.pendingReceipt, onDismiss: {
                confirmVisible = false
                openStagedReceipt()
            }) { parsed in
                ReceiptConfirmView(parsed: parsed) { receipt in
                    stageReceipt(receipt)
                }
                .onAppear { confirmVisible = true }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .sheet(isPresented: $showReceipts) {
                MonthReceiptsSheet(month: displayedMonth, receipts: filteredReceipts)
            }
            .sheet(isPresented: $showCategories) {
                MonthCategoriesSheet(
                    month: displayedMonth,
                    rows: displayCategoryRows,
                    total: currentMonthSpent
                )
            }
            // COMMENTED OUT FOR FIRST RELEASE - VORLI AI NOT SHIPPING YET
            // .fullScreenCover(isPresented: $showVorli) {
            //     VorliChatView()
            // }
            .navigationDestination(item: $nav.scannedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { startScanning in
                onboardingCompleted = true
                showOnboarding = false
                if startScanning {
                    nav.selectedTab = .scan
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

    // MARK: - Month pager

    /// A page per month, full width, snapping. `LazyHStack` keeps the months
    /// off-screen from doing any work — each page recomputes its own totals.
    private var monthPager: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(availableMonths.enumerated()), id: \.element) { index, month in
                    monthPage(month, index: index)
                        .containerRelativeFrame(.horizontal)
                        .id(month)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollDisabled(isScrubbing)
        .scrollPosition(id: $pagedMonth, anchor: .center)
        // The indicator has to move with the finger, so it needs the live
        // offset rather than the page the scroll view eventually lands on.
        .onScrollGeometryChange(for: Double.self) { geometry in
            let width = geometry.containerSize.width
            guard width > 0 else { return 0 }
            return geometry.contentOffset.x / width
        } action: { _, new in
            pageProgress = new
        }
        // Start where navigation says we are, not always on the newest month.
        .onAppear { pagedMonth = Self.startOfMonth(nav.selectedMonth) }
        // Swiping is the source of truth while the user is on this screen.
        .onChange(of: pagedMonth) { _, month in
            guard let month else { return }
            nav.selectedMonth = month
        }
        // The Dashboard tab jumps Home to a month; follow it.
        .onChange(of: nav.selectedMonth) { _, month in
            let normalized = Self.startOfMonth(month)
            guard normalized != pagedMonth else { return }
            withAnimation(.easeInOut(duration: 0.25)) {
                pagedMonth = normalized
            }
        }
    }

    private func monthPage(_ month: Date, index: Int) -> some View {
        let receipts = receipts(in: month)
        let fixed = fixedCostsTotal
        return MonthSummaryView(
            month: month,
            spent: receipts.reduce(Decimal(0)) { $0 + $1.totalAmount } + fixed,
            income: income(in: month),
            spentToday: spentToday(in: month, receipts: receipts),
            dailyTotals: dailyTotals(in: month, receipts: receipts),
            receiptCount: receipts.count,
            closeness: max(0, 1 - abs(pageProgress - Double(index))),
            onReceipts: { showReceipts = true },
            onCategories: { showCategories = true },
            onScrubbingChanged: { isScrubbing = $0 }
        )
    }

    /// The gear has nowhere else to live — Home is the only screen that opens
    /// Settings, and the month layout has no header to hang it off.
    private var settingsButton: some View {
        Button {
            showSettings = true
        } label: {
            TablerIcon("settings", size: 20)
                .foregroundStyle(.primary)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.interactive(), in: .circle)
        }
        .tint(.primary)
        .accessibilityLabel("Podešavanja")
        .padding(.trailing, 20)
        .padding(.top, 8)
    }

    // MARK: - Months

    /// Every month from the oldest thing on record to the current one, so the
    /// pager can't wander into empty years in either direction.
    private var availableMonths: [Date] {
        let calendar = Calendar.current
        let thisMonth = Self.startOfMonth(Date())

        let stamps = allReceipts.map(\.timestamp) + budgetEntries.map(\.timestamp)
        guard let earliest = stamps.min() else { return [thisMonth] }

        var months: [Date] = []
        var cursor = Self.startOfMonth(earliest)
        // Guard against a nonsense timestamp dragging the pager back decades.
        while cursor <= thisMonth, months.count < 600 {
            months.append(cursor)
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        // A month the user navigated to but has no data for still needs a page.
        let selected = Self.startOfMonth(nav.selectedMonth)
        if !months.contains(selected) {
            months.append(selected)
            months.sort()
        }
        return months
    }

    private static func startOfMonth(_ date: Date) -> Date {
        let calendar = Calendar.current
        return calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    /// What the sheets are scoped to: the page on screen, falling back to
    /// navigation state before the pager has settled.
    private var displayedMonth: Date {
        pagedMonth ?? Self.startOfMonth(nav.selectedMonth)
    }

    // MARK: - Per-month figures

    private func receipts(in month: Date) -> [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter {
            calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month)
        }
    }

    /// Everything added to the budget this month — what the month's spending
    /// is measured against.
    private func income(in month: Date) -> Decimal {
        let calendar = Calendar.current
        return budgetEntries
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    private func spentToday(in month: Date, receipts: [Receipt]) -> Decimal {
        let calendar = Calendar.current
        guard calendar.isDate(month, equalTo: Date(), toGranularity: .month) else { return 0 }
        return receipts
            .filter { calendar.isDate($0.timestamp, inSameDayAs: Date()) }
            .reduce(Decimal(0)) { $0 + $1.totalAmount }
    }

    /// Spend per calendar day, index 0 = the 1st. Receipts only: fixed costs
    /// are charged to the month, not to any particular day.
    private func dailyTotals(in month: Date, receipts: [Receipt]) -> [Decimal] {
        let calendar = Calendar.current
        let dayCount = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        var totals = [Decimal](repeating: 0, count: dayCount)
        for receipt in receipts {
            let day = calendar.component(.day, from: receipt.timestamp)
            guard day >= 1, day <= dayCount else { continue }
            totals[day - 1] += receipt.totalAmount
        }
        return totals
    }

    // MARK: - Computed Properties (month on screen)

    /// Spending per category for the month on screen, largest first. Includes
    /// fixed costs, so the rows add up to the header's "spent" figure.
    private var categoryRows: [CategorySpending.Row] {
        CategorySpending.rows(
            for: filteredReceipts,
            categories: merchantCategories,
            fixedCosts: fixedCostsTotal
        )
    }

    /// Every category gets a bar — the bars share the available width, so there
    /// is no reason to hide any behind a "+N drugih" bucket. Descending by
    /// amount, since "Bez kategorije" can easily outweigh a named category and
    /// parking it last made the bar heights jump around.
    private var displayCategoryRows: [CategorySpending.Row] {
        categoryRows.sorted { $0.total > $1.total }
    }

    private var filteredReceipts: [Receipt] {
        receipts(in: displayedMonth)
    }

    private var fixedCostsTotal: Decimal {
        fixedCosts.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.iznos }
    }

    private var currentMonthSpent: Decimal {
        filteredReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount } + fixedCostsTotal
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

    /// Opens a scanned receipt as soon as it is safe to: right away if nothing
    /// is on screen over the list, otherwise once the presenter's dismissal
    /// animation has finished (see `stagedReceipt`).
    private func stageReceipt(_ receipt: Receipt) {
        stagedReceipt = receipt
        openStagedReceipt()
    }

    private func openStagedReceipt() {
        guard !confirmVisible, let receipt = stagedReceipt else { return }
        // A detail screen is already up (or on its way up). Swapping the
        // destination mid-transition tears the push down under UIKit —
        // whatever produced a second receipt has to wait for the pop.
        guard nav.scannedReceipt == nil else { return }
        stagedReceipt = nil
        // Next runloop turn. `onDismiss` runs inside UIKit's dismissal
        // completion, and pushing from there tears the presentation down
        // mid-flight — the app dies right after the receipt is saved.
        Task { @MainActor in
            nav.scannedReceipt = receipt
        }
    }

    private func processReceiptImage(_ image: UIImage) async {
        debugLog("📸 ContentView.processReceiptImage called with image: \(image.size)")
        do {
            let service = ReceiptService(modelContext: modelContext)
            debugLog("🔧 Calling service.processReceiptImage")
            let receipt = try await service.processReceiptImage(image)
            debugLog("✅ Receipt processed successfully: \(receipt.merchantName)")
            stageReceipt(receipt)
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
