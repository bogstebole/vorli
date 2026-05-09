//
//  MonthlyIncomeScheduler.swift
//  Receipt Tracker
//

import Foundation

enum MonthlyIncomeScheduler {
    private static let lastAddedKey = "monthlyIncomeLastAddedMonth"
    private static let amountKey = "monthlyIncomeAmount"
    private static let autoAddKey = "monthlyIncomeAutoAdd"

    static func recordAutoAdd() {
        let month = currentMonthIdentifier()
        UserDefaults.standard.set(month, forKey: lastAddedKey)
    }

    static func shouldAutoAdd() -> Decimal? {
        guard UserDefaults.standard.bool(forKey: autoAddKey) else { return nil }
        guard let amountString = UserDefaults.standard.string(forKey: amountKey),
              !amountString.isEmpty,
              let amount = Decimal(string: amountString.replacingOccurrences(of: ",", with: ".")),
              amount > 0 else { return nil }

        let lastAdded = UserDefaults.standard.string(forKey: lastAddedKey) ?? ""
        guard lastAdded != currentMonthIdentifier() else { return nil }

        return amount
    }

    private static func currentMonthIdentifier() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: Date())
    }
}
