//
//  DayPickerSheet.swift
//  Receipt Tracker
//
//  Opened by tapping the month chip on Home: a calendar for jumping straight
//  to a day instead of swiping month by month.
//
//  Not the system date picker. That one draws in SF Pro and knows nothing
//  about spending; this one is set in the app's SF Mono and puts a dot under
//  every day that had receipts, darker the more was spent — so the calendar
//  answers "which day was that?" before anything is tapped.
//
//  Picking a day closes the sheet; Home then pages to that month and holds
//  the day up on the chart with the same glass read-out the press-and-hold
//  scrub uses.
//
//  The month and the year are two buttons in the header. Each swaps the days
//  for its own choice — the twelve months, or the years there are receipts
//  for — and picking one comes back to the days, so last spring is two taps
//  away instead of a dozen swipes.
//

import SwiftUI

struct DayPickerSheet: View {
    /// What the area under the header shows.
    private enum Mode {
        case days, months, years
    }

    @Environment(\.dismiss) private var dismiss

    let index: MonthIndex
    /// The day Home is currently holding up, if any — shown filled.
    let focusedDay: Date?
    var onSelect: (Date) -> Void

    /// The month on show. Starts on whatever month Home was on.
    @State private var month: Date
    /// Which way the last month change went, so the grid slides the right way.
    @State private var forward = true
    @State private var picks = 0
    /// Taps on each chevron, to kick its arrow.
    @State private var backKicks = 0
    @State private var forwardKicks = 0
    @State private var mode: Mode = .days

    /// Six rows of days under the header, and a margin under the last row
    /// like the one above the header — no band of empty sheet below.
    private static let sheetHeight: CGFloat = 468
    /// Every control in the header, chevrons and choices alike, is this tall —
    /// the close button's size, measured off the screen, so the header and the
    /// bar above it read as one set of glass.
    private static let controlSize: CGFloat = 42

    init(index: MonthIndex, initialMonth: Date, focusedDay: Date?, onSelect: @escaping (Date) -> Void) {
        self.index = index
        self.focusedDay = focusedDay
        self.onSelect = onSelect
        _month = State(initialValue: initialMonth)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                header
                // A real container, so each mode comes and goes as one piece.
                ZStack(alignment: .top) {
                    switch mode {
                    case .days:
                        days.transition(Self.swap)
                    case .months:
                        monthGrid.transition(Self.swap)
                    case .years:
                        yearGrid.transition(Self.swap)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            // Pinned to the top. Were the days ever a touch taller than the
            // sheet, a centred column would ride up by half the overflow and
            // the header would jump as the months came in.
            .frame(maxHeight: .infinity, alignment: .top)
            // The margin under the last row is set by the sheet's height, not
            // left to the home-indicator inset on top of it.
            .ignoresSafeArea(.container, edges: .bottom)
            .padding(.horizontal, 20)
            // Air between the title and the header.
            .padding(.top, 20)
            .monoNavigationTitle("Izaberi dan")
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
        .presentationDetents([.height(Self.sheetHeight), .large])
        // Opaque, like the app's other sheets. At this height the default glass
        // let Home's black buttons show through as dark bars across a week,
        // which read as a selected range.
        .presentationBackground(Color(uiColor: .systemBackground))
        .sensoryFeedback(.selection, trigger: picks)
    }

    /// The outgoing choice fades straight out; the incoming one comes up out of
    /// a blur a beat later, the way the rest of the app brings content in. Not
    /// scaled and not slid: the two grids never share the space long enough
    /// to be read over each other.
    private static let swap = AnyTransition.asymmetric(
        insertion: .modifier(active: BlurFade(shown: 0), identity: BlurFade(shown: 1))
            .animation(.easeOut(duration: 0.22).delay(0.06)),
        removal: .opacity.animation(.easeIn(duration: 0.1))
    )

    private func toggle(_ target: Mode) {
        withAnimation(.snappy(duration: 0.24)) {
            mode = mode == target ? .days : target
        }
    }

    // MARK: - Header

    /// The chevrons at the ends, the month and year buttons centred between
    /// them. The row reaches out to the navigation bar's own margin, so the
    /// chevrons line up with the close button above instead of sitting a few
    /// points inside it. The chevrons step months, so they step aside while
    /// the months or years are showing — there the two buttons are the
    /// controls.
    private var header: some View {
        HStack(spacing: 0) {
            chevron("chevron-left", direction: -1, enabled: canGoBack)
                .accessibilityLabel("Prethodni mesec")
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                choiceButton(Self.monthNameFormatter.string(from: month).sentenceCased, open: mode == .months) {
                    toggle(.months)
                }
                .accessibilityHint(mode == .months ? "Vraća na dane" : "Prikazuje mesece")

                choiceButton(String(year(of: month)), open: mode == .years) {
                    toggle(.years)
                }
                .accessibilityHint(mode == .years ? "Vraća na dane" : "Prikazuje godine")
            }
            Spacer(minLength: 8)
            chevron("chevron-right", direction: 1, enabled: canGoForward)
                .accessibilityLabel("Sledeći mesec")
        }
        // Out to the close button's edge. The content sits 20pt in from the
        // sheet, the close button's glass about 15pt, and a glass button draws
        // its glass 4pt inside its own frame — so the row reaches 9pt past the
        // content on each side. Measured to the pixel against the close button.
        .padding(.horizontal, -9)
        .sensoryFeedback(.selection, trigger: month)
    }

    /// Plain glass whether open or not — only the chevron beside the word turns
    /// over to say its choice is showing. Swapping to prominent glass on open
    /// rebuilt the button and lagged a beat behind the tap.
    private func choiceButton(_ title: String, open: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Text(title)
                    .font(.system(.body, design: .monospaced, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    // Rolls the way the month went.
                    .contentTransition(.numericText(countsDown: !forward))
                TablerIcon("chevron-down", size: 14)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(open ? 180 : 0))
            }
            .foregroundStyle(.primary)
            .frame(height: Self.controlLabelSize)
        }
        .buttonStyle(.glass)
    }

