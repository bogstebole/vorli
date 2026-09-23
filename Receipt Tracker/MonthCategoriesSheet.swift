//
//  MonthCategoriesSheet.swift
//  Receipt Tracker
//
//  Where the month's money went, behind the home screen's "Kategorije"
//  button. One strip split by share, then a row per category — shade follows
//  rank, so the strip and the list read as the same object.
//

import SwiftUI

struct MonthCategoriesSheet: View {
    @Environment(\.dismiss) private var dismiss

    let month: Date
    /// Sorted largest first by the caller, and summing to `total`.
    let rows: [CategorySpending.Row]
    let total: Decimal

    var body: some View {
        NavigationStack {
            Group {
                if rows.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 24) {
                            header
                            strip
                            list
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
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

    // MARK: - Pieces

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(MoneyFormat.grouped(total) + " RSD")
                .font(.system(size: 28, weight: .medium, design: .monospaced))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
            Text("\(rows.count) \(rows.count == 1 ? "kategorija" : "kategorija")")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// One strip, a segment per category, widths in proportion to the amounts.
    private var strip: some View {
        GeometryReader { geometry in
            HStack(spacing: 2) {
                ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(shade(index: index, row: row))
                        .frame(width: segmentWidth(row, in: geometry.size.width))
                }
            }
        }
        .frame(height: 10)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Podela potrošnje po kategorijama")
    }

    private var list: some View {
        VStack(spacing: 14) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(shade(index: index, row: row))
                        .frame(width: 6, height: 6)

                    Text(row.name)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(Int((row.fraction * 100).rounded()))%")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Text(MoneyFormat.grouped(row.total))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(row.name): \(MoneyFormat.grouped(row.total)) dinara, \(Int((row.fraction * 100).rounded())) odsto")
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            TablerIcon("wallet", size: 48)
                .foregroundStyle(.tertiary)
            Text("Nema potrošnje ovog meseca")
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Helpers

    private func segmentWidth(_ row: CategorySpending.Row, in width: CGFloat) -> CGFloat {
        let gaps = CGFloat(max(0, rows.count - 1)) * 2
        let available = max(0, width - gaps)
        return max(4, available * CGFloat(row.fraction))
    }

    /// Same ramp the home header used: brightness follows rank, so the biggest
    /// category is also the strongest segment.
    private func shade(index: Int, row: CategorySpending.Row) -> Color {
        Color.primary.opacity(CategorySpending.shadeOpacity(
            rank: index,
            count: rows.count,
            isUncategorized: row.isUncategorized
        ))
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
