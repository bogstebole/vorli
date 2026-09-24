//
//  MonthCategoriesView.swift
//  Receipt Tracker
//
//  Where the month's money went — the "Kategorije" tab of the month's details
//  sheet: a doughnut with the month's total in the hole, then a row per
//  category.
//
//  This is the one screen in the app that carries colour. Everything else is
//  monochrome on purpose, but a share-of-total chart has to separate six
//  slices from one another, and shades of grey stop being tellable apart
//  around the third one.
//
//  Type follows the app's scale — `.subheadline` for rows, `.caption`/`.caption2`
//  for annotations — rather than the fixed point sizes the home screen takes
//  from its Figma spec.
//

import SwiftUI
import Charts

struct MonthCategoriesView: View {
    /// Sorted largest first by the caller, and summing to `total`.
    let rows: [CategorySpending.Row]
    let total: Decimal

    var body: some View {
        if rows.isEmpty {
            emptyState
        } else {
            ScrollView {
                VStack(spacing: 28) {
                    doughnut
                    legend
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 32)
            }
        }
    }

    // MARK: - Doughnut

    /// Slices sit in the same order as the rows below, so the ring and the list
    /// read as one object. `angularInset` is the 2pt of surface between
    /// neighbours that keeps two similar hues from bleeding together.
    private var doughnut: some View {
        Chart(slices, id: \.row.id) { slice in
            SectorMark(
                angle: .value("Iznos", (slice.row.total as NSDecimalNumber).doubleValue),
                innerRadius: .ratio(0.64),
                angularInset: 1.5
            )
            .cornerRadius(3)
            .foregroundStyle(slice.color)
            .accessibilityLabel(slice.row.name)
            .accessibilityValue("\(MoneyFormat.grouped(slice.row.total)) dinara, \(percent(slice.row)) odsto")
        }
        .chartLegend(.hidden)
        .frame(height: 220)
        // The hole is the obvious place for the figure the slices add up to.
        .overlay {
            VStack(spacing: 2) {
                Text(MoneyFormat.grouped(total))
                    .font(.system(.title3, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .contentTransition(.numericText())
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                Text("RSD ukupno")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 48)
            .accessibilityHidden(true)
        }
        .accessibilityLabel("Potrošnja po kategorijama")
    }

    // MARK: - Legend

    /// Always present, and always carrying the name and the amount — the light
    /// slices sit under 3:1 against a white sheet, so the words are what make
    /// them identifiable, not the colour on its own.
    private var legend: some View {
        VStack(spacing: 14) {
            ForEach(slices, id: \.row.id) { slice in
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(slice.color)
                        .frame(width: 10, height: 10)

                    Text(slice.row.name)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 8)

                    Text("\(percent(slice.row))%")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)

                    Text(MoneyFormat.grouped(slice.row.total))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.primary)
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel("\(slice.row.name): \(MoneyFormat.grouped(slice.row.total)) dinara, \(percent(slice.row)) odsto")
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

            Text("Skenirajte račun ili dodajte fiksni trošak.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Slices

    private struct Slice {
        let row: CategorySpending.Row
        let color: Color
    }

    /// Hues are handed out in the palette's fixed order and never cycled: past
    /// the last slot the tail folds into one "Ostalo" wedge. "Bez kategorije"
    /// is never given a hue either — it isn't a category, it's what is left.
    private var slices: [Slice] {
        var result: [Slice] = []
        var slot = 0
        var folded: Decimal = 0
        var foldedFraction: Double = 0

        for row in rows {
            if row.isUncategorized {
                result.append(Slice(row: row, color: CategoryPalette.neutral))
            } else if slot < CategoryPalette.slots.count {
                result.append(Slice(row: row, color: CategoryPalette.slots[slot]))
                slot += 1
            } else {
                folded += row.total
                foldedFraction += row.fraction
            }
        }

        if folded > 0 {
            result.append(Slice(
                row: CategorySpending.Row(name: "Ostalo", total: folded,
                                          fraction: foldedFraction, isUncategorized: false),
                color: CategoryPalette.fold
            ))
        }
        return result
    }

    private func percent(_ row: CategorySpending.Row) -> Int {
        Int((row.fraction * 100).rounded())
    }

}

// MARK: - Palette

/// Categorical hues for the category chart.
///
/// Not picked by eye: this is a validated categorical order, checked for
/// lightness band, chroma, colour-blind separation and contrast against both
/// the light and the dark sheet surface. The *order* is the safety mechanism —
/// neighbouring slots are the pairs proven to stay apart under protanopia,
/// deuteranopia and tritanopia — so slots are handed out in sequence and never
/// shuffled or cycled.
enum CategoryPalette {
    static let slots: [Color] = [
        adaptive(light: 0x2A78D6, dark: 0x3987E5),   // blue
        adaptive(light: 0xEB6834, dark: 0xD95926),   // orange
        adaptive(light: 0x1BAF7A, dark: 0x199E70),   // aqua
        adaptive(light: 0xEDA100, dark: 0xC98500),   // yellow
        adaptive(light: 0xE87BA4, dark: 0xD55181),   // magenta
        adaptive(light: 0x008300, dark: 0x008300)    // green
    ]

    /// "Bez kategorije" — the leftover bucket, deliberately colourless.
    static let neutral = Color.secondary
    /// The folded tail, one step quieter again.
    static let fold = Color.gray.opacity(0.45)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(uiColor: UIColor { traits in
            UIColor(rgb: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

#Preview {
    MonthCategoriesView(
        rows: [
            .init(name: "Hrana", total: 46_120, fraction: 0.39, isUncategorized: false),
            .init(name: "Fiksni troškovi", total: 32_000, fraction: 0.27, isUncategorized: false),
            .init(name: "Prevoz", total: 14_800, fraction: 0.13, isUncategorized: false),
            .init(name: "Tehnika", total: 12_990, fraction: 0.11, isUncategorized: false),
            .init(name: "Kafa", total: 6_430, fraction: 0.05, isUncategorized: false),
            .init(name: "Bez kategorije", total: 6_000, fraction: 0.05, isUncategorized: true)
        ],
        total: 118_340
    )
}