    /// The label size that, with the glass button's own padding round it, makes
    /// a control `controlSize` tall.
    private static let controlLabelSize: CGFloat = controlSize - 12

    /// Glass, like every other button in the app, so a press is felt: the
    /// glass gives under the finger, and the arrow kicks the way it points.
    private func chevron(_ icon: String, direction: CGFloat, enabled: Bool) -> some View {
        let kicks = direction < 0 ? backKicks : forwardKicks
        let active = mode == .days
        return Button {
            if direction < 0 { backKicks += 1 } else { forwardKicks += 1 }
            step(Int(direction))
        } label: {
            TablerIcon(icon, size: 18)
                .foregroundStyle(enabled ? .primary : .quaternary)
                .keyframeAnimator(initialValue: CGFloat(0), trigger: kicks) { content, x in
                    content.offset(x: x)
                } keyframes: { _ in
                    SpringKeyframe(direction * 4, duration: 0.1, spring: .snappy)
                    SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                }
                .frame(width: Self.controlLabelSize, height: Self.controlLabelSize)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!enabled || !active)
        .opacity(active ? 1 : 0)
        .accessibilityHidden(!active)
    }

    private var canGoBack: Bool { index.months.first.map { month > $0 } ?? false }
    private var canGoForward: Bool { index.months.last.map { month < $0 } ?? false }

    private func step(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        forward = delta > 0
        withAnimation(.smooth(duration: 0.32)) { month = next }
    }

    // MARK: - Days

    private var days: some View {
        VStack(spacing: 14) {
            weekdayRow
            ZStack {
                grid
                    .id(month)
                    .transition(.push(from: forward ? .trailing : .leading))
            }
            // Only the days are clipped, so the month slides within the grid.
            // Clipping the whole column also cut the top off the chevrons'
            // glass, which swells past its frame when pressed.
            .clipped()
        }
    }

