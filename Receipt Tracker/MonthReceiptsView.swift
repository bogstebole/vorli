//
//  MonthReceiptsView.swift
//  Receipt Tracker
//
//  Every receipt of one month, grouped by day. The home screen only shows the
//  few most recent ones; this is where "Prikaži sve račune" lands.
//

import SwiftUI
import SwiftData

struct MonthReceiptsView: View {
    let month: Date

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Receipt.timestamp, order: .reverse) private var allReceipts: [Receipt]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(receiptsByDay, id: \.day) { group in
                    dayHeader(day: group.day, total: group.total)
                        .padding(.top, 4)
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
                                Label {
                                    Text("Obriši")
                                } icon: {
                                    TablerIcon("trash", size: 16)
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(monthTitle)
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Text(countLabel)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Pieces

    private static let dayHeaderFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMM"
        return f
    }()

    private func dayHeader(day: Date, total: Decimal) -> some View {
        HStack {
            // Only the weekday is capitalised — Serbian month names are lowercase.
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

    private var monthReceipts: [Receipt] {
        let calendar = Calendar.current
        return allReceipts.filter {
            calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month)
        }
    }

    private var receiptsByDay: [(day: Date, total: Decimal, receipts: [Receipt])] {
        let calendar = Calendar.current
        let groups = Dictionary(grouping: monthReceipts) {
            calendar.startOfDay(for: $0.timestamp)
        }
        return groups.keys.sorted(by: >).map { day in
            let dayReceipts = (groups[day] ?? []).sorted { $0.timestamp > $1.timestamp }
            let total = dayReceipts.reduce(Decimal(0)) { $0 + $1.totalAmount }
            return (day: day, total: total, receipts: dayReceipts)
        }
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month).sentenceCased
    }

    private var countLabel: String {
        let count = monthReceipts.count
        let noun = (count % 10 == 1 && count % 100 != 11) ? "račun" : "računa"
        return "\(count) \(noun)"
    }

    private func deleteReceipt(_ receipt: Receipt) {
        let service = ReceiptService(modelContext: modelContext)
        try? service.deleteReceipt(receipt)
    }
}
