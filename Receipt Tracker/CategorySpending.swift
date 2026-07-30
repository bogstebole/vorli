//
//  CategorySpending.swift
//  Receipt Tracker
//
//  Spending grouped by the user's merchant categories. Categories are never
//  auto-assigned, so receipts from merchants the user hasn't labelled land in
//  "Bez kategorije" — shown last, and never hidden, so the totals always add up.
//

import Foundation

enum CategorySpending {
    struct Row: Identifiable {
        var id: String { name }
        let name: String
        let total: Decimal
        /// Share of the period's total, 0...1 — for bars or percentages.
        let fraction: Double
        let isUncategorized: Bool
    }

    /// Totals per category for the given receipts, largest first.
    ///
    /// `fixedCosts` (active recurring costs for the period) becomes its own row
    /// so the rows sum to the same "spent" figure the header shows — otherwise
    /// the total under the list would silently disagree with it.
    static func rows(for receipts: [Receipt], categories: [MerchantCategory], fixedCosts: Decimal = 0) -> [Row] {
        guard !receipts.isEmpty || fixedCosts > 0 else { return [] }

        let categoryByMerchant = Dictionary(
            categories.map { ($0.merchantKey, $0.name) },
            uniquingKeysWith: { first, _ in first }
        )

        var totals: [String: Decimal] = [:]
        var uncategorized: Decimal = 0
        for receipt in receipts {
            let key = PriceHistory.merchantKey(receipt.merchantName)
            if let category = categoryByMerchant[key] {
                totals[category, default: 0] += receipt.totalAmount
            } else {
                uncategorized += receipt.totalAmount
            }
        }

        let grandTotal = totals.values.reduce(uncategorized + fixedCosts, +)
        let grandTotalD = (grandTotal as NSDecimalNumber).doubleValue
        guard grandTotalD > 0 else { return [] }

        func fraction(_ value: Decimal) -> Double {
            (value as NSDecimalNumber).doubleValue / grandTotalD
        }

        var rows = totals
            .map { Row(name: $0.key, total: $0.value, fraction: fraction($0.value), isUncategorized: false) }

        if fixedCosts > 0 {
            rows.append(Row(name: "Fiksni troškovi", total: fixedCosts,
                            fraction: fraction(fixedCosts), isUncategorized: false))
        }
        rows.sort { $0.total > $1.total }

        // Always last: it's the leftover bucket, not a real category.
        if uncategorized > 0 {
            rows.append(Row(name: "Bez kategorije", total: uncategorized,
                            fraction: fraction(uncategorized), isUncategorized: true))
        }
        return rows
    }
}
