//
//  MonthSummaryView.swift
//  Receipt Tracker
//
//  One month, reduced to what matters. Built to the Figma spec
//  ("New dashboard", node 324:6911).
//
//  The page holds the month's spend as the hero figure, what it was measured
//  against, today's spend, the daily rhythm as a bar chart, and two buttons.
//  Everything else — the receipts themselves, the split per category — lives
//  behind those buttons. The hierarchy is carried by type size alone: no
//  cards, no rules, no colour.
//
//  The month label is NOT here: it belongs to the shared pager indicator
//  above, which morphs between months as you swipe (see MonthPagerIndicator).
//
//  Colours derive from `.primary` rather than literal black so the page
//  inverts with the appearance instead of staying light-mode forever.
//

import SwiftUI
import UIKit

struct MonthSummaryView: View {
    /// Month the page is scoped to — drives every figure.
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
    /// Raised while a day is being read off the chart, so the pager can hold
    /// still instead of turning the page under the scrubbing finger.
    var onScrubbingChanged: (Bool) -> Void = { _ in }

    /// How long the staggered entrance takes end to end: the last element's
    /// delay plus its spring. `RootView` waits this out before sliding the tab
    /// bar up, so the screen assembles top-down and the chrome arrives last.
    static let revealDuration: Double = 0.32 + 0.42

    /// Fixed so every page lines up: the "danas" line is only meaningful for
    /// the month on the calendar, but its slot is reserved on every page so
    /// the chart and buttons don't shift as you swipe across months.
    static let pageHeight: CGFloat = 320

    // MARK: - Layout constants (from the Figma spec)

    private static let barAreaHeight: CGFloat = 56
    private static let minBarHeight: CGFloat = 3
    private static let barSpacing: CGFloat = 3

    // MARK: - State

