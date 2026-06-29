//
//  MoneyFormat.swift
//  Receipt Tracker
//
//  Grouped-thousands formatting for whole-RSD amounts.
//

import Foundation

enum MoneyFormat {
    /// Whole-number digit string for a Decimal, e.g. 40000 → "40000".
    static func digits(_ value: Decimal) -> String {
        String(NSDecimalNumber(decimal: value).int64Value)
    }

    /// Groups a digit string with "." separators, e.g. "40000" → "40.000". Empty in → "".
    static func grouped(_ digits: String) -> String {
        let onlyDigits = digits.filter(\.isNumber)
        guard !onlyDigits.isEmpty else { return "" }
        let reversed = Array(onlyDigits.reversed())
        var groups: [String] = []
        var chunk = ""
        for (i, char) in reversed.enumerated() {
            chunk.append(char)
            if (i + 1) % 3 == 0 && i + 1 < reversed.count {
                groups.append(String(chunk.reversed()))
                chunk = ""
            }
        }
        if !chunk.isEmpty { groups.append(String(chunk.reversed())) }
        return groups.reversed().joined(separator: ".")
    }

    /// Grouped string for a Decimal, e.g. 40000 → "40.000".
    static func grouped(_ value: Decimal) -> String {
        grouped(digits(value))
    }

    /// Grouped string with a leading minus for negatives, e.g. -49814 → "-49.814".
    static func signed(_ value: Decimal) -> String {
        let isNegative = value < 0
        let magnitude = grouped(String(NSDecimalNumber(decimal: value.magnitude).int64Value))
        let body = magnitude.isEmpty ? "0" : magnitude
        return isNegative ? "-" + body : body
    }
}
