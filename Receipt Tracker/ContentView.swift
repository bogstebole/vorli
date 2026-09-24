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
    /// month to the fourth), for the month indicator. An observable object
    /// rather than `@State` on purpose: as state it re-ran this whole screen on
    /// every frame of a swipe; as an object only the indicator, which reads
    /// it, is redrawn.
    @State private var pagerProgress = PagerProgress()
    /// True while a day is being read off a chart. The pager is frozen for the
    /// duration so the scrubbing finger doesn't also turn the page.
    @State private var isScrubbing = false

    /// Sheets hung off the month buttons.
    @State private var showDetails = false

    /// The calendar behind the month chip.
    @State private var showDayPicker = false
    /// Picked in the calendar, applied once the sheet has gone — so the pager
    /// visibly travels to it instead of moving behind a closing sheet.
    @State private var pendingDay: Date?
    /// The picked day, held up on its month's chart until the chart is
    /// touched or that page is left.
    @State private var focusedDay: Date?

    /// Any of this screen's sheets is up.
    private var sheetUp: Bool {
        showSettings || showDayPicker || showDetails || nav.pendingReceipt != nil
    }

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
        // Every month's figures in one pass over the receipts. This body no
        // longer runs during a swipe, only when data or navigation changes, so
        // this is paid once per change rather than once per frame.
        let index = monthIndex
        return NavigationStack {
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // Tapping the month opens the calendar.
                Button {
                    showDayPicker = true
                } label: {
                    LiveMonthIndicator(months: index.months, progress: pagerProgress)
                }
                .buttonStyle(MonthChipButtonStyle())
                .accessibilityHint("Otvara kalendar za izbor dana")
                .frame(maxWidth: .infinity)
                Spacer().frame(height: 24)
                monthPager(index)
                    .frame(height: MonthSummaryView.pageHeight)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            // Centre against the whole screen, not against whatever the tab
            // bar leaves behind. The bar is hidden for the opening animation
            // and slides in at the end; centring inside the safe area would
            // make the figures drift up by half a bar as it lands. The block
            // is far shorter than the screen, so the bar never reaches it.
            .ignoresSafeArea(.container, edges: .bottom)
            // The tab back to the current month grows out of the trailing edge
            // halfway down the screen, where the thumb already is. The page's
            // own margin is wider than the tab, so it never covers a figure.
            .overlay {
                LiveReturnTab(progress: pagerProgress, nowIndex: nowIndex(in: index)) {
                    returnToCurrentMonth(index)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
                .ignoresSafeArea()
                // Sheets float clear of the screen edge now, and the tab
                // showed as a grey bump beside them.
                .opacity(sheetUp ? 0 : 1)
                .animation(.easeOut(duration: 0.2), value: sheetUp)
            }
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
            .sheet(isPresented: $showDayPicker, onDismiss: applyPendingDay) {
                DayPickerSheet(
                    index: monthIndex,
                    initialMonth: displayedMonth,
                    focusedDay: focusedDay
                ) { day in
                    pendingDay = day
                }
            }
            .sheet(isPresented: $showDetails) {
                MonthDetailsSheet(
                    month: displayedMonth,
                    receipts: filteredReceipts,
                    categoryRows: displayCategoryRows,
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

    /// A page per month, full width, snapping. Pages only look their figures
    /// up; nothing in here depends on the scroll offset, so a swipe does not
    /// re-run it.
    private func monthPager(_ index: MonthIndex) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(index.months, id: \.self) { month in
                    monthPage(month, figures: index.figures(for: month))
                        .equatable()
                        .containerRelativeFrame(.horizontal)
                        // Depth: pages away from centre sit back rather than
                        // sliding past at full strength. Computed by the scroll
                        // view while it draws, so it tracks the finger without
                        // re-running any page.
                        .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                            let distance = abs(phase.value)
                            return content
                                .scaleEffect(1 - 0.06 * distance)
                                .opacity(1 - 0.75 * distance)
                        }
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
            pagerProgress.value = new
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
            // Jumps can cross several months at once, from the calendar or the
            // tab back to now; a little more time lets the month chips visibly
            // run past on the way instead of blinking to the end.
            withAnimation(.smooth(duration: 0.45)) {
                pagedMonth = normalized
            }
        }
    }

    /// Returns the concrete type so the pager can mark it `.equatable()`.
    private func monthPage(_ month: Date, figures: MonthFigures) -> MonthSummaryView {
        MonthSummaryView(
            month: month,
            spent: figures.spent,
            income: figures.income,
            spentToday: figures.spentToday,
            dailyTotals: figures.dailyTotals,
            onDetails: { showDetails = true },
            onScrubbingChanged: { scrubbing in
                isScrubbing = scrubbing
                // A scrub takes over from a day picked in the calendar.
                if scrubbing { focusedDay = nil }
            },
            focusedDay: focusedDayIndex(in: month),
            onFocusCleared: { focusedDay = nil }
        )
    }

    // MARK: - Jumping to a day or back to now

    private func nowIndex(in index: MonthIndex) -> Int? {
        index.months.firstIndex(of: Self.startOfMonth(Date()))
    }

    private func returnToCurrentMonth(_ index: MonthIndex) {
        guard let now = nowIndex(in: index) else { return }
        focusedDay = nil
        nav.selectedMonth = index.months[now]
    }

    /// Runs once the calendar sheet has finished closing. Paging to the month
    /// goes through `nav.selectedMonth`, the same route the Dashboard uses.
    private func applyPendingDay() {
        guard let day = pendingDay else { return }
        pendingDay = nil
        focusedDay = Calendar.current.startOfDay(for: day)
        nav.selectedMonth = Self.startOfMonth(day)
    }

    /// The picked day as an index into `month`'s chart, if it falls in it.
    private func focusedDayIndex(in month: Date) -> Int? {
        let calendar = Calendar.current
        guard let focusedDay,
              calendar.isDate(focusedDay, equalTo: month, toGranularity: .month) else { return nil }
        return calendar.component(.day, from: focusedDay) - 1
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

    /// Every month from the oldest thing on record to the current one, with
    /// its figures. One pass over the receipts; see `MonthIndex`.
    private var monthIndex: MonthIndex {
        MonthIndex(
            receipts: allReceipts,
            budgetEntries: budgetEntries,
            fixedCosts: fixedCostsTotal,
            including: nav.selectedMonth
        )
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

    // MARK: - Month on screen (for the sheets)

    private func receipts(in month: Date) -> [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter {
            calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month)
        }
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
