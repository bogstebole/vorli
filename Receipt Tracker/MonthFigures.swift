//
//  MonthFigures.swift
//  Receipt Tracker
//
//  Everything Home shows for a month, worked out for every month in a single
//  pass over the receipts.
//
//  Home used to filter the whole receipt list once per month page, and it did
//  so on every frame of a swipe. The pager keeps about six pages built, so one
//  frame read every receipt out of SwiftData six times over; with 720 receipts
//  that alone cost around 7 ms a frame — most of a 120 Hz frame's 8.3 ms before
//  anything had been drawn. Grouping once turns each page into a lookup.
//

import Foundation

/// The figures one month page shows.
struct MonthFigures: Equatable {
    /// Receipts plus the month's fixed costs.
    var spent: Decimal
    /// Everything added to the budget that month.
    var income: Decimal
    /// Today's receipts. Zero for any month but the current one.
    var spentToday: Decimal
    /// Receipts per calendar day, index 0 = the 1st.
    var dailyTotals: [Decimal]
    var receiptCount: Int
}

/// The months Home can page through, and what each of them shows.
struct MonthIndex {
    /// Oldest month on record through the current one, ascending, each the
    /// first instant of its month — the same values `startOfMonth` produces, so
    /// they line up with the pager's scroll position and `AppNavigation`.
    let months: [Date]
    private let figuresByMonth: [Date: MonthFigures]
    private let fixedCosts: Decimal
    private let calendar: Calendar

    /// A long-dead timestamp shouldn't turn the pager into fifty years of
    /// empty pages. The newest months are the ones that matter, so the range
    /// is cut from the old end.
    private static let maxMonths = 600

    init(
        receipts: [Receipt],
        budgetEntries: [BudgetEntry],
        fixedCosts: Decimal,
        including selectedMonth: Date,
        now: Date = Date(),
        calendar: Calendar = .current
    ) {
        self.fixedCosts = fixedCosts
        self.calendar = calendar

        /// Months as plain integers: cheap to hash, compare and step through.
        func key(_ year: Int, _ month: Int) -> Int { year * 12 + (month - 1) }

        let nowParts = calendar.dateComponents([.year, .month, .day], from: now)
        let thisMonth = key(nowParts.year ?? 0, nowParts.month ?? 1)
        let today = nowParts.day ?? 0

        var tallies: [Int: Tally] = [:]
        var earliest: Int?

        for receipt in receipts {
            let parts = calendar.dateComponents([.year, .month, .day], from: receipt.timestamp)
            guard let year = parts.year, let month = parts.month, let day = parts.day else { continue }
            let k = key(year, month)
            // `default:` mutates the stored tally in place; copying it out and
            // back would duplicate its 31-day array for every receipt.
            tallies[k, default: Tally()].add(
                receipt.totalAmount,
                on: day,
                isToday: k == thisMonth && day == today
            )
            earliest = min(earliest ?? k, k)
        }

        for entry in budgetEntries {
            let parts = calendar.dateComponents([.year, .month], from: entry.timestamp)
            guard let year = parts.year, let month = parts.month else { continue }
            let k = key(year, month)
            tallies[k, default: Tally()].income += entry.amount
            earliest = min(earliest ?? k, k)
        }

        var keys: [Int]
        if let earliest {
            keys = earliest <= thisMonth
                ? Array(max(earliest, thisMonth - Self.maxMonths + 1)...thisMonth)
                : []
            // A month the user navigated to but has no data for still needs a page.
            let selected = calendar.dateComponents([.year, .month], from: selectedMonth)
            if let year = selected.year, let month = selected.month {
                let k = key(year, month)
                if !keys.contains(k) {
                    keys.append(k)
                    keys.sort()
                }
            }
        } else {
            keys = [thisMonth]
        }

        var months: [Date] = []
        var figures: [Date: MonthFigures] = [:]
        months.reserveCapacity(keys.count)
        for k in keys {
            guard let start = calendar.date(from: DateComponents(year: k / 12, month: k % 12 + 1)) else { continue }
            let days = calendar.range(of: .day, in: .month, for: start)?.count ?? 30
            let tally = tallies[k] ?? Tally()
            figures[start] = MonthFigures(
                spent: tally.spent + fixedCosts,
                income: tally.income,
                spentToday: tally.today,
                dailyTotals: Array(tally.daily.prefix(days)),
                receiptCount: tally.count
            )
            months.append(start)
        }
        self.months = months
        self.figuresByMonth = figures
    }

    /// Always answers: a month outside the range gets an empty page rather than
    /// a crash.
    func figures(for month: Date) -> MonthFigures {
        if let figures = figuresByMonth[month] { return figures }
        let days = calendar.range(of: .day, in: .month, for: month)?.count ?? 30
        return MonthFigures(spent: fixedCosts, income: 0, spentToday: 0,
                            dailyTotals: Array(repeating: 0, count: days), receiptCount: 0)
    }

    private struct Tally {
        var spent: Decimal = 0
        var today: Decimal = 0
        var income: Decimal = 0
        var count = 0
        var daily = [Decimal](repeating: 0, count: 31)

        mutating func add(_ amount: Decimal, on day: Int, isToday: Bool) {
            spent += amount
            count += 1
            if (1...31).contains(day) { daily[day - 1] += amount }
            if isToday { today += amount }
        }
    }
}
