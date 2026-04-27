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

// MARK: - SearchView

struct SearchView: View {
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @FocusState private var isSearchFocused: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                if searchText.isEmpty {
                    allReceiptsView
                } else {
                    itemResultsView
                }
            }
            .padding(.top, 4)
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
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
                }
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
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
                            .foregroundStyle(.tertiary)
                    }
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.15), value: searchText.isEmpty)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: 44)
            .glassEffect(.regular.interactive(), in: .capsule)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .onAppear {
            isSearchFocused = true
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
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
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
}
