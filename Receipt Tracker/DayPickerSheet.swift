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
//  Tapping the month's name swaps the days for the year's twelve months, the
//  way the system calendar does, and the chevrons then step whole years — so
//  last spring is two taps away instead of a dozen.
//

import SwiftUI

struct DayPickerSheet: View {
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
    /// Showing the year's months instead of the month's days.
    @State private var choosingMonth = false
    /// The year on show while choosing a month.
    @State private var year: Int

    init(index: MonthIndex, initialMonth: Date, focusedDay: Date?, onSelect: @escaping (Date) -> Void) {
        self.index = index
        self.focusedDay = focusedDay
        self.onSelect = onSelect
        _month = State(initialValue: initialMonth)
        _year = State(initialValue: Calendar.current.component(.year, from: initialMonth))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                monthHeader
                if choosingMonth {
                    ZStack {
                        monthGrid
                            .id(year)
                            .transition(.push(from: forward ? .trailing : .leading))
                    }
                    .clipped()
                    .transition(Self.modeTransition)
                } else {
                    VStack(spacing: 14) {
                        weekdayRow
                        ZStack {
                            grid
                                .id(month)
                                .transition(.push(from: forward ? .trailing : .leading))
                        }
                        // Only the days are clipped, so the month slides within
                        // the grid. Clipping the whole column also cut the top
                        // off the chevrons' glass, which swells past its frame
                        // when pressed.
                        .clipped()
                    }
                    .transition(Self.modeTransition)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
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
        .presentationDetents([.height(500), .large])
        // Opaque, like the app's other sheets. At this height the default glass
        // let Home's black buttons show through as dark bars across a week,
        // which read as a selected range.
        .presentationBackground(Color(uiColor: .systemBackground))
        .sensoryFeedback(.selection, trigger: picks)
    }

    // MARK: - Month header

    /// Laid out on the grid's own seven columns, so the chevrons sit exactly
    /// over Monday and Sunday instead of floating somewhere in between; the
    /// title is centred across the whole row above them. The chevrons stay put
    /// when the months are showing — they step years then — so nothing under
    /// the thumb moves when the mode changes.
    private var monthHeader: some View {
        HStack(spacing: 0) {
            chevron("chevron-left", direction: -1, enabled: canGoBack)
                .accessibilityLabel(choosingMonth ? "Prethodna godina" : "Prethodni mesec")
                .frame(maxWidth: .infinity)
            ForEach(0..<5, id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
            chevron("chevron-right", direction: 1, enabled: canGoForward)
                .accessibilityLabel(choosingMonth ? "Sledeća godina" : "Sledeći mesec")
                .frame(maxWidth: .infinity)
        }
        .overlay { titleButton }
        .sensoryFeedback(.selection, trigger: month)
        .sensoryFeedback(.selection, trigger: year)
    }

    /// The month's name, or the year while choosing a month. A chevron beside
    /// it says it opens; it turns over while the months are showing.
    private var titleButton: some View {
        Button(action: toggleMonthChoice) {
            HStack(spacing: 6) {
                Text(choosingMonth ? String(year) : Self.monthFormatter.string(from: month).sentenceCased)
                    .font(.system(.headline, design: .monospaced))
                    .foregroundStyle(.primary)
                    // The year rolls the way the month went.
                    .contentTransition(.numericText(countsDown: !forward))
                TablerIcon("chevron-down", size: 14)
                    .foregroundStyle(.secondary)
                    .rotationEffect(.degrees(choosingMonth ? 180 : 0))
            }
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choosingMonth ? "Godina \(year)" : Self.monthFormatter.string(from: month))
        .accessibilityHint(choosingMonth ? "Vraća na dane" : "Prikazuje mesece za izbor")
    }

    /// Glass, like every other button in the app, so a press is felt: the
    /// glass gives under the finger, and the arrow kicks the way it points.
    private func chevron(_ icon: String, direction: CGFloat, enabled: Bool) -> some View {
        let kicks = direction < 0 ? backKicks : forwardKicks
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
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .disabled(!enabled)
    }

    private var canGoBack: Bool {
        if choosingMonth { return firstYear.map { year > $0 } ?? false }
        return index.months.first.map { month > $0 } ?? false
    }

    private var canGoForward: Bool {
        if choosingMonth { return lastYear.map { year < $0 } ?? false }
        return index.months.last.map { month < $0 } ?? false
    }

    private var firstYear: Int? { index.months.first.map { Calendar.current.component(.year, from: $0) } }
    private var lastYear: Int? { index.months.last.map { Calendar.current.component(.year, from: $0) } }

    /// A month in day mode, a year while choosing a month.
    private func step(_ delta: Int) {
        forward = delta > 0
        if choosingMonth {
            withAnimation(.smooth(duration: 0.32)) { year += delta }
            return
        }
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        withAnimation(.smooth(duration: 0.32)) { month = next }
    }

    private func toggleMonthChoice() {
        // Opens on the year of the month on show, whatever year was last
        // browsed to.
        if !choosingMonth { year = Calendar.current.component(.year, from: month) }
        withAnimation(.smooth(duration: 0.3)) { choosingMonth.toggle() }
    }

    private static let modeTransition = AnyTransition.opacity
        .combined(with: .scale(scale: 0.96, anchor: .top))

    // MARK: - Months

    /// The year's twelve months, three to a row. A dot under each says how
    /// much went on receipts that month, darker the more — the same reading
    /// as the days, a level up. Months with no page on Home are dimmed.
    private var monthGrid: some View {
        let calendar = Calendar.current
        let available = Set(index.months)
        let months = (1...12).compactMap { calendar.date(from: DateComponents(year: year, month: $0)) }
        let totals = months.map { available.contains($0) ? receiptsTotal(in: $0) : 0 }
        let peak = totals.max() ?? 0

        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 3), spacing: 8) {
            ForEach(Array(months.enumerated()), id: \.offset) { offset, candidate in
                monthCell(candidate, spent: totals[offset], peak: peak, enabled: available.contains(candidate))
            }
        }
    }

