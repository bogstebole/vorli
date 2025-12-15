//
//  ReceiptParser.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import Foundation

/// Parses Serbian fiscal receipt HTML from suf.purs.gov.rs
struct ReceiptParser {
    
    enum ParserError: LocalizedError {
        case invalidURL
        case networkError(Error)
        case parsingError(String)
        case invalidReceiptFormat
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "Invalid receipt URL"
            case .networkError(let error):
                return "Network error: \(error.localizedDescription)"
            case .parsingError(let message):
                return "Parsing error: \(message)"
            case .invalidReceiptFormat:
                return "Invalid receipt format"
            }
        }
    }
    
    /// Fetches and parses a receipt from the given URL
    static func parseReceipt(from urlString: String) async throws -> ParsedReceipt {
        // Validate URL
        guard urlString.contains("suf.purs.gov.rs") else {
            throw ParserError.invalidURL
        }
        
        guard let url = URL(string: urlString) else {
            throw ParserError.invalidURL
        }
        
        // Fetch HTML
        let (data, _) = try await URLSession.shared.data(from: url)
        
        guard let html = String(data: data, encoding: .utf8) else {
            throw ParserError.parsingError("Could not decode HTML")
        }
        
        // Parse the HTML
        return try parseHTML(html, url: urlString)
    }
    
    /// Parses the HTML content of a Serbian fiscal receipt
    private static func parseHTML(_ html: String, url: String) throws -> ParsedReceipt {
        // The receipt is in a <pre> tag with monospace font
        guard let preContent = extractPreContent(from: html) else {
            throw ParserError.invalidReceiptFormat
        }
        
        let lines = preContent.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Parse components
        let merchantInfo = try parseMerchantInfo(from: lines)
        let items = try parseLineItems(from: lines)
        let totals = try parseTotals(from: lines)
        let timestamp = try parseTimestamp(from: lines)
        let receiptNumber = try parseReceiptNumber(from: lines)
        let cashRegister = parseCashRegister(from: lines)
        
        return ParsedReceipt(
            url: url,
            merchantName: merchantInfo.name,
            merchantAddress: merchantInfo.address,
            merchantCity: merchantInfo.city,
            timestamp: timestamp,
            totalAmount: totals.total,
            totalTax: totals.tax,
            paymentMethod: totals.paymentMethod,
            receiptNumber: receiptNumber,
            cashRegisterNumber: cashRegister,
            items: items
        )
    }
    
    /// Extracts content from <pre> tag
    private static func extractPreContent(from html: String) -> String? {
        guard let startRange = html.range(of: "<pre"),
              let endRange = html.range(of: "</pre>") else {
            return nil
        }
        
        let preContent = html[startRange.upperBound..<endRange.lowerBound]
        
        // Remove style attributes and tags
        let withoutTags = preContent.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        return String(withoutTags)
    }
    
    /// Parses merchant information
    private static func parseMerchantInfo(from lines: [String]) throws -> (name: String, address: String, city: String) {
        // Merchant info is typically near the top after the header
        // Format:
        // ============ ФИСКАЛНИ РАЧУН ============
        // [ID number]
        // [Merchant Name]
        // [Store ID]
        // [Address]
        // [City]
        
        var name = ""
        var address = ""
        var city = ""
        
        for (index, line) in lines.enumerated() {
            // Skip header lines
            if line.contains("ФИСКАЛНИ РАЧУН") || line.contains("===") || line.contains("---") {
                continue
            }
            
            // Look for typical patterns
            if line.count >= 8 && !line.contains(":") && !line.contains("Касир") && !name.isEmpty == false {
                // First substantial line after header is usually merchant name
                if name.isEmpty && !line.allSatisfy({ $0.isNumber || $0 == "-" }) {
                    name = line
                } else if address.isEmpty && !line.contains("Београд") && !line.contains("Нови Сад") {
                    address = line
                } else if city.isEmpty && (line.contains("Београд") || line.contains("Нови Сад") || line.contains("-")) {
                    city = line
                    break
                }
            }
        }
        
        // Fallback: look for specific patterns
        if name.isEmpty {
            for line in lines {
                if line.uppercased() == line && line.count > 5 && !line.contains("РАЧУН") && !line.allSatisfy({ !$0.isLetter }) {
                    name = line
                    break
                }
            }
        }
        
        return (name: name, address: address, city: city)
    }
    
    /// Parses line items from the receipt
    private static func parseLineItems(from lines: [String]) throws -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        var isInItemSection = false
        var currentItemName = ""
        
        for line in lines {
            // Start of items section
            if line.contains("Артикли") || line.contains("Назив") {
                isInItemSection = true
                continue
            }
            
            // End of items section
            if line.contains("Укупан износ:") || line.contains("====") && isInItemSection && !items.isEmpty {
                break
            }
            
            if isInItemSection && !line.contains("===") && !line.contains("---") && !line.contains("Назив") {
                // Check if this line contains price and quantity data
                // Format: "       620,00          1          620,00"
                let components = line.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                
                // If line has 3+ numbers, it's likely the price/quantity/total line
                let numberComponents = components.filter { isNumericString($0) }
                
                if numberComponents.count >= 3 {
                    // This is the data line for the current item
                    if !currentItemName.isEmpty {
                        if let unitPrice = parseDecimal(from: numberComponents[0]),
                           let quantity = parseDouble(from: numberComponents[1]),
                           let lineTotal = parseDecimal(from: numberComponents[2]) {
                            
                            let item = ParsedReceiptItem(
                                name: currentItemName,
                                quantity: quantity,
                                unitPrice: unitPrice,
                                lineTotal: lineTotal
                            )
                            items.append(item)
                            currentItemName = ""
                        }
                    }
                } else if !line.isEmpty {
                    // This is the item name line
                    currentItemName = line
                }
            }
        }
        
        return items
    }
    
    /// Parses total amount and tax
    private static func parseTotals(from lines: [String]) throws -> (total: Decimal, tax: Decimal, paymentMethod: String) {
        var total: Decimal = 0
        var tax: Decimal = 0
        var paymentMethod = "Неодређено"
        
        for line in lines {
            // Total amount: "Укупан износ:                   2.880,00"
            if line.contains("Укупан износ:") && !line.contains("пореза") {
                let components = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if let amount = parseDecimal(from: components) {
                    total = amount
                }
            }
            
            // Tax: "Укупан износ пореза:              480,00"
            if line.contains("Укупан износ пореза:") {
                let components = line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
                if let amount = parseDecimal(from: components) {
                    tax = amount
                }
            }
            
            // Payment method
            if line.contains("безготовинско") {
                paymentMethod = "Безготовинско плаћање"
            } else if line.contains("Готовина") {
                paymentMethod = "Готовина"
            }
        }
        
        return (total: total, tax: tax, paymentMethod: paymentMethod)
    }
    
    /// Parses timestamp from receipt
    private static func parseTimestamp(from lines: [String]) throws -> Date {
        // Format: "ПФР време:          12.12.2025. 15:57:02"
        for line in lines {
            if line.contains("ПФР време:") {
                let dateString = line.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                
                // Parse Serbian date format: DD.MM.YYYY. HH:mm:ss
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
                formatter.locale = Locale(identifier: "sr_RS")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
        }
        
        throw ParserError.parsingError("Could not parse timestamp")
    }
    
    /// Parses receipt number
    private static func parseReceiptNumber(from lines: [String]) throws -> String {
        // Format: "ПФР број рачуна: S8SMA9VT-C38FDVO0-36894"
        for line in lines {
            if line.contains("ПФР број рачуна:") {
                return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
            }
        }
        return ""
    }
    
    /// Parses cash register number (ESIR)
    private static func parseCashRegister(from lines: [String]) -> String {
        // Format: "ЕСИР број:                    1099/1.0.0"
        for line in lines {
            if line.contains("ЕСИР број:") {
                return line.components(separatedBy: ":").last?.trimmingCharacters(in: .whitespaces) ?? ""
            }
        }
        return ""
    }
    
    // MARK: - Helper Functions
    
    /// Checks if a string represents a number (with Serbian decimal format)
    private static func isNumericString(_ string: String) -> Bool {
        let cleaned = string.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
        return Double(cleaned) != nil
    }
    
    /// Parses a Decimal from Serbian number format (1.234,56)
    private static func parseDecimal(from string: String) -> Decimal? {
        // Serbian format uses . for thousands and , for decimal
        let cleaned = string
            .replacingOccurrences(of: ".", with: "") // Remove thousands separator
            .replacingOccurrences(of: ",", with: ".") // Replace decimal separator
            .trimmingCharacters(in: .whitespaces)
        
        return Decimal(string: cleaned)
    }
    
    /// Parses a Double from Serbian number format
    private static func parseDouble(from string: String) -> Double? {
        let cleaned = string
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        
        return Double(cleaned)
    }
}

// MARK: - Parsed Models

struct ParsedReceipt {
    let url: String
    let merchantName: String
    let merchantAddress: String
    let merchantCity: String
    let timestamp: Date
    let totalAmount: Decimal
    let totalTax: Decimal
    let paymentMethod: String
    let receiptNumber: String
    let cashRegisterNumber: String
    let items: [ParsedReceiptItem]
}

struct ParsedReceiptItem {
    let name: String
    let quantity: Double
    let unitPrice: Decimal
    let lineTotal: Decimal
}
