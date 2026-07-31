//
//  SummaryHeaderCard.swift
//  Receipt Tracker
//
//  Home header, built to the Figma spec ("New dashboard", node 263:1549):
//  a "Stanje" title row with the settings control, then a dark gradient card —
//  month, the month's spend as the hero figure, a hairline, today's spend and
//  the balance, and a monochrome bar chart of spending per category.
//
//  The card keeps its dark gradient in both appearances (as designed); only
//  the title above it follows the system label colour.
//

import SwiftUI

struct SummaryHeaderCard: View {
    /// Month the screen is scoped to — drives the label and the totals.
    let month: Date
    let balance: Decimal
    let spent: Decimal
    let spentToday: Decimal
    /// Same rows as the list below the card, so the chart matches it.
    var categories: [CategorySpending.Row] = []

    var onSettings: () -> Void = {}

    // Figma palette. Fixed values, not semantic colors: they sit on the dark
    // card, which does not invert.
    private let dim = Color(red: 0.447, green: 0.447, blue: 0.447)     // #727272
    private let muted = Color(red: 0.749, green: 0.749, blue: 0.749)   // #bfbfbf

    /// Radial highlight near the top centre falling off to black, per the
    /// design's gradient (#575757 → #000000).
    private let cardGradient = EllipticalGradient(
        stops: [
            .init(color: Color(red: 0.341, green: 0.341, blue: 0.341), location: 0.0),
            .init(color: Color(red: 0.255, green: 0.255, blue: 0.255), location: 0.25),
            .init(color: Color(red: 0.173, green: 0.173, blue: 0.173), location: 0.5),
            .init(color: Color(red: 0.086, green: 0.086, blue: 0.086), location: 0.75),
            .init(color: Color(red: 0.043, green: 0.043, blue: 0.043), location: 0.875),
            .init(color: .black, location: 1.0)
        ],
        center: UnitPoint(x: 0.515, y: 0.28),
        startRadiusFraction: 0,
        endRadiusFraction: 0.95
    )

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
    }

    // MARK: - Card

    private var card: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monthLabel)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(muted)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(MoneyFormat.grouped(spent))
                    .font(.system(size: 36, design: .monospaced))
                    .foregroundStyle(.white)
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
                categoryChart
                    .padding(.top, 4)
            }
        }
        .padding(16)
        .background(cardGradient, in: RoundedRectangle(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.black, lineWidth: 1)
        }
        .shadow(color: Color(white: 0.35).opacity(0.10), radius: 4.5, y: 4)
        .shadow(color: Color(white: 0.35).opacity(0.09), radius: 7.5, y: 15)
    }

    private var hairline: some View {
        Rectangle()
            .fill(.white.opacity(0.16))
            .frame(height: 1)
    }

    private func labelledValue(_ label: String, _ value: String) -> some View {
        HStack(spacing: 4) {
            Text(label)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(muted)
            Text(value + " RSD")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white)
                .contentTransition(.numericText())
        }
    }

    // MARK: - Category chart

    /// Plain vertical bar chart: one bar per category, tallest = biggest spend,
    /// scaled against the largest so the chart always fills its height.
    private var categoryChart: some View {
        // The caller decides how many rows to show (and folds the tail into
        // "Ostalo"), so every row it hands over gets a bar.
        let maxFraction = categories.map(\.fraction).max() ?? 1

        return HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(categories.enumerated()), id: \.element.id) { index, row in
                VStack(spacing: 6) {
                    ZStack(alignment: .bottom) {
                        Color.clear
                            .frame(height: Self.barAreaHeight)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(shade(index: index, row: row))
                            // Fixed width so these read as bars, not blocks;
                            // the floor keeps a stub visible for tiny ones.
                            .frame(
                                width: Self.barWidth,
                                height: max(3, Self.barAreaHeight * (row.fraction / max(maxFraction, 0.0001)))
                            )
                    }

                    Text(row.name)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(row.isUncategorized ? dim : muted)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }

    private static let barAreaHeight: CGFloat = 52
    private static let barWidth: CGFloat = 30

    private func shade(index: Int, row: CategorySpending.Row) -> Color {
        // Leftover buckets ("Bez kategorije", "Ostalo") stay dimmest so they
        // never read as the headline category.
        if row.isUncategorized { return .white.opacity(0.20) }
        let steps: [Double] = [0.95, 0.72, 0.55, 0.42, 0.32]
        return .white.opacity(index < steps.count ? steps[index] : 0.26)
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
