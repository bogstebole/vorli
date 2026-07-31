//
//  SummaryHeaderCard.swift
//  Receipt Tracker
//
//  Home header, built to the Figma spec ("New dashboard", node 263:1549):
//  a black receipt-slip card — date chip + balance on top, dashed tear line,
//  then the month's spend as the hero number with today's spend under it.
//
//  The card stays black in both appearances (as designed); the white inset
//  stroke is what separates it from a dark background.
//

import SwiftUI

struct SummaryHeaderCard: View {
    /// Month the screen is scoped to — drives the chip and the totals.
    let month: Date
    let balance: Decimal
    let spent: Decimal
    let spentToday: Decimal
    /// Same rows as the list below the card, so the bar doubles as its legend.
    var categories: [CategorySpending.Row] = []

    var onSettings: () -> Void = {}

    // Figma palette (fixed on the black card, so not semantic colors).
    private let dim = Color(red: 0.447, green: 0.447, blue: 0.447)      // #727272
    private let bright = Color(red: 0.851, green: 0.851, blue: 0.851)   // #d9d9d9
    private let value = Color(red: 0.749, green: 0.749, blue: 0.749)    // #bfbfbf

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            topRow
            tearLine
            amountBlock
            if !categories.isEmpty {
                categoryBar
            }
        }
        .padding(12)
        .background(Color.black, in: RoundedRectangle(cornerRadius: 12))
        .overlay {
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(Color.white.opacity(0.65), lineWidth: 2)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Top row: date chip + balance

    private var topRow: some View {
        HStack(spacing: 4) {
            HStack(spacing: 8) {
                Text(chipText)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.8), in: RoundedRectangle(cornerRadius: 4))

                Text(yearText)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(dim)
            }
            .padding(.leading, 2)
            .padding(.trailing, 8)
            .padding(.vertical, 2)
            .background(Color.white.opacity(0.21), in: RoundedRectangle(cornerRadius: 6))

            Spacer(minLength: 4)

            // Balance, then settings — same row as the chip, per the design.
            HStack(spacing: 0) {
                Text("Stanje — ")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(bright)
                Text(MoneyFormat.signed(balance))
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(value)
                    .contentTransition(.numericText())
            }
            .lineLimit(1)

            Button(action: onSettings) {
                TablerIcon("settings", size: 15)
                    .foregroundStyle(bright)
                    .frame(width: 24, height: 24)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Podešavanja")
        }
    }

    private var tearLine: some View {
        DashedLine()
            .stroke(Color.white.opacity(0.28), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .frame(height: 1)
            .padding(.vertical, 4)
    }

    // MARK: - Hero amount

    private var amountBlock: some View {
        VStack(spacing: 4) {
            VStack(spacing: 0) {
                Text("RSD")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dim)

                Text(MoneyFormat.grouped(spent))
                    .font(.system(size: 36, design: .monospaced))
                    .foregroundStyle(bright)
                    .contentTransition(.numericText())
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
            }

            if isCurrentMonth {
                HStack(spacing: 4) {
                    Text("Danas — ")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(bright)
                    Text(MoneyFormat.grouped(spentToday))
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(dim)
                        .contentTransition(.numericText())
                }
            } else {
                Text("potrošeno ovog meseca")
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(dim)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    // MARK: - Category bar

    /// Monochrome breakdown of the month's spend: one segment per category,
    /// brightest for the biggest. Widths come from the same fractions as the
    /// list below, so segment order and sizes match it exactly.
    private var categoryBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            GeometryReader { geometry in
                let gap: CGFloat = 2
                let usable = max(0, geometry.size.width - gap * CGFloat(max(0, categories.count - 1)))
                HStack(spacing: gap) {
                    ForEach(Array(categories.enumerated()), id: \.element.id) { index, row in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(shade(index: index, row: row))
                            // Floor keeps a sliver visible for tiny categories.
                            .frame(width: max(3, usable * row.fraction))
                    }
                }
            }
            .frame(height: 8)
            // The 3pt floor above can round past the available width when many
            // categories are tiny; clipping keeps the bar inside the card.
            .clipped()

            HStack(spacing: 4) {
                Text(topCategoryLabel)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(dim)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
        }
        .padding(.top, 4)
    }

    private func shade(index: Int, row: CategorySpending.Row) -> Color {
        // The leftover buckets ("Bez kategorije", "Ostalo") stay dimmest so
        // they never read as the headline category.
        if row.isUncategorized { return .white.opacity(0.16) }
        let steps: [Double] = [0.92, 0.70, 0.54, 0.42, 0.32]
        return .white.opacity(index < steps.count ? steps[index] : 0.24)
    }

    /// One line of context so the bar isn't abstract: the biggest category.
    private var topCategoryLabel: String {
        guard let top = categories.first(where: { !$0.isUncategorized }) ?? categories.first else { return "" }
        return "\(top.name) \(Int((top.fraction * 100).rounded()))%"
    }

    // MARK: - Text

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    /// Today's date while browsing the current month; the month's name when
    /// browsing an older one — a day chip would be a lie there.
    private var chipText: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        formatter.dateFormat = isCurrentMonth ? "EEE, d. MMM" : "MMMM"
        return formatter.string(from: isCurrentMonth ? Date() : month).sentenceCased
    }

    private var yearText: String {
        String(Calendar.current.component(.year, from: month))
    }
}

// MARK: - Dashed tear line

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        return path
    }
}

#Preview {
    VStack {
        SummaryHeaderCard(
            month: Date(),
            balance: 350_000,
            spent: 56_212,
            spentToday: 1_000
        )
        Spacer()
    }
    .padding(.top, 48)
}
