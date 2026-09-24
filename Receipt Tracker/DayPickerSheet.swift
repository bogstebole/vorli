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

    init(index: MonthIndex, initialMonth: Date, focusedDay: Date?, onSelect: @escaping (Date) -> Void) {
        self.index = index
        self.focusedDay = focusedDay
        self.onSelect = onSelect
        _month = State(initialValue: initialMonth)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 14) {
                monthHeader
                weekdayRow
                ZStack {
                    grid
                        .id(month)
                        .transition(.push(from: forward ? .trailing : .leading))
                }
                // Only the days are clipped, so the month slides within the
                // grid. Clipping the whole column also cut the top off the
                // chevrons' glass, which swells past its frame when pressed.
                .clipped()
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 4)
            .navigationTitle("Izaberi dan")
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
    /// month name is centred across the whole row above them.
    private var monthHeader: some View {
        HStack(spacing: 0) {
            chevron("chevron-left", direction: -1, enabled: canGoBack)
                .accessibilityLabel("Prethodni mesec")
                .frame(maxWidth: .infinity)
            ForEach(0..<5, id: \.self) { _ in
                Color.clear.frame(maxWidth: .infinity, maxHeight: 0)
            }
            chevron("chevron-right", direction: 1, enabled: canGoForward)
                .accessibilityLabel("Sledeći mesec")
                .frame(maxWidth: .infinity)
        }
        .overlay {
            Text(Self.monthFormatter.string(from: month).sentenceCased)
                .font(.system(.headline, design: .monospaced))
                .foregroundStyle(.primary)
                // The year rolls the way the month went.
                .contentTransition(.numericText(countsDown: !forward))
        }
        .sensoryFeedback(.selection, trigger: month)
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

    private var canGoBack: Bool { index.months.first.map { month > $0 } ?? false }
    private var canGoForward: Bool { index.months.last.map { month < $0 } ?? false }

    private func step(_ delta: Int) {
        guard let next = Calendar.current.date(byAdding: .month, value: delta, to: month) else { return }
        forward = delta > 0
        withAnimation(.smooth(duration: 0.32)) { month = next }
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
        .buttonStyle(DayCellButtonStyle())
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

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "EEEE, d. MMMM"
        return f
    }()
}

/// A day under the finger: a soft disc comes up behind the number and the
/// cell gives a little, so the press shows before the sheet closes on release.
private struct DayCellButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background {
                Circle()
                    .fill(Color.primary.opacity(configuration.isPressed ? 0.14 : 0))
                    .frame(width: 42, height: 42)
            }
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
