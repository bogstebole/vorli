//
//  SummaryHeaderCard.swift
//  Receipt Tracker
//
//  Home header, built to the Figma spec ("New dashboard", node 263:1549):
//  a "Stanje" title row with the settings control, then a solid card —
//  month, the month's spend as the hero figure, a hairline, today's spend and
//  the balance, and a monochrome bar chart of spending per category.
//
//  The card inverts with the appearance: black on a white screen, white on a
//  black one. So its fill is `.primary` and everything drawn on it derives
//  from `.systemBackground` — never a literal black or white.
//

import SwiftUI
import Charts

struct SummaryHeaderCard: View {
    /// Month the screen is scoped to — drives the label and the totals.
    let month: Date
    let balance: Decimal
    let spent: Decimal
    let spentToday: Decimal
    /// Same rows as the list below the card, so the chart matches it.
    var categories: [CategorySpending.Row] = []

    var onSettings: () -> Void = {}

    /// Ink for anything sitting on the card — the inverse of the card's fill,
    /// so it stays legible whichever way the appearance flips.
    private var onCard: Color { Color(uiColor: .systemBackground) }
    /// Figma's #bfbfbf and #727272, expressed as fractions of the card's ink.
    private var muted: Color { onCard.opacity(0.72) }
    private var dim: Color { onCard.opacity(0.45) }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            titleRow
            card
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Title row (outside the card)

    private var titleRow: some View {
        HStack {
            Text("Stanje")
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(.primary)

            Spacer()

            Button(action: onSettings) {
                TablerIcon("settings", size: 20)
                    .foregroundStyle(.primary)
                    .frame(width: 36, height: 36)
                    .glassEffect(.regular.interactive(), in: .circle)
            }
            .tint(.primary)
            .accessibilityLabel("Podešavanja")
        }
        .frame(height: 36)
        // Extra inset so the title lines up with the day headers and merchant
        // names below, which sit 16pt inside their cards.
        .padding(.horizontal, 16)
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel)
                .font(.system(size: 16, design: .monospaced))
                .foregroundStyle(muted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MoneyFormat.grouped(spent))
                    .font(.system(size: 36, design: .monospaced))
                    .foregroundStyle(onCard)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)

                Spacer(minLength: 0)

                Text("RSD")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dim)
            }

            hairline

            HStack(spacing: 8) {
                if isCurrentMonth {
                    labelledValue("Danas", MoneyFormat.grouped(spentToday))
                }
                Spacer(minLength: 0)
                labelledValue("Stanje", MoneyFormat.signed(balance))
            }

            if !categories.isEmpty {
                VStack(alignment: .leading, spacing: 18) {
                    categoryChart
                    categoryLegend
                }
                // 10pt inside the panel; the panel's own edges line up with the
                // hairline and the text above it.
                .padding(.vertical, 12)
                .padding(.horizontal, 10)
                .background(onCard.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
                .padding(.top, 10)
            }
        }
        .padding(16)
        .background(Color.primary, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(white: 0.35).opacity(0.10), radius: 4.5, y: 4)
        .shadow(color: Color(white: 0.35).opacity(0.09), radius: 7.5, y: 15)
    }

    private var hairline: some View {
        Rectangle()
            .fill(onCard.opacity(0.16))
            .frame(height: 1)
    }

    private func labelledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(muted)
            Text(value + " RSD")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(onCard)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Category chart

    /// Vertical bar chart of spending per category, via Swift Charts — so it
    /// carries VoiceOver descriptions and Audio Graphs, and animates when the
    /// month changes. The caller decides how many rows to show (and folds the
    /// tail into "Ostalo"), so every row it hands over gets a bar.
    private var categoryChart: some View {
        Chart {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, row in
                BarMark(
                    x: .value("Kategorija", row.name),
                    y: .value("Iznos", (row.total as NSDecimalNumber).doubleValue),
                    // Ratio, not a fixed width: the bars split the plot evenly
                    // and fill it whatever the category count is.
                    width: .ratio(0.72)
                )
                .foregroundStyle(shade(index: index, row: row))
                .cornerRadius(2)
                .accessibilityLabel(row.name)
                .accessibilityValue("\(MoneyFormat.grouped(row.total)) dinara, \(Int((row.fraction * 100).rounded())) odsto")
            }
        }
        // Bars only. Names and amounts live in the list under the card: five
        // long Serbian labels plus five numbers inside this panel was unreadable.
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: categories.map(\.name))
        .chartPlotStyle { plot in
            plot.frame(height: Self.barAreaHeight)
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: categories.map(\.total))
    }

    /// Names and amounts for the bars, quietly: swatch in the bar's own shade,
    /// no rules, no percentages — the bar heights already carry the proportion.
    /// Every label uses one colour; varying them per row made the block harder
    /// to read, not easier.
    private var categoryLegend: some View {
        VStack(spacing: 5) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, row in
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(shade(index: index, row: row))
                        .frame(width: 6, height: 6)

                    Text(row.name)
                        .font(.system(size: 10, design: .monospaced))
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text(MoneyFormat.grouped(row.total))
                        .font(.system(size: 10, design: .monospaced))
                }
                .foregroundStyle(muted)
            }
        }
    }

    private static let barAreaHeight: CGFloat = 52

    /// Brightness follows the bar's rank, which (since the caller sorts by
    /// amount) means the tallest bar is also the brightest.
    private func shade(index: Int, row: CategorySpending.Row) -> Color {
        onCard.opacity(CategorySpending.shadeOpacity(
            rank: index,
            count: categories.count,
            isUncategorized: row.isUncategorized
        ))
    }

    // MARK: - Text

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var monthLabel: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month).sentenceCased
    }
}

#Preview {
    VStack {
        SummaryHeaderCard(
            month: Date(),
            balance: 234_000,
            spent: 56_212,
            spentToday: 1_000,
            categories: [
                .init(name: "Tehnika", total: 33_332, fraction: 0.60, isUncategorized: false),
                .init(name: "Hrana", total: 13_360, fraction: 0.24, isUncategorized: false),
                .init(name: "Prevoz", total: 8_000, fraction: 0.14, isUncategorized: false),
                .init(name: "Pekara", total: 480, fraction: 0.01, isUncategorized: false),
                .init(name: "Bez kategorije", total: 520, fraction: 0.01, isUncategorized: true)
            ]
        )
        Spacer()
    }
    .padding(.top, 48)
}
