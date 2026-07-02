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

    /// Point-of-sale style display: interprets a digit string as cents and
    /// formats with two decimals, e.g. "66195" → "661,95", "" → "0,00".
    static func centsDisplay(_ digits: String) -> String {
        let d = digits.filter(\.isNumber)
        guard !d.isEmpty, let cents = Decimal(string: d) else { return "0,00" }
        return decimalString(cents / 100)
    }

    /// Serbian-style display with two decimals, e.g. 661.95 → "661,95".
    static func decimalString(_ value: Decimal) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        formatter.groupingSeparator = "."
        formatter.decimalSeparator = ","
        return formatter.string(from: value as NSDecimalNumber) ?? "0,00"
    }

    /// Parses a free-form amount string into a Decimal, tolerant of Serbian
    /// (1.661,95) and English (1,661.95) formats. The last separator is treated
    /// as the decimal point; a lone separator with two trailing digits is decimal.
    static func parse(_ raw: String) -> Decimal? {
        var s = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard s.contains(where: \.isNumber) else { return nil }
        let hasDot = s.contains(".")
        let hasComma = s.contains(",")
        if hasDot && hasComma {
            if s.lastIndex(of: ",")! > s.lastIndex(of: ".")! {
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            let parts = s.split(separator: ",", omittingEmptySubsequences: false)
            s = (parts.count == 2 && parts.last?.count == 2)
                ? s.replacingOccurrences(of: ",", with: ".")
                : s.replacingOccurrences(of: ",", with: "")
        } else if hasDot {
            let parts = s.split(separator: ".", omittingEmptySubsequences: false)
            if !(parts.count == 2 && parts.last?.count == 2) {
                s = s.replacingOccurrences(of: ".", with: "")
            }
        }
        return Decimal(string: s)
    }
}