    private func monthCell(_ candidate: Date, spent: Double, peak: Double, enabled: Bool) -> some View {
        let calendar = Calendar.current
        let isShown = calendar.isDate(candidate, equalTo: month, toGranularity: .month)
        let isNow = calendar.isDate(candidate, equalTo: Date(), toGranularity: .month)

        return Button {
            forward = candidate > month
            withAnimation(.smooth(duration: 0.3)) {
                month = candidate
                choosingMonth = false
            }
        } label: {
            VStack(spacing: 4) {
                Text(Self.shortMonthFormatter.string(from: candidate)
                        .replacingOccurrences(of: ".", with: "").sentenceCased)
                    .font(.system(.subheadline, design: .monospaced, weight: isNow ? .semibold : .regular))
                    .foregroundStyle(isShown ? AnyShapeStyle(Color(uiColor: .systemBackground))
                                     : enabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.quaternary))
                Circle()
                    .fill(isShown ? Color(uiColor: .systemBackground) : Color.primary)
                    .frame(width: 4, height: 4)
                    .opacity(spent > 0 && peak > 0 ? 0.3 + 0.7 * (spent / peak) : 0)
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
        .accessibilityLabel(Self.monthFormatter.string(from: candidate))
        .accessibilityValue(spent > 0 ? "\(MoneyFormat.grouped(Decimal(spent))) dinara" : "bez potrošnje")
    }

    /// Receipts only, as the day dots are — fixed costs land on every month
    /// alike and would darken them all the same.
    private func receiptsTotal(in month: Date) -> Double {
        let total = index.figures(for: month).dailyTotals.reduce(Decimal(0), +)
        return (total as NSDecimalNumber).doubleValue
    }

    // MARK: - Grid

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
                Circle()
                    .fill(isFocused ? Color(uiColor: .systemBackground) : Color.primary)
                    .frame(width: 4, height: 4)
                    .opacity(spent > 0 && peak > 0 ? 0.3 + 0.7 * (spent / peak) : 0)
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

    /// "avg" — the month on its own, for the month grid.
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

/// A day or a month under the finger: a soft disc (a capsule, for months)
/// comes up behind it and the cell gives a little, so the press shows before
/// anything happens on release.
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