    private var weekdayRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(Self.weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private var grid: some View {
        let calendar = Calendar.current
        let figures = index.figures(for: month)
        let totals = figures.dailyTotals
        let peak = (totals.max() ?? 0 as Decimal) as NSDecimalNumber
        // Monday first: weekday 2 lands in column 0, Sunday (1) in column 6.
        let leading = (calendar.component(.weekday, from: month) + 5) % 7

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 6) {
            // Blanks take negative ids and days positive ones. With both
            // counting from zero the grid treats day 1 and the first blank as
            // the same cell, and the 1st of the month goes missing.
            ForEach(-leading..<0, id: \.self) { _ in
                Color.clear.frame(height: 46)
            }
            ForEach(1...max(1, totals.count), id: \.self) { day in
                dayCell(day: day, amount: totals.indices.contains(day - 1) ? totals[day - 1] : 0,
                        peak: peak.doubleValue)
            }
        }
    }

    private func dayCell(day: Int, amount: Decimal, peak: Double) -> some View {
        let date = dateFor(day)
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let isFuture = date > Date() && !isToday
        let isFocused = focusedDay.map { calendar.isDate($0, inSameDayAs: date) } ?? false
        let spent = (amount as NSDecimalNumber).doubleValue

        return Button {
            picks += 1
            onSelect(date)
            dismiss()
        } label: {
            VStack(spacing: 4) {
                Text("\(day)")
                    .font(.system(.subheadline, design: .monospaced, weight: isToday ? .semibold : .regular))
                    .foregroundStyle(isFocused ? AnyShapeStyle(Color(uiColor: .systemBackground))
                                     : isFuture ? AnyShapeStyle(.quaternary) : AnyShapeStyle(.primary))
                // Spending that day: a dot that darkens with the amount. No
                // dot means nothing was bought.
                spendDot(spent: spent, peak: peak, inverted: isFocused)
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .background {
                if isFocused {
                    Circle().fill(Color.primary).frame(width: 42, height: 42)
                } else if isToday {
                    Circle().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1).frame(width: 42, height: 42)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarCellButtonStyle(width: 42, height: 42))
        .disabled(isFuture)
        .accessibilityLabel(Self.dayFormatter.string(from: date))
        .accessibilityValue(spent > 0 ? "\(MoneyFormat.grouped(amount)) dinara" : "bez potrošnje")
    }

    private func dateFor(_ day: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month], from: month)
        components.day = day
        return calendar.date(from: components) ?? month
    }

    // MARK: - Months