    /// Staggered entrance, run once as the page swings into view.
    @State private var revealed = false
    /// Day index currently under the finger during a press-and-hold scrub.
    @State private var scrubbedDay: Int?
    @State private var chartWidth: CGFloat = 0
    @State private var popupWidth: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            figures
            Spacer().frame(height: 48)
            chart
            Spacer().frame(height: 48)
            buttons
        }
        // 24pt of screen inset plus 24pt inside it — the content column is
        // 294pt wide on a 390pt screen, exactly two buttons and their gap.
        .padding(.horizontal, 48)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // The depth effect as pages slide past lives on the pager, in a
        // `scrollTransition`: applied while drawing, instead of re-running this
        // body on every frame of the swipe to feed it an offset.
        //
        // The entrance fires once a fifth of the page is on screen — the same
        // point as before, but reported by the scroll view rather than worked
        // out from the offset frame by frame.
        .onScrollVisibilityChange(threshold: 0.2) { visible in
            if visible { revealed = true }
        }
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
                .reveal(revealed, delay: 0)

            Text("Od \(MoneyFormat.grouped(income))")
                .font(.system(size: 13, design: .monospaced))
                .tracking(-0.08)
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .padding(.top, 2)
                .accessibilityLabel("Od \(MoneyFormat.grouped(income)) dinara")
                .reveal(revealed, delay: 0.05)

            // The slot is always here; only the month on the calendar has a
            // "today" to report, so past months get a blank line of the same
            // height and every page stays in register.
            Text(isCurrentMonth ? "\(MoneyFormat.grouped(spentToday)) danas" : " ")
                .font(.system(size: 11, design: .monospaced))
                .tracking(-0.08)
                .foregroundStyle(.secondary)
                .contentTransition(.numericText())
                .padding(.top, 8)
                .accessibilityLabel(isCurrentMonth ? "Danas \(MoneyFormat.grouped(spentToday)) dinara" : "")
                .reveal(revealed, delay: 0.10)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    // MARK: - Daily chart

    /// One bar per day of the month. Today is the only solid bar; the days
    /// still to come are stubs, so the month reads as "this far in" at a
    /// glance. Press and hold to scrub a day and read its exact total.
    private var chart: some View {
        VStack(spacing: 8) {
            bars
                .overlay(alignment: .topLeading) { scrubPopup }
            axis
        }
    }

    private var bars: some View {
        // Worked out once for the whole chart. The busiest day and today's
        // index used to be recomputed inside every one of the 30 bars — the
        // busiest day by scanning all 30 again each time.
        let peak = (peakDailyTotal as NSDecimalNumber).doubleValue
        let today = todayIndex
        let scrubbed = scrubbedDay

        return HStack(alignment: .bottom, spacing: Self.barSpacing) {
            ForEach(Array(dailyTotals.enumerated()), id: \.offset) { index, amount in
                RoundedRectangle(cornerRadius: 2)
                    .fill(barColor(index, today: today, scrubbed: scrubbed))
                    .frame(height: barHeight(amount, index, today: today, peak: peak))
                    .frame(maxWidth: .infinity)
                    // Grows out of the baseline, sweeping the month from the
                    // 1st to the last — the chart filling up in order, which
                    // is the one direction that means something here.
                    .scaleEffect(y: revealed ? 1 : 0, anchor: .bottom)
                    .opacity(revealed ? 1 : 0)
                    .animation(
                        .spring(response: 0.42, dampingFraction: 0.82)
                            .delay(0.15 + Double(index) * 0.004),
                        value: revealed
                    )
            }
        }
        .frame(height: Self.barAreaHeight, alignment: .bottom)
        // One blur for the whole chart as it pulls into focus, not one per
        // bar: the same look, from one blurred layer instead of thirty.
        .blur(radius: revealed ? 0 : 4)
        .animation(.spring(response: 0.42, dampingFraction: 0.88).delay(0.15), value: revealed)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: dailyTotals)
        .contentShape(.rect)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { chartWidth = $0 }
        // Hold to read a day off the chart. This is a UIKit recogniser rather
        // than a SwiftUI `LongPressGesture`: SwiftUI's holds onto the touch
        // while it decides, which killed the pager for any swipe that started
        // on the chart. UIKit's bows out the moment the finger travels, so a
        // swipe still turns the page, and once the hold *does* win,
        // `onScrubbingChanged` freezes the pager so the two never share a drag.
        .overlay {
            ChartScrubber { x in
                guard let x else {
                    scrubbedDay = nil
                    return
                }
                let day = day(atX: x)
                if scrubbedDay != day { scrubbedDay = day }
            }
        }
        .sensoryFeedback(.selection, trigger: scrubbedDay)
        .onChange(of: scrubbedDay != nil) { _, active in onScrubbingChanged(active) }
        .animation(.spring(response: 0.3, dampingFraction: 0.8), value: scrubbedDay)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Potrošnja po danima")
        .accessibilityValue(chartAccessibilityValue)
    }

    /// Reads out the scrubbed day as Liquid Glass, floating over the chart.
    @ViewBuilder
    private var scrubPopup: some View {
        if let day = scrubbedDay {
            VStack(spacing: 2) {
                Text(dayLabel(day))
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(MoneyFormat.grouped(amount(forDay: day)) + " RSD")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 14))
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { popupWidth = $0 }
            .offset(x: popupX(for: day), y: -(Self.barAreaHeight + 6))
            .allowsHitTesting(false)
            .transition(.scale(scale: 0.9, anchor: .bottom).combined(with: .opacity))
        }
    }

    private var axis: some View {
        HStack(spacing: 4) {
            Text(edgeDayLabel(first: true))
            Spacer(minLength: 0)
            Text(edgeDayLabel(first: false))
        }
        .font(.system(size: 9, design: .monospaced))
        .foregroundStyle(.tertiary)
        .accessibilityHidden(true)
        .reveal(revealed, delay: 0.24)
    }

    // MARK: - Chart maths

    /// Bars are scaled against the month's own busiest day, so a quiet month
    /// still shows a shape instead of a flat line.
    private var peakDailyTotal: Decimal {
        dailyTotals.max() ?? 0
    }

    private func barHeight(_ amount: Decimal, _ index: Int, today: Int?, peak: Double) -> CGFloat {
        let isFuture = today.map { index > $0 } ?? false
        guard !isFuture, peak > 0 else { return Self.minBarHeight }
        let fraction = (amount as NSDecimalNumber).doubleValue / peak
        return max(Self.minBarHeight, Self.barAreaHeight * fraction)
    }

    private func barColor(_ index: Int, today: Int?, scrubbed: Int?) -> Color {
        if scrubbed == index || today == index { return .primary }
        if let today, index > today { return .primary.opacity(0.08) }
        // Everything dims a little while another day is being read.
        return .primary.opacity(scrubbed == nil ? 0.28 : 0.16)
    }

    private func day(atX x: CGFloat) -> Int {
        guard chartWidth > 0, !dailyTotals.isEmpty else { return 0 }
        let slot = chartWidth / CGFloat(dailyTotals.count)
        return min(dailyTotals.count - 1, max(0, Int(x / slot)))
    }

    /// Centres the popup over the scrubbed bar, but keeps it inside the chart.
    private func popupX(for day: Int) -> CGFloat {
        guard chartWidth > 0, !dailyTotals.isEmpty else { return 0 }
        let slot = chartWidth / CGFloat(dailyTotals.count)
        let barCentre = slot * (CGFloat(day) + 0.5)
        let half = popupWidth / 2
        return min(max(barCentre - half, 0), max(0, chartWidth - popupWidth))
    }

    private func amount(forDay index: Int) -> Decimal {
        dailyTotals.indices.contains(index) ? dailyTotals[index] : 0
    }

    /// Today's bar, or nil for any month but the current one. Days after it
    /// are still to come.
    private var todayIndex: Int? {
        guard isCurrentMonth else { return nil }
        return Calendar.current.component(.day, from: Date()) - 1
    }

    private var chartAccessibilityValue: String {
        let spentDays = dailyTotals.filter { $0 > 0 }.count
        return "\(spentDays) dana sa potrošnjom, najviše \(MoneyFormat.grouped(peakDailyTotal)) dinara"
    }

    // MARK: - Buttons

    private var buttons: some View {
        HStack(spacing: 8) {
            glassButton("Računi (\(receiptCount))", action: onReceipts)
                .reveal(revealed, delay: 0.28)
            glassButton("Kategorije", action: onCategories)
                .reveal(revealed, delay: 0.32)
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

    /// "sre, 23. sep" for the scrub popup.
    private func dayLabel(_ index: Int) -> String {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = index + 1
        guard let date = calendar.date(from: components) else { return "" }
        return Self.scrubFormatter.string(from: date).sentenceCased
    }

    /// "1. sep" / "30. sep" — the ends of the axis.
    private func edgeDayLabel(first: Bool) -> String {
        let calendar = Calendar.current
        let day = first ? 1 : (calendar.range(of: .day, in: .month, for: month)?.count ?? dailyTotals.count)
        return "\(day). \(Self.shortMonthFormatter.string(from: month))"
    }

    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMM"
        return f
    }()

    private static let scrubFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEE, d. MMM"
        return f
    }()
}

