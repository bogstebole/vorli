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
    
    /// Decodes HTML entities in a string (e.g., &#39; -> ')
    func decodingHTMLEntities() -> String {
        var result = self
        
        // Dictionary of common HTML numeric entities
        let numericEntities: [String: String] = [
            "&#34;": "\"",   // quotation mark
            "&#38;": "&",    // ampersand
            "&#39;": "'",    // apostrophe
            "&#60;": "<",    // less-than
            "&#62;": ">",    // greater-than
            "&#91;": "[",    // left bracket
            "&#93;": "]",    // right bracket
            "&#123;": "{",   // left brace
            "&#125;": "}",   // right brace
            "&#40;": "(",    // left parenthesis
            "&#41;": ")",    // right parenthesis
            "&#47;": "/",    // forward slash
            "&#92;": "\\",   // backslash
            "&#64;": "@",    // at sign
            "&#35;": "#",    // number sign
            "&#36;": "$",    // dollar sign
            "&#37;": "%",    // percent sign
            "&#94;": "^",    // caret
            "&#42;": "*",    // asterisk
            "&#43;": "+",    // plus sign
            "&#61;": "=",    // equals sign
            "&#126;": "~",   // tilde
            "&#96;": "`",    // backtick
            "&#124;": "|",   // pipe
            "&#58;": ":",    // colon
            "&#59;": ";",    // semicolon
            "&#44;": ",",    // comma
            "&#46;": ".",    // period
            "&#63;": "?",    // question mark
            "&#33;": "!",    // exclamation mark
        ]
        
        // Replace all numeric entities
        for (entity, character) in numericEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        
        // Dictionary of common HTML named entities
        let namedEntities: [String: String] = [
            "&quot;": "\"",
            "&amp;": "&",
            "&apos;": "'",
            "&lt;": "<",
            "&gt;": ">",
            "&nbsp;": " ",
        ]
        
        // Replace all named entities
        for (entity, character) in namedEntities {
            result = result.replacingOccurrences(of: entity, with: character)
        }
        
        // Use regex to catch any remaining numeric entities (&#xxx; or &#xHH;)
        let decimalPattern = "&#(\\d+);"
        if let regex = try? NSRegularExpression(pattern: decimalPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            // Process in reverse to maintain correct indices
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let numberRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[numberRange]),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        
        // Handle hexadecimal entities (&#xHH;)
        let hexPattern = "&#x([0-9A-Fa-f]+);"
        if let regex = try? NSRegularExpression(pattern: hexPattern) {
            let matches = regex.matches(in: result, range: NSRange(result.startIndex..., in: result))
            // Process in reverse to maintain correct indices
            for match in matches.reversed() {
                if let fullRange = Range(match.range, in: result),
                   let hexRange = Range(match.range(at: 1), in: result),
                   let code = Int(result[hexRange], radix: 16),
                   let scalar = UnicodeScalar(code) {
                    result.replaceSubrange(fullRange, with: String(scalar))
                }
            }
        }
        
        return result
    }
}

// MARK: - Date Extensions

extension Date {
    var startOfMonth: Date {
        Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: self)) ?? self
    }

    var monthYearString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        return formatter.string(from: self)
    }

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
