//
//  PriceHistorySheet.swift
//  Receipt Tracker
//
//  Price history of a single product within one merchant chain: chart of
//  unit prices across purchases, the purchase list, and the overall change.
//

import SwiftUI
import SwiftData
import Charts

struct PriceHistorySheet: View {
    @Environment(\.dismiss) private var dismiss
    @Query private var allReceipts: [Receipt]

    let item: ReceiptItem

    var body: some View {
        NavigationStack {
            Form {
                if entries.count >= 2 {
                    chartSection
                    summarySection
                }
                purchasesSection
            }
            .navigationTitle(item.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Sections

    private var chartSection: some View {
        Section {
            Chart(entries) { entry in
                LineMark(
                    x: .value("Datum", entry.date),
                    y: .value("Cena", (entry.unitPrice as NSDecimalNumber).doubleValue)
                )
                .interpolationMethod(.monotone)
                PointMark(
                    x: .value("Datum", entry.date),
                    y: .value("Cena", (entry.unitPrice as NSDecimalNumber).doubleValue)
                )
            }
            .foregroundStyle(overallIncrease ? Color.orange : Color.green)
            .chartYScale(domain: .automatic(includesZero: false))
            .frame(height: 160)
            .padding(.vertical, 4)
        } header: {
            Text(chainName)
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var summarySection: some View {
        Section {
            HStack {
                Text("Od prve kupovine")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                if let overall {
                    PriceChangeBadge(change: overall)
                } else {
                    Text("bez promene")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
            HStack {
                Text("Prosečna cena")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MoneyFormat.decimalString(averagePrice) + " RSD")
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
    }

    private var purchasesSection: some View {
        Section {
            ForEach(entries.reversed()) { entry in
                HStack {
                    Text(entry.date.formatted(.dateTime.day().month(.abbreviated).year()))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(MoneyFormat.decimalString(entry.unitPrice) + " RSD")
                        .font(.system(.subheadline, design: .monospaced))
                }
            }
        } header: {
            Text("Kupovine (\(entries.count))")
                .font(.system(.caption, design: .monospaced))
        } footer: {
            Text("Cene sa tvojih računa u ovom lancu. Poređenje radi samo za račune skenirane preko QR koda.")
                .font(.system(.caption, design: .monospaced))
        }
    }

    // MARK: - Computed

    private var entries: [PriceHistory.Entry] {
        PriceHistory.history(for: item, in: allReceipts)
    }

    private var chainName: String {
        item.receipt?.merchantName ?? ""
    }

    /// Change from the first recorded purchase to the most recent one.
    private var overall: PriceHistory.Change? {
        guard let first = entries.first, let last = entries.last,
              first.id != last.id, first.unitPrice != last.unitPrice else { return nil }
        return PriceHistory.Change(previousPrice: first.unitPrice,
                                   currentPrice: last.unitPrice,
                                   previousDate: first.date)
    }

    private var overallIncrease: Bool {
        overall?.isIncrease ?? false
    }

    private var averagePrice: Decimal {
        guard !entries.isEmpty else { return 0 }
        let total = entries.reduce(Decimal(0)) { $0 + $1.unitPrice }
        return total / Decimal(entries.count)
    }
}
