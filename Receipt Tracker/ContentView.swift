//
//  ContentView.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

// MARK: - Search Support Types

enum SearchScope: Hashable {
    case all
    case current
    case month(Date)
}

private struct SearchResultEntry: Identifiable {
    var id: UUID { item.id }
    let receipt: Receipt
    let item: ReceiptItem
}

private struct SearchResultGroup: Identifiable {
    var id: Date { month }
    let month: Date
    let total: Decimal
    let entries: [SearchResultEntry]
}

private struct ReceiptGroup: Identifiable {
    var id: Date { month }
    let month: Date
    let total: Decimal
    let receipts: [Receipt]
}

// MARK: - ContentView

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
    // @Environment(AuthenticationManager.self) private var authManager
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @Query(sort: \BudgetEntry.timestamp, order: .reverse) private var budgetEntries: [BudgetEntry]
    @State private var budget: Budget?

    @State private var selectedMonth: Date = Date()
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var showScanner = false
    @State private var showAddBalance = false
    @State private var showAddNew = false
    @State private var showDashboard = false
    @State private var showSettings = false
    @State private var showVorli = false
    @State private var scannedReceipt: Receipt?

    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    @State private var searchScope: SearchScope = .all

    private var isSearchActive: Bool {
        isSearchFocused || !searchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(spacing: 12) {
                        if budget != nil {
                            MonthBalanceCard(
                                month: currentMonthName,
                                currentBalance: currentMonthLeftoverBalance,
                                spent: currentMonthSpent,
                                spentToday: currentDaySpent,
                                onAddNew: { showAddNew = true },
                                onDashboard: { showDashboard = true },
                                onSettings: { showSettings = true }
                            )
                        }

                        SectionDivider(title: "Računi")
                            .padding(.horizontal)

                        searchBarRow
                            .padding(.horizontal)

                        if isSearchActive {
                            if searchText.isEmpty {
                                searchAllReceiptsView
                            } else {
                                searchResultsView
                            }
                        } else {
                            normalReceiptsView
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItemGroup(placement: .bottomBar) {
                    Button {
                        showVorli = true
                    } label: {
                        Image(systemName: "sparkles")
                    }

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
                } onReceiptScan: { image in
                    Task { await processReceiptImage(image) }
                }
            }
            .sheet(isPresented: $showAddNew) {
                AddNewSheet(onAddBalance: { showAddBalance = true })
            }
            .sheet(isPresented: $showAddBalance) {
                AddBalanceSheet { amount in addBalance(amount) }
            }
            .sheet(isPresented: $showDashboard) {
                DashboardSheet(receipts: allReceipts) { month in selectedMonth = month }
            }
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
                    // COMMENTED OUT FOR FIRST RELEASE - NO AUTHENTICATION
                    // .environment(authManager)
            }
            .fullScreenCover(isPresented: $showVorli) {
                VorliChatView()
            }
            .navigationDestination(item: $scannedReceipt) { receipt in
                ReceiptDetailView(receipt: receipt)
            }
        }
        .task {
            loadBudget()
        }
    }

    // MARK: - Search Bar

    @ViewBuilder
    private var searchBarRow: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                    .font(.system(size: 14))

                TextField("Pretraži račune...", text: $searchText)
                    .font(.system(.subheadline, design: .monospaced))
                    .focused($isSearchFocused)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isSearchActive {
                Menu {
                    Picker("Mesec", selection: $searchScope) {
                        Text("Svi meseci").tag(SearchScope.all)
                        Text("Ovaj mesec").tag(SearchScope.current)
                        ForEach(availableMonths, id: \.self) { month in
                            Text(month.monthYearString.capitalized)
                                .tag(SearchScope.month(month))
                        }
                    }
                } label: {
                    Image(systemName: "calendar")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .tint(.primary)
                        .frame(width: 36, height: 36)
                        .glassEffect(.regular.interactive(), in: .circle)
                }
                .tint(.primary)
                .transition(.scale(scale: 0.8).combined(with: .opacity))

                Button("Otkaži") {
                    searchText = ""
                    isSearchFocused = false
                }
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: isSearchActive)
    }

    // MARK: - Content Views

    @ViewBuilder
    private var normalReceiptsView: some View {
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

    @ViewBuilder
    private var searchAllReceiptsView: some View {
        let groups = groupedReceiptsForSearch
        if groups.isEmpty {
            EmptyReceiptsView()
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(groups) { group in
                    monthHeader(month: group.month, total: group.total)

                    ForEach(group.receipts) { receipt in
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
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private var searchResultsView: some View {
        let groups = searchResultGroups
        if groups.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 40))
                    .foregroundStyle(.tertiary)
                Text("Nema rezultata za \"\(searchText)\"")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding(.top, 60)
        } else {
            LazyVStack(spacing: 12) {
                ForEach(groups) { group in
                    monthHeader(month: group.month, total: group.total)

                    ForEach(group.entries) { entry in
                        NavigationLink {
                            ReceiptDetailView(receipt: entry.receipt)
                        } label: {
                            SearchItemCardView(
                                itemName: entry.item.name,
                                merchantName: entry.receipt.merchantName,
                                lineTotal: entry.item.lineTotal
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    @ViewBuilder
    private func monthHeader(month: Date, total: Decimal) -> some View {
        HStack {
            Text(month.monthYearString.capitalized)
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Text(total.asRSD)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .padding(.top, 4)
    }

    // MARK: - Computed Properties

    private var availableMonths: [Date] {
        var seen = Set<Date>()
        var months: [Date] = []
        for receipt in allReceipts {
            let start = receipt.timestamp.startOfMonth
            if seen.insert(start).inserted {
                months.append(start)
            }
        }
        return months.sorted(by: >)
    }

    private var scopedReceipts: [Receipt] {
        let calendar = Calendar.current
        switch searchScope {
        case .all:
            return allReceipts
        case .current:
            return allReceipts.filter { calendar.isDate($0.timestamp, equalTo: Date(), toGranularity: .month) }
        case .month(let date):
            return allReceipts.filter { calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
        }
    }

    private var groupedReceiptsForSearch: [ReceiptGroup] {
        var groups: [Date: [Receipt]] = [:]
        for receipt in scopedReceipts {
            let start = receipt.timestamp.startOfMonth
            groups[start, default: []].append(receipt)
        }
        return groups.map { month, receipts in
            ReceiptGroup(
                month: month,
                total: receipts.reduce(Decimal(0)) { $0 + $1.totalAmount },
                receipts: receipts.sorted { $0.timestamp > $1.timestamp }
            )
        }.sorted { $0.month > $1.month }
    }

    private var searchResultGroups: [SearchResultGroup] {
        guard !searchText.isEmpty else { return [] }
        let query = searchText.lowercased()
        var groups: [Date: [SearchResultEntry]] = [:]
        for receipt in scopedReceipts {
            for item in receipt.items {
                if item.name.lowercased().contains(query) || receipt.merchantName.lowercased().contains(query) {
                    let start = receipt.timestamp.startOfMonth
                    groups[start, default: []].append(SearchResultEntry(receipt: receipt, item: item))
                }
            }
        }
        return groups.map { month, entries in
            SearchResultGroup(
                month: month,
                total: entries.reduce(Decimal(0)) { $0 + $1.item.lineTotal },
                entries: entries.sorted { $0.receipt.timestamp > $1.receipt.timestamp }
            )
        }.sorted { $0.month > $1.month }
    }

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

    private var currentMonthSpent: Decimal {
        filteredReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
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

    private func loadBudget() {
        let service = ReceiptService(modelContext: modelContext)
        if let fetchedBudget = try? service.getBudget() {
            budget = fetchedBudget
        }
    }

    private func processReceipt(from urlString: String) async {
        do {
            let service = ReceiptService(modelContext: modelContext)
            let receipt = try await service.processReceipt(from: urlString)
            loadBudget()
            scannedReceipt = receipt
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func processReceiptImage(_ image: UIImage) async {
        print("📸 ContentView.processReceiptImage called with image: \(image.size)")
        do {
            let service = ReceiptService(modelContext: modelContext)
            print("🔧 Calling service.processReceiptImage")
            let receipt = try await service.processReceiptImage(image)
            print("✅ Receipt processed successfully: \(receipt.merchantName)")
            loadBudget()
            scannedReceipt = receipt
        } catch {
            print("❌ Error in processReceiptImage: \(error)")
            errorMessage = error.localizedDescription
            showError = true
        }
    }

    private func deleteReceipt(_ receipt: Receipt) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.deleteReceipt(receipt)
        loadBudget()
    }

    private func addBalance(_ amount: Decimal) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.addBalanceEntry(amount: amount)
        loadBudget()
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

            // COMMENTED OUT FOR FIRST RELEASE - NO SETTINGS/AUTHENTICATION
            /*
            Button {
                showSettings = true
            } label: {
                Image("avatar")
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 27, height: 36)
                    .clipped()
                    .background(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 7))
                    .shadow(color: .black.opacity(0.1), radius: 1.5, x: 0, y: 1)
                    .shadow(color: .black.opacity(0.09), radius: 2.5, x: 0, y: 5)
                    .shadow(color: .black.opacity(0.05), radius: 3.5, x: 1, y: 12)
                    .shadow(color: .black.opacity(0.01), radius: 4, x: 1, y: 21)
                    .shadow(color: .black.opacity(0), radius: 4.5, x: 2, y: 33)
                    .rotationEffect(Angle(degrees: -5))
            }
            */
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
        .modelContainer(for: [Receipt.self, Budget.self, BudgetEntry.self], inMemory: true)
}
