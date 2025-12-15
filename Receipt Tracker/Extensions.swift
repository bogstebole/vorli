//
//  Extensions.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import Foundation

// MARK: - Decimal Extensions

extension Decimal {
    /// Formats the decimal as Serbian currency (RSD)
    var asRSD: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "RSD"
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: self as NSDecimalNumber) ?? "0 RSD"
    }
    
    /// Formats the decimal with Serbian number format (1.234,56)
    var asSerbianNumber: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.locale = Locale(identifier: "sr_RS")
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2
        return formatter.string(from: self as NSDecimalNumber) ?? "0,00"
    }
}

// MARK: - String Extensions

extension String {
    /// Checks if string is a valid Serbian fiscal URL
    var isSerbianFiscalURL: Bool {
        self.contains("suf.purs.gov.rs") && self.hasPrefix("http")
    }
    
    /// Cleans the string from extra whitespace and newlines
    var cleaned: String {
        self.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
    }
}

// MARK: - Date Extensions

extension Date {
    /// Formats date in Serbian locale
    var asSerbianDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: self)
    }
    
    /// Formats date and time in Serbian locale
    var asSerbianDateTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: "sr_RS")
        return formatter.string(from: self)
    }
}
