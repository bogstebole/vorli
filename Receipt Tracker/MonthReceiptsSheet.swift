//
//  MonthReceiptsSheet.swift
//  Receipt Tracker
//
//  The month's receipts, grouped by day. This used to sit inline under the
//  home header; the home screen is now just the month's figures, so the list
//  moved behind the "Računi" button.
//

import SwiftUI
import SwiftData

struct MonthReceiptsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    /// Month the list is scoped to — only drives the title.
    let month: Date
    /// Already filtered to `month` by the caller, which owns the query.
    let receipts: [Receipt]

    var body: some View {
        NavigationStack {
            Group {
                if receipts.isEmpty {
                    EmptyReceiptsView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
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
                        .padding(.vertical, 8)
                    }
                }
            }
            .navigationTitle(monthLabel)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        TablerIcon("x", size: 17)
                            .foregroundStyle(.primary)
                    }
                    .accessibilityLabel("Zatvori")
                }
            }
        }
    }

    // MARK: - Rows

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

    // MARK: - Data

    /// The month's receipts grouped by calendar day, newest day first.
    private var receiptsByDay: [(day: Date, total: Decimal, receipts: [Receipt])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: receipts) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return groups.keys.sorted(by: >).map { day in
            let dayReceipts = (groups[day] ?? []).sorted { $0.timestamp > $1.timestamp }
            let total = dayReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
            return (day: day, total: total, receipts: dayReceipts)
        }
    }

    private func deleteReceipt(_ receipt: Receipt) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.deleteReceipt(receipt)
    }

    private var monthLabel: String {
        Self.monthFormatter.string(from: month).sentenceCased
    }

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMM"
        return f
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}