// MARK: - Equatable

/// A page only needs redrawing when what it shows changes. Home re-runs once
/// mid-swipe, when the settled month flips; without this every page the pager
/// has built — about six — would redraw its chart for identical figures. The
/// callbacks are left out on purpose: they always do the same thing.
extension MonthSummaryView: Equatable {
    static func == (lhs: MonthSummaryView, rhs: MonthSummaryView) -> Bool {
        lhs.month == rhs.month
            && lhs.receiptCount == rhs.receiptCount
            && lhs.spent == rhs.spent
            && lhs.income == rhs.income
            && lhs.spentToday == rhs.spentToday
            && lhs.dailyTotals == rhs.dailyTotals
    }
}

// MARK: - Chart scrubbing

/// Press-and-hold tracking that co-operates with an enclosing scroll view.
///
/// `UILongPressGestureRecognizer` fails as soon as the finger travels more than
/// a few points before the press duration is up, so an ordinary swipe is never
/// stolen from the pager; only a deliberate hold wins. `cancelsTouchesInView`
/// stays false and the delegate allows simultaneous recognition so the touch
/// keeps flowing to everything else.
private struct ChartScrubber: UIViewRepresentable {
    /// x in the overlay's own coordinate space, or nil once the hold ends.
    var onChange: (CGFloat?) -> Void

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        let recognizer = UILongPressGestureRecognizer(
            target: context.coordinator,
            action: #selector(Coordinator.handle(_:))
        )
        recognizer.minimumPressDuration = 0.18
        recognizer.cancelsTouchesInView = false
        recognizer.delegate = context.coordinator
        view.addGestureRecognizer(recognizer)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onChange = onChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    final class Coordinator: NSObject, UIGestureRecognizerDelegate {
        var onChange: (CGFloat?) -> Void

        init(onChange: @escaping (CGFloat?) -> Void) {
            self.onChange = onChange
        }

        @objc func handle(_ recognizer: UILongPressGestureRecognizer) {
            switch recognizer.state {
            case .began, .changed:
                onChange(recognizer.location(in: recognizer.view).x)
            default:
                onChange(nil)
            }
        }

        func gestureRecognizer(
            _ gestureRecognizer: UIGestureRecognizer,
            shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
        ) -> Bool {
            true
        }
    }
}

// MARK: - Staggered entrance

private extension View {
    /// Composed entrance: the element pulls into focus out of a blur while it
    /// fades up and rises the last few points onto a spring. Three properties
    /// rather than one — a bare fade reads as a glitch, and the blur is what
    /// makes it read as coming into focus rather than switching on.
    ///
    /// `delay` staggers the block from the top down: the figure first, then
    /// what it is measured against, then the chart, then the buttons — the
    /// order the screen is read in.
    func reveal(_ revealed: Bool, delay: Double) -> some View {
        self
            .opacity(revealed ? 1 : 0)
            .offset(y: revealed ? 0 : 10)
            .blur(radius: revealed ? 0 : 6)
            .animation(.spring(response: 0.42, dampingFraction: 0.88).delay(delay), value: revealed)
    }
}

#Preview {
    MonthSummaryView(
        month: Date(),
        spent: 568_212,
        income: 435_871,
        spentToday: 13_840,
        dailyTotals: [3_200, 1_100, 700, 4_500, 2_000, 800, 6_100, 2_400, 700, 1_900,
                      3_300, 12_000, 2_200, 700, 1_500, 4_800, 2_900, 600, 7_400, 3_100,
                      700, 6_080, 13_840, 0, 0, 0, 0, 0, 0, 0],
        receiptCount: 34
    )
    .frame(height: MonthSummaryView.pageHeight)
    .background(Color(uiColor: .systemGroupedBackground))
}
