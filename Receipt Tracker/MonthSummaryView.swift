//
//  MonthSummaryView.swift
//  Receipt Tracker
//
//  One month, reduced to what matters. Built to the Figma spec
//  ("New dashboard", node 324:6911).
//
//  The screen holds nothing but a month pill, the month's spend as the hero
//  figure, what it was measured against, today's spend, the daily rhythm as a
//  bar chart, and two buttons. Everything else — the receipts themselves, the
//  split per category — lives behind those buttons. The hierarchy is carried
//  by type size alone: no cards, no rules, no colour.
//
//  Colours derive from `.primary` rather than literal black so the screen
//  inverts with the appearance instead of staying light-mode forever.
//

import SwiftUI

struct MonthSummaryView: View {
    /// Month the screen is scoped to — drives the pill and every figure.
    let month: Date
    /// Everything spent in the month, fixed costs included.
    let spent: Decimal
    /// What that spending is measured against: everything added to the budget
    /// this month.
    let income: Decimal
    let spentToday: Decimal
    /// Spend per calendar day, index 0 = the 1st. Receipts only — fixed costs
    /// have no day to sit on, so they are in `spent` but not in the bars.
    let dailyTotals: [Decimal]
    let receiptCount: Int

    var onReceipts: () -> Void = {}
    var onCategories: () -> Void = {}

    // MARK: - Layout constants (from the Figma spec)

    private static let barAreaHeight: CGFloat = 56
    private static let minBarHeight: CGFloat = 3
    private static let barSpacing: CGFloat = 3

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)

            monthPill

            Spacer().frame(height: 24)

            figures

            Spacer().frame(height: 48)

            chart

            Spacer().frame(height: 48)

            buttons

            Spacer(minLength: 0)
        }
        // 24pt of screen inset plus 24pt inside it — the content column is
        // 294pt wide on a 390pt screen, exactly two buttons and their gap.
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Month pill

    private var monthPill: some View {
        HStack(spacing: 5) {
            Text(monthName)
            Text(yearString)
        }
        .font(.system(size: 13, design: .monospaced))
        .tracking(-0.43)
        .foregroundStyle(.primary)
        .padding(.horizontal, 11)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemFill), in: .capsule)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Mesec: \(monthName) \(yearString)")
    }

    // MARK: - Figures

    private var figures: some View {
        VStack(spacing: 0) {
            Text(MoneyFormat.grouped(spent))
                .font(.system(size: 33, weight: .medium, design: .monospaced))
                .tracking(-0.43)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .accessibilityLabel("Potrošeno \(MoneyFormat.grouped(spent)) dinara")

            Text("Od \(MoneyFormat.grouped(income))")
                .font(.system(size: 13, design: .monospaced))
                .tracking(-0.08)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
                .accessibilityLabel("Od \(MoneyFormat.grouped(income)) dinara")

            // Only the month on the calendar has a "today" to report.
            if isCurrentMonth {
                Text("\(MoneyFormat.grouped(spentToday)) danas")
                    .font(.system(size: 11, design: .monospaced))
                    .tracking(-0.08)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
                    .padding(.top, 8)
                    .accessibilityLabel("Danas \(MoneyFormat.grouped(spentToday)) dinara")
            }
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Daily chart

    /// One bar per day of the month. Today is the only solid bar; the days
    /// still to come are stubs, so the month reads as "this far in" at a
    /// glance. The bars share the width evenly, which keeps 28-day and 31-day
    /// months on the same footing.
    private var chart: some View {
        VStack(spacing: 8) {
            HStack(alignment: .bottom, spacing: Self.barSpacing) {
                ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, amount in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor(day: index))
                        .frame(height: barHeight(amount, day: index))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: Self.barAreaHeight, alignment: .bottom)
            .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dailyTotals)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Potrošnja po danima")
            .accessibilityValue(chartAccessibilityValue)

            axis
        }
    }

    private var axis: some View {
        HStack(spacing: 4) {
            Text(edgeDayLabel(first: true))
                .foregroundStyle(.tertiary)

            Spacer(minLength: 0)

            if isCurrentMonth {
                Text("danas")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }

            Spacer(minLength: 0)

            Text(edgeDayLabel(first: false))
                .foregroundStyle(.tertiary)
        }
        .font(.system(size: 9, design: .monospaced))
        .accessibilityHidden(true)
    }

    /// Bars are scaled against the month's own busiest day, so a quiet month
    /// still shows a shape instead of a flat line.
    private var peakDailyTotal: Decimal {
        dailyTotals.max() ?? 0
    }

    private func barHeight(_ amount: Decimal, day index: Int) -> CGFloat {
        guard !isFuture(day: index), peakDailyTotal > 0 else { return Self.minBarHeight }
        let fraction = (amount as NSDecimalNumber).doubleValue / (peakDailyTotal as NSDecimalNumber).doubleValue
        return max(Self.minBarHeight, Self.barAreaHeight * fraction)
    }

    private func barColor(day index: Int) -> Color {
        if isToday(day: index) { return .primary }
        if isFuture(day: index) { return .primary.opacity(0.08) }
        return .primary.opacity(0.28)
    }

    private func isToday(day index: Int) -> Bool {
        isCurrentMonth && index + 1 == Calendar.current.component(.day, from: Date())
    }

    private func isFuture(day index: Int) -> Bool {
        isCurrentMonth && index + 1 > Calendar.current.component(.day, from: Date())
    }

    private var chartAccessibilityValue: String {
        let spentDays = dailyTotals.filter { $0 > 0 }.count
        return "\(spentDays) dana sa potrošnjom, najviše \(MoneyFormat.grouped(peakDailyTotal)) dinara"
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            glassButton("Računi (\(receiptCount))", action: onReceipts)
            glassButton("Kategorije", action: onCategories)
        }
    }

    /// Native Liquid Glass, prominent. The label is pinned to the system
    /// background colour on purpose: the app tints everything `.primary`, which
    /// fills a prominent glass button with the same ink as its text.
    private func glassButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(Color(uiColor: .systemBackground))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, minHeight: 34)
        }
        .buttonStyle(.glassProminent)
    }

    // MARK: - Text

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var monthName: String {
        Self.monthFormatter.string(from: month).sentenceCased
    }

    private var yearString: String {
        Self.yearFormatter.string(from: month)
    }

    /// "1. sep" / "30. sep" — the ends of the axis.
    private func edgeDayLabel(first: Bool) -> String {
        let calendar = Calendar.current
        let day = first ? 1 : (calendar.range(of: .day, in: .month, for: month)?.count ?? dailyTotals.count)
        return "\(day). \(Self.shortMonthFormatter.string(from: month))"
    }

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMMM"
        return f
    }()

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMM"
        return f
    }()

    private static let yearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "yyyy"
        return f
    }()
}

#Preview {
    MonthSummaryView(
        month: Date(),
        spent: 568_212,
        income: 435_871,
        spentToday: 13_840,
        dailyTotals: [3_200, 1_100, 0, 4_500, 2_000, 800, 6_100, 2_400, 0, 1_900,
                      3_300, 12_000, 2_200, 0, 1_500, 4_800, 2_900, 600, 7_400, 3_100,
                      0, 6_080, 13_840, 0, 0, 0, 0, 0, 0, 0],
        receiptCount: 34
    )
    .background(Color(uiColor: .systemGroupedBackground))
}
