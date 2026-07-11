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

    @AppStorage("onboardingCompleted") private var onboardingCompleted = false
    @State private var showOnboarding = false

    @State private var selectedMonth: Date = Date()
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showScanner = false
    @State private var showAddNew = false
    @State private var showDashboard = false
    @State private var showSettings = false
    @State private var showVorli = false
    @State private var scannedReceipt: Receipt?
    @State private var pendingReceipt: ParsedReceipt?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        MonthBalanceCard(
                            month: currentMonthName,
                            currentBalance: currentMonthLeftoverBalance,
                            spent: currentMonthSpent,
                            spentToday: currentDaySpent,
                            onAddNew: { showAddNew = true },
                            onDashboard: { showDashboard = true },
                            onSettings: { showSettings = true }
                        )

                        SectionDivider(title: "Računi")
                            .padding(.horizontal)

                        // Search bar — tapping pushes SearchView
                        NavigationLink {
                            SearchView()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 14))
                                Text("Pretraži račune...")
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                Spacer()
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal)

                        // Receipt list for current month
                        if filteredReceipts.isEmpty {
                            EmptyReceiptsView()
                                .padding(.top, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(filteredReceipts) { receipt in
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
                                            Label("Obriši", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    // COMMENTED OUT FOR FIRST RELEASE - VORLI AI NOT SHIPPING YET
                    // Button {
                    //     showVorli = true
                    // } label: {
                    //     Image(systemName: "sparkles")
                    // }

                    Spacer()

                    Button {
                        showScanner = true
                    } label: {
                        Image(systemName: "qrcode.viewfinder")
                    }
                }
            }
            .alert("Greška", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                }
            }
            .sheet(isPresented: $showScanner) {
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
            .sheet(isPresented: $showAddNew) {
                AddNewSheet()
            }
            .sheet(isPresented: $showDashboard) {
                DashboardSheet(receipts: allReceipts) { month in selectedMonth = month }
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
                        showScanner = true
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
    }

    // MARK: - Computed Properties

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        return formatter.string(from: selectedMonth)
    }

    private var filteredReceipts: [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter { receipt in
            calendar.isDate(receipt.timestamp, equalTo: selectedMonth, toGranularity: .month)
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
            calendar.isDate(entry.timestamp, equalTo: selectedMonth, toGranularity: .month)
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
            Image(systemName: "receipt")
                .font(.system(size: 60))
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
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self, FixedCost.self, Wish.self], inMemory: true)
}
