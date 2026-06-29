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

    /// Average monthly leftover across the most recent months that had income or receipts.
    static func averageMonthlyLeftover(receipts: [Receipt], entries: [BudgetEntry], fixed: [FixedCost], maxMonths: Int = 6, calendar: Calendar = .current) -> Decimal {
        var anchors = Set<DateComponents>()
        for r in receipts {
            anchors.insert(calendar.dateComponents([.year, .month], from: r.timestamp))
        }
        for e in entries where e.note == incomeNote {
            anchors.insert(calendar.dateComponents([.year, .month], from: e.timestamp))
        }
        let monthDates = anchors
            .compactMap { calendar.date(from: $0) }
            .sorted(by: >)
            .prefix(maxMonths)
        guard !monthDates.isEmpty else { return 0 }
        let total = monthDates.reduce(Decimal(0)) {
            $0 + leftover(month: $1, receipts: receipts, entries: entries, fixed: fixed, calendar: calendar)
        }
        return total / Decimal(monthDates.count)
    }

    /// Total amount the user has set aside across active wishes.
    static func totalReserved(_ wishes: [Wish]) -> Decimal {
        wishes.filter { !$0.isArchived }.reduce(Decimal(0)) { $0 + $1.usteceno }
    }
}
