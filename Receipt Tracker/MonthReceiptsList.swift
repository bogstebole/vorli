//
//  MonthReceiptsList.swift
//  Receipt Tracker
//
//  The month's receipts, grouped by day — the "Računi" tab of the month's
//  details sheet. The sheet owns the navigation stack, title and close button;
//  this is only the list, so a receipt still pushes its detail inside the
//  sheet.
//

import SwiftUI
import SwiftData

struct MonthReceiptsList: View {
    @Environment(\.modelContext) private var modelContext

    /// Already filtered to the month by the caller, which owns the query.
    let receipts: [Receipt]

    var body: some View {
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
                .font(.system(.caption, design: .monospaced, weight: .medium))
                .foregroundStyle(.primary)
            Spacer()
            Text(MoneyFormat.grouped(total) + " RSD")
                .font(.system(.caption, design: .monospaced, weight: .medium))
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

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMM"
        return f
    }()
}
