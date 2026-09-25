//
//  MonthDetailsSheet.swift
//  Receipt Tracker
//
//  Everything behind a month's figures on Home, in one sheet: its receipts,
//  and where the money went, as two tabs. Home used to carry a button for
//  each; one "Detalji" button keeps the page down to the figures and the chart.
//

import SwiftUI

struct MonthDetailsSheet: View {
    enum Tab: Hashable {
        case receipts, categories
    }

    @Environment(\.dismiss) private var dismiss

    let month: Date
    /// Already filtered to `month` by the caller, which owns the query.
    let receipts: [Receipt]
    /// Sorted largest first, and summing to `total`.
    let categoryRows: [CategorySpending.Row]
    let total: Decimal

    @State private var tab: Tab = .receipts

    init(month: Date, receipts: [Receipt], categoryRows: [CategorySpending.Row], total: Decimal) {
        SegmentedControlAppearance.applyOnce()
        self.month = month
        self.receipts = receipts
        self.categoryRows = categoryRows
        self.total = total
    }

    var body: some View {
        NavigationStack {
            // A real container, not a Group: a Group hands its modifiers to
            // each branch, so every tab carried its own segmented control,
            // title and close button, and switching crossfaded one control
            // into another mid-slide.
            ZStack {
                switch tab {
                case .receipts:
                    MonthReceiptsList(receipts: receipts)
                case .categories:
                    MonthCategoriesView(rows: categoryRows, total: total)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            // The tabs stay put while either list scrolls under them.
            .safeAreaBar(edge: .top) { tabPicker }
            .monoNavigationTitle(monthLabel)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        TablerIcon("x", size: 20)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Zatvori")
                }
            }
        }
    }

    private var tabPicker: some View {
        Picker("Prikaz", selection: $tab) {
            Text("Računi (\(receipts.count))").tag(Tab.receipts)
            Text("Kategorije").tag(Tab.categories)
        }
        .pickerStyle(.segmented)
        // Animated here and only here: the glass slides across, and the
        // content below swaps outright, as it does under a segmented control
        // everywhere else in iOS.
        .animation(.default, value: tab)
        .padding(.horizontal, 20)
        .padding(.top, 8)
        // Twice the old gap, so the tabs read as a control over the content
        // rather than its first row.
        .padding(.bottom, 32)
    }

    private var monthLabel: String {
        Self.monthFormatter.string(from: month).sentenceCased
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}
