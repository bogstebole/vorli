//
//  SearchView.swift
//  Receipt Tracker
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

/// One month of search results: receipts whose merchant matched the query
/// plus individual items that matched. `total` covers both.
private struct SearchResultGroup: Identifiable {
    var id: Date { month }
    let month: Date
    let total: Decimal
    let receipts: [Receipt]
    let entries: [SearchResultEntry]
}

private struct ReceiptGroup: Identifiable {
    var id: Date { month }
    let month: Date
    let total: Decimal
    let receipts: [Receipt]
}

// MARK: - SearchView

struct SearchView: View {
    @Environment(PremiumStore.self) private var premiumStore
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]
    @Query private var merchantCategories: [MerchantCategory]

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @State private var categoryFilter: String?
    @FocusState private var isSearchFocused: Bool
    @State private var showPaywall = false

    /// Receipts the current tier may browse — non-premium sees only the
    /// free window (current + previous month).
    private var accessibleReceipts: [Receipt] {
        allReceipts.filter {
            PremiumStore.isMonthUnlocked($0.timestamp, isPremium: premiumStore.isPremium)
        }
    }

    private var hasLockedReceipts: Bool {
        accessibleReceipts.count < allReceipts.count
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if searchText.isEmpty {
                    allReceiptsView
                } else {
                    itemResultsView
                }

                if hasLockedReceipts {
                    Button {
                        showPaywall = true
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 11))
                            Text("Stariji računi su deo Premium-a")
                                .font(.system(.caption, design: .monospaced))
                        }
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 10)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallSheet()
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle("Pretraga")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // Styled principal title — default nav title isn't monospaced.
            ToolbarItem(placement: .principal) {
                Text("Pretraga")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 10) {
                HStack(spacing: 8) {
                    searchField
                    monthMenu
                }
                .padding(.horizontal, 16)

                if !availableCategories.isEmpty {
                    categoryChips
                }
            }
            .padding(.vertical, 10)
            .background(Color(uiColor: .systemBackground))
        }
    }

    // MARK: - Search Field

    private var searchField: some View {
        HStack(spacing: 8) {
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
                        .foregroundStyle(.primary)
                }
                .tint(.primary)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, minHeight: 44)
        .glassEffect(.regular.interactive(), in: .capsule)
    }

    // MARK: - Filters (month dropdown inline with search, categories below)

    private var scopeTitle: String {
        switch searchScope {
        case .all: return "Svi meseci"
        case .current: return "Ovaj mesec"
        case .month(let date): return date.monthYearString.capitalized
        }
    }

    /// Month filter as a compact calendar icon; the active scope shows as a
    /// small dot on the icon so a non-default filter is never invisible.
    private var monthMenu: some View {
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
            Image(systemName: searchScope == .all ? "calendar" : "calendar.badge.checkmark")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: 52, height: 44)
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .tint(.primary)
    }

    private var categoryChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(availableCategories, id: \.self) { category in
                    chip(category, isSelected: categoryFilter == category) {
                        categoryFilter = (categoryFilter == category) ? nil : category
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        // Glass chips cast a soft shadow — without this the scroll view
        // clips it into a visible hard edge.
        .scrollClipDisabled()
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Group {
            if isSelected {
                Button(action: action) {
                    Text(title)
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glassProminent)
                .tint(.primary)
            } else {
                Button(action: action) {
                    Text(title)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 4)
                }
                .buttonStyle(.glass)
            }
        }
    }

    // MARK: - Content Views

    @ViewBuilder
    private var allReceiptsView: some View {
        let groups = groupedReceiptsForSearch
        if groups.isEmpty {
            EmptyReceiptsView()
                .padding(.top, 40)
        } else {
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                if let categoryFilter {
                    categorySummaryRow(name: categoryFilter, groups: groups)
                }
                ForEach(groups) { group in
                    Section {
                        ForEach(group.receipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptCardView(receipt: receipt)
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        monthHeader(month: group.month, total: group.total)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    /// Total for the selected category across the active scope — the number
    /// the user is actually after when they tap a category chip.
    private func categorySummaryRow(name: String, groups: [ReceiptGroup]) -> some View {
        let total = groups.reduce(Decimal(0)) { $0 + $1.total }
        let count = groups.reduce(0) { $0 + $1.receipts.count }
        return HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                Text(scopeTitle)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(total.asRSD)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                Text("\(count) \(count % 10 == 1 && count % 100 != 11 ? "račun" : "računa")")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var itemResultsView: some View {
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
            LazyVStack(spacing: 12, pinnedViews: [.sectionHeaders]) {
                summaryRow(for: groups)

                ForEach(groups) { group in
                    Section {
                        ForEach(group.receipts) { receipt in
                            NavigationLink {
                                ReceiptDetailView(receipt: receipt)
                            } label: {
                                ReceiptCardView(receipt: receipt)
                            }
                            .buttonStyle(.plain)
                        }
                        ForEach(group.entries) { entry in
                            NavigationLink {
                                ReceiptDetailView(receipt: entry.receipt)
                            } label: {
                                SearchItemCardView(
                                    itemName: entry.item.name,
                                    merchantName: entry.receipt.merchantName,
                                    date: entry.receipt.timestamp,
                                    lineTotal: entry.item.lineTotal
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    } header: {
                        monthHeader(month: group.month, total: group.total)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    /// The answer to "why am I searching": total spent on the query across
    /// the current scope.
    private func summaryRow(for groups: [SearchResultGroup]) -> some View {
        let total = groups.reduce(Decimal(0)) { $0 + $1.total }
        let count = groups.reduce(0) { $0 + $1.receipts.count + $1.entries.count }
        return HStack(alignment: .firstTextBaseline) {
            Text("\"\(searchText)\"")
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .lineLimit(1)
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(total.asRSD)
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                Text("\(count) \(count == 1 ? "rezultat" : "rezultata")")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func monthHeader(month: Date, total: Decimal) -> some View {
        HStack {
            Text(month.monthYearString.capitalized)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            Spacer()
            Text(total.asRSD)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
        }
        // Match the cards' inner padding so header text aligns with card text.
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        // Full-bleed background: the header sits inside a padded stack, so a
        // plain background would let cards and their shadows peek around it
        // while pinned.
        .background {
            Color(uiColor: .systemBackground)
                .containerRelativeFrame(.horizontal)
        }
    }

    // MARK: - Computed Properties

    private var availableMonths: [Date] {
        let calendar = Calendar.current
        var seen = Set<Date>()
        var months: [Date] = []
        for receipt in accessibleReceipts {
            let start = receipt.timestamp.startOfMonth
            // "Ovaj mesec" chip already covers the current month.
            if calendar.isDate(start, equalTo: Date(), toGranularity: .month) { continue }
            if seen.insert(start).inserted {
                months.append(start)
            }
        }
        return months.sorted(by: >)
    }

    private var availableCategories: [String] {
        Array(Set(merchantCategories.map(\.name))).sorted()
    }

    /// Merchant keys covered by the active category filter, nil = no filter.
    private var categoryMerchantKeys: Set<String>? {
        guard let categoryFilter else { return nil }
        return Set(merchantCategories.filter { $0.name == categoryFilter }.map(\.merchantKey))
    }

    private var scopedReceipts: [Receipt] {
        let calendar = Calendar.current
        var receipts: [Receipt]
        switch searchScope {
        case .all:
            receipts = accessibleReceipts
        case .current:
            receipts = accessibleReceipts.filter { calendar.isDate($0.timestamp, equalTo: Date(), toGranularity: .month) }
        case .month(let date):
            receipts = accessibleReceipts.filter { calendar.isDate($0.timestamp, equalTo: date, toGranularity: .month) }
        }
        if let keys = categoryMerchantKeys {
            receipts = receipts.filter { keys.contains(PriceHistory.merchantKey($0.merchantName)) }
        }
        return receipts
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

    /// Normalized (case-, diacritic- and script-insensitive) matching via the
    /// same keys price history uses. A merchant hit shows the whole receipt;
    /// item hits show individual items — so "lidl" gives receipts instead of
    /// flooding the list with every item Lidl ever sold.
    private var searchResultGroups: [SearchResultGroup] {
        let query = PriceHistory.normalize(searchText)
        guard !query.isEmpty else { return [] }

        var receiptHits: [Date: [Receipt]] = [:]
        var itemHits: [Date: [SearchResultEntry]] = [:]

        for receipt in scopedReceipts {
            let start = receipt.timestamp.startOfMonth
            if PriceHistory.merchantKey(receipt.merchantName).contains(query) {
                receiptHits[start, default: []].append(receipt)
                continue
            }
            for item in receipt.items {
                let key = item.normalizedName.isEmpty ? PriceHistory.normalize(item.name) : item.normalizedName
                if key.contains(query) {
                    itemHits[start, default: []].append(SearchResultEntry(receipt: receipt, item: item))
                }
            }
        }

        let months = Set(receiptHits.keys).union(itemHits.keys)
        return months.map { month in
            let receipts = (receiptHits[month] ?? []).sorted { $0.timestamp > $1.timestamp }
            let entries = (itemHits[month] ?? []).sorted { $0.receipt.timestamp > $1.receipt.timestamp }
            let total = receipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
                + entries.reduce(Decimal(0)) { $0 + $1.item.lineTotal }
            return SearchResultGroup(month: month, total: total, receipts: receipts, entries: entries)
        }.sorted { $0.month > $1.month }
    }
}