    /// The shown year's twelve months, three to a row, with the same spending
    /// dot as the days. Months Home has no page for — before the first receipt,
    /// or still to come — are dimmed.
    private var monthGrid: some View {
        let calendar = Calendar.current
        let available = Set(index.months)
        let shownYear = year(of: month)
        let months = (1...12).compactMap { calendar.date(from: DateComponents(year: shownYear, month: $0)) }
        let totals = months.map { available.contains($0) ? receiptsTotal(in: $0) : 0 }
        let peak = totals.max() ?? 0

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 8) {
            ForEach(Array(months.enumerated()), id: \.offset) { offset, candidate in
                choiceCell(
                    Self.shortMonthFormatter.string(from: candidate)
                        .replacingOccurrences(of: ".", with: "").sentenceCased,
                    spent: totals[offset], peak: peak,
                    isShown: calendar.isDate(candidate, equalTo: month, toGranularity: .month),
                    isNow: calendar.isDate(candidate, equalTo: Date(), toGranularity: .month),
                    enabled: available.contains(candidate)
                ) {
                    show(candidate)
                }
                .accessibilityLabel(Self.monthFormatter.string(from: candidate))
            }
        }
    }

    // MARK: - Years

    /// Every year there are receipts for, with a dot for how much went on them.
    private var yearGrid: some View {
        let calendar = Calendar.current
        let years = yearRange
        let totals = years.map { year in
            index.months
                .filter { calendar.component(.year, from: $0) == year }
                .reduce(0) { $0 + receiptsTotal(in: $1) }
        }
        let peak = totals.max() ?? 0
        let thisYear = calendar.component(.year, from: Date())
        // Three to a row, but no more columns than years: two years share the
        // width between them instead of huddling in the left two thirds.
        let columns = max(1, min(3, years.count))

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: columns), spacing: 8) {
            ForEach(Array(years.enumerated()), id: \.offset) { offset, candidate in
                choiceCell(
                    String(candidate),
                    spent: totals[offset], peak: peak,
                    isShown: candidate == year(of: month),
                    isNow: candidate == thisYear,
                    enabled: true
                ) {
                    show(sameMonth(inYear: candidate))
                }
                .accessibilityLabel("Godina \(candidate)")
            }
        }
    }

    /// The same month in another year — or, where that month has no page, the
    /// nearest one that does: the first month with receipts, or this month.
    private func sameMonth(inYear target: Int) -> Date {
        let calendar = Calendar.current
        let number = calendar.component(.month, from: month)
        guard let candidate = calendar.date(from: DateComponents(year: target, month: number)),
              let first = index.months.first, let last = index.months.last else { return month }
        return min(max(candidate, first), last)
    }

    private var yearRange: [Int] {
        guard let first = index.months.first, let last = index.months.last else { return [year(of: month)] }
        return Array(year(of: first)...year(of: last))
    }

    // MARK: - Choosing

    /// Back to the days, on the chosen month.
    private func show(_ target: Date) {
        forward = target > month
        withAnimation(.smooth(duration: 0.22)) {
            month = target
            mode = .days
        }
    }

    /// A month or a year in its grid: the word, the spending dot under it, the
    /// one on show filled, the current one ringed.
    private func choiceCell(_ title: String, spent: Double, peak: Double, isShown: Bool, isNow: Bool,
                            enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(.subheadline, design: .monospaced, weight: isNow ? .semibold : .regular))
                    .foregroundStyle(isShown ? AnyShapeStyle(Color(uiColor: .systemBackground))
                                     : enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                spendDot(spent: spent, peak: peak, inverted: isShown)
            }
            .frame(maxWidth: .infinity, minHeight: 56)
            .background {
                if isShown {
                    Capsule().fill(Color.primary).frame(width: 76, height: 50)
                } else if isNow {
                    Capsule().strokeBorder(Color.primary.opacity(0.3), lineWidth: 1).frame(width: 76, height: 50)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CalendarCellButtonStyle(width: 76, height: 50))
        .disabled(!enabled)
        .accessibilityValue(spent > 0 ? "\(MoneyFormat.grouped(Decimal(spent))) dinara" : "bez potrošnje")
    }

    /// Spending as a dot that darkens with the amount; none at all is no dot.
    private func spendDot(spent: Double, peak: Double, inverted: Bool) -> some View {
        Circle()
            .fill(inverted ? Color(uiColor: .systemBackground) : Color.primary)
            .frame(width: 4, height: 4)
            .opacity(spent > 0 && peak > 0 ? 0.3 + 0.7 * (spent / peak) : 0)
    }

    /// Receipts only, as the day dots are — fixed costs land on every month
    /// alike and would darken them all the same.
    private func receiptsTotal(in month: Date) -> Double {
        let total = index.figures(for: month).dailyTotals.reduce(Decimal(0), +)
        return (total as NSDecimalNumber).doubleValue
    }

    private func year(of date: Date) -> Int {
        Calendar.current.component(.year, from: date)
    }

    // MARK: - Formatting

    /// "P U S Č P S N" — Serbian, week starting Monday.
    private static let weekdaySymbols: [String] = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        let sundayFirst = f.veryShortStandaloneWeekdaySymbols ?? ["n", "p", "u", "s", "č", "p", "s"]
        return (Array(sundayFirst.dropFirst()) + [sundayFirst[0]]).map { $0.uppercased() }
    }()

    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMMM yyyy"
        return f
    }()

    /// "septembar" — the month on its own, for the header's month button.
    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "LLLL"
        return f
    }()

    /// "avg" — short, for the month grid.
    private static let shortMonthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "LLL"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()
}

/// Opacity and blur together, 0 hidden to 1 shown.
private struct BlurFade: ViewModifier {
    let shown: Double

    func body(content: Content) -> some View {
        content
            .opacity(shown)
            .blur(radius: (1 - shown) * 6)
    }
}

/// A day, month or year under the finger: a soft disc (a capsule, for months
/// and years) comes up behind it and the cell gives a little, so the press
/// shows before anything happens on release.
private struct CalendarCellButtonStyle: ButtonStyle {
    let width: CGFloat
    let height: CGFloat

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Capsule()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0))
                    .frame(width: width, height: height)
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
