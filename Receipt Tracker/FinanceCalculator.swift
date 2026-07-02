//
//  FinanceCalculator.swift
//  Receipt Tracker
//
//  Shared budget math used by the home screen and the wishlist.
//

import Foundation

enum FinanceCalculator {
    static let incomeNote = "mesecna_zarada"

    static func incomeTotal(_ entries: [BudgetEntry], in month: Date, calendar: Calendar = .current) -> Decimal {
        entries
            .filter { $0.note == incomeNote && calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + $1.amount }
    }

    static func receiptsTotal(_ receipts: [Receipt], in month: Date, calendar: Calendar = .current) -> Decimal {
        receipts
            .filter { calendar.isDate($0.timestamp, equalTo: month, toGranularity: .month) }
            .reduce(Decimal(0)) { $0 + $1.totalAmount }
    }

    static func activeFixedTotal(_ fixed: [FixedCost]) -> Decimal {
        fixed.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.iznos }
    }

    /// Leftover for a month = income − receipts − active fixed costs.
    static func leftover(month: Date, receipts: [Receipt], entries: [BudgetEntry], fixed: [FixedCost], calendar: Calendar = .current) -> Decimal {
        incomeTotal(entries, in: month, calendar: calendar)
            - receiptsTotal(receipts, in: month, calendar: calendar)
            - activeFixedTotal(fixed)
    }

    /// Months (as dates) that had any income or receipt activity, newest first.
    private static func activityMonths(receipts: [Receipt], entries: [BudgetEntry], calendar: Calendar) -> [Date] {
        var anchors = Set<DateComponents>()
        for r in receipts {
            anchors.insert(calendar.dateComponents([.year, .month], from: r.timestamp))
        }
        for e in entries where e.note == incomeNote {
            anchors.insert(calendar.dateComponents([.year, .month], from: e.timestamp))
        }
        return anchors
            .compactMap { calendar.date(from: $0) }
            .sorted(by: >)
    }

    /// Average monthly leftover across the most recent months that had income or receipts.
    static func averageMonthlyLeftover(receipts: [Receipt], entries: [BudgetEntry], fixed: [FixedCost], maxMonths: Int = 6, calendar: Calendar = .current) -> Decimal {
        let monthDates = activityMonths(receipts: receipts, entries: entries, calendar: calendar)
            .prefix(maxMonths)
        guard !monthDates.isEmpty else { return 0 }
        let total = monthDates.reduce(Decimal(0)) {
            $0 + leftover(month: $1, receipts: receipts, entries: entries, fixed: fixed, calendar: calendar)
        }
        return total / Decimal(monthDates.count)
    }

    /// Cumulative savings: the sum of leftovers across ALL months with activity.
    /// This is what wish reservations are drawn from — a wish is funded over
    /// many months, so comparing it against a single month's leftover would
    /// go negative as soon as reservations outgrow one month's surplus.
    ///
    /// A month that ended with nothing left over contributes 0, never a minus:
    /// you can't "un-save" money, and months with receipts but no recorded
    /// income would otherwise show up as debt that doesn't exist.
    static func totalLeftover(receipts: [Receipt], entries: [BudgetEntry], fixed: [FixedCost], calendar: Calendar = .current) -> Decimal {
        activityMonths(receipts: receipts, entries: entries, calendar: calendar)
            .reduce(Decimal(0)) {
                $0 + max(0, leftover(month: $1, receipts: receipts, entries: entries, fixed: fixed, calendar: calendar))
            }
    }

    /// Total amount the user has set aside across active wishes.
    static func totalReserved(_ wishes: [Wish]) -> Decimal {
        wishes.filter { !$0.isArchived }.reduce(Decimal(0)) { $0 + $1.usteceno }
    }
}
