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
        
        // DON'T trim lines - we need the indentation to parse correctly!
        let lines = preContent.components(separatedBy: .newlines)
        
        // Create trimmed version for metadata parsing
        let trimmedLines = lines.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        // Parse components
        let merchantInfo = try parseMerchantInfo(from: trimmedLines)
        let items = try parseLineItems(from: lines) // Use original lines with indentation!
        let totals = try parseTotals(from: trimmedLines)
        let timestamp = try parseTimestamp(from: trimmedLines)
        let receiptNumber = try parseReceiptNumber(from: trimmedLines)
        let cashRegister = parseCashRegister(from: trimmedLines)
        
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
        
        for line in lines {
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
        
        // Find the start of items section (after "Артикли")
        guard let itemsStartIndex = lines.firstIndex(where: { $0.contains("Артикли") }) else {
            print("Debug: Could not find 'Артикли' marker")
            throw ParserError.parsingError("Could not find items section")
        }
        
        // Find the end of items section (before "Укупан износ:")
        guard let itemsEndIndex = lines.firstIndex(where: { $0.contains("Укупан износ:") }) else {
            print("Debug: Could not find 'Укупан износ:' marker")
            throw ParserError.parsingError("Could not find end of items section")
        }
        
        print("Debug: Items section from line \(itemsStartIndex) to \(itemsEndIndex)")
        
        var i = itemsStartIndex + 1
        
        // Skip header lines (separator and column headers)
        while i < itemsEndIndex {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            if line.contains("===") || 
               line.contains("---") || 
               line.contains("Назив") ||
               line.contains("Цена") ||
               line.contains("Кол.") ||
               line.contains("Укупно") {
                i += 1
            } else {
                break
            }
        }
        
        // Parse items: Each item consists of 2-3 lines:
        // Line 1: Item name (may start with optional 7-digit SKU)
        // Line 2: Name continuation (optional - only if next line is NOT indented and NOT a price line)
        // Line 3: Price line (ALWAYS indented with spaces at the start)
        while i < itemsEndIndex {
            let line = lines[i]
            let lineTrimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Skip separator, empty lines, or header lines
            if lineTrimmed.contains("---") || 
               lineTrimmed.contains("===") || 
               lineTrimmed.isEmpty ||
               lineTrimmed.contains("Назив") ||
               lineTrimmed.contains("Цена") ||
               lineTrimmed.contains("Кол.") ||
               lineTrimmed.contains("Укупно") {
                i += 1
                continue
            }
            
            // Check if this line is NOT indented (potential item name or SKU)
            // Item names start at the left (no leading spaces)
            if !line.hasPrefix(" ") && !line.hasPrefix("\t") && !lineTrimmed.isEmpty {
                print("Debug: Found potential item at line \(i): '\(lineTrimmed)'")
                
                // Build the full name
                var nameParts: [String] = []
                
                // Check if this line is ONLY a SKU (7 digits only)
                let isOnlySKU = lineTrimmed.range(of: "^[0-9]{7}$", options: .regularExpression) != nil
                
                if isOnlySKU {
                    // SKU is on its own line - the actual name is on the NEXT line
                    print("Debug: Line \(i) is SKU-only, name should be on next line")
                    i += 1
                    
                    // Now collect the actual item name from subsequent lines
                    while i < itemsEndIndex {
                        let nextLine = lines[i]
                        let nextLineTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                        
                        // Skip empty lines
                        if nextLineTrimmed.isEmpty {
                            i += 1
                            continue
                        }
                        
                        // Check if this is a price line (indented + contains price pattern)
                        let isIndented = nextLine.hasPrefix(" ") || nextLine.hasPrefix("\t")
                        let hasPricePattern = nextLineTrimmed.range(of: "[0-9]+(?:\\.[0-9]{3})*,[0-9]{2}", options: .regularExpression) != nil
                        
                        if isIndented && hasPricePattern {
                            // This is the price line - we're done collecting name
                            print("Debug: Found price line at \(i)")
                            break
                        }
                        
                        // Check if this looks like a new item (starts with 7-digit SKU)
                        let startsWithSKU = nextLineTrimmed.range(of: "^[0-9]{7}", options: .regularExpression) != nil
                        
                        if startsWithSKU && !isIndented {
                            // This is a new item - stop collecting name parts
                            print("Debug: Found new item with SKU at \(i)")
                            break
                        }
                        
                        // This is part of the item name if:
                        // 1. Not indented
                        // 2. Doesn't look like a standalone price line
                        // 3. Contains some text content
                        let looksLikeNamePart = !isIndented && 
                                                nextLineTrimmed.count <= 50 && 
                                                !nextLineTrimmed.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." || $0.isWhitespace })
                        
                        if looksLikeNamePart {
                            nameParts.append(nextLineTrimmed)
                            print("Debug: Added name part: '\(nextLineTrimmed)'")
                            i += 1
                        } else {
                            // Unknown line type, stop
                            print("Debug: Stopping name collection at line \(i): '\(nextLineTrimmed)'")
                            break
                        }
                    }
                } else {
                    // No SKU, or SKU + name on same line
                    var itemName = lineTrimmed
                    
                    // Try to extract SKU if present (7-digit number at start)
                    let skuPattern = "^([0-9]{7})\\s+"
                    if let skuRegex = try? NSRegularExpression(pattern: skuPattern),
                       let match = skuRegex.firstMatch(in: lineTrimmed, range: NSRange(lineTrimmed.startIndex..., in: lineTrimmed)),
                       let range = Range(match.range(at: 1), in: lineTrimmed),
                       let fullMatchRange = Range(match.range(at: 0), in: lineTrimmed) {
                        // Remove SKU from name (but keep the rest)
                        let sku = String(lineTrimmed[range])
                        itemName = String(lineTrimmed[fullMatchRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                        print("Debug: Found SKU: \(sku), Name after SKU: '\(itemName)'")
                    }
                    
                    // Add first line of name
                    if !itemName.isEmpty {
                        nameParts.append(itemName)
                    }
                    
                    i += 1
                    
                    // Check next lines for name continuation
                    // Continue collecting lines until we hit:
                    // 1. An indented line (price line)
                    // 2. An empty line followed by indented line
                    // 3. A new item (starts with SKU)
                    while i < itemsEndIndex {
                        let nextLine = lines[i]
                        let nextLineTrimmed = nextLine.trimmingCharacters(in: .whitespaces)
                        
                        // Skip empty lines
                        if nextLineTrimmed.isEmpty {
                            i += 1
                            continue
                        }
                        
                        // Check if this is a price line (indented + contains price pattern)
                        let isIndented = nextLine.hasPrefix(" ") || nextLine.hasPrefix("\t")
                        let hasPricePattern = nextLineTrimmed.range(of: "[0-9]+(?:\\.[0-9]{3})*,[0-9]{2}", options: .regularExpression) != nil
                        
                        if isIndented && hasPricePattern {
                            // This is the price line - stop collecting name parts
                            print("Debug: Found price line at \(i)")
                            break
                        }
                        
                        // Check if this looks like a new item (optional: starts with 7-digit SKU)
                        let startsWithSKU = nextLineTrimmed.range(of: "^[0-9]{7}", options: .regularExpression) != nil
                        
                        if startsWithSKU && !isIndented {
                            // This is a new item - stop collecting name parts
                            print("Debug: Found new item with SKU at \(i)")
                            break
                        }
                        
                        // Check if this line is TOO SHORT to be a valid name continuation
                        // Lines like "(Ђ)" or ")" are probably artifacts, not real content
                        // But we still want to collect them as they complete words like "re-cikl" or measurements
                        
                        // This is a name continuation line if:
                        // 1. Not indented
                        // 2. Doesn't look like a standalone price line
                        // 3. Contains some text content (letters, parentheses, slashes, etc.)
                        let looksLikeNamePart = !isIndented && 
                                                nextLineTrimmed.count <= 50 && // Reasonable line length
                                                !nextLineTrimmed.allSatisfy({ $0.isNumber || $0 == "," || $0 == "." || $0.isWhitespace })
                        
                        if looksLikeNamePart {
                            nameParts.append(nextLineTrimmed)
                            print("Debug: Added name continuation: '\(nextLineTrimmed)'")
                            i += 1
                        } else {
                            // Unknown line type, stop
                            print("Debug: Stopping name collection at line \(i): '\(nextLineTrimmed)'")
                            break
                        }
                    }
                }
                
                let fullName = nameParts.joined(separator: " ")
                print("Debug: Full name assembled: '\(fullName)'")
                
                // Now parse the price line
                if i < itemsEndIndex {
                    let priceLine = lines[i]
                    let priceLineTrimmed = priceLine.trimmingCharacters(in: .whitespaces)
                    
                    // Check if this is an indented price line
                    if (priceLine.hasPrefix(" ") || priceLine.hasPrefix("\t")) && !priceLineTrimmed.isEmpty {
                        print("Debug: Processing price line: '\(priceLineTrimmed)'")
                        
                        // Extract prices and quantity using regex
                        guard let unitPrice = extractDecimal(from: priceLineTrimmed) else {
                            print("Debug: Failed to extract unit price from: '\(priceLineTrimmed)'")
                            i += 1
                            continue
                        }
                        
                        let lineTotal = extractLineTotal(from: priceLineTrimmed) ?? unitPrice
                        let quantity = extractQuantity(from: priceLineTrimmed)
                        
                        let item = ParsedReceiptItem(
                            name: fullName,
                            quantity: quantity,
                            unitPrice: unitPrice,
                            lineTotal: lineTotal
                        )
                        
                        items.append(item)
                        print("Debug: ✅ Parsed item #\(items.count): '\(fullName)', Qty=\(quantity), Price=\(unitPrice), Total=\(lineTotal)")
                        
                        i += 1
                    } else {
                        print("Debug: Expected indented price line but got: '\(priceLineTrimmed)'")
                        i += 1
                    }
                }
            } else {
                // Line is indented or doesn't look like an item start
                i += 1
            }
        }
        
        print("Debug: Total items parsed: \(items.count)")
        return items
    }
    
    /// Extracts the first decimal number from the text (unit price)
    private static func extractDecimal(from text: String) -> Decimal? {
        let pattern = "([0-9]{1,3}(?:\\.[0-9]{3})*,[0-9]{2})"
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let numberString = String(text[range])
        let normalizedString = numberString
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: normalizedString)
    }
    
    /// Extracts quantity from price line (middle number between unit price and total)
    private static func extractQuantity(from text: String) -> Double {
        let pattern = "([0-9]{1,3}(?:\\.[0-9]{3})*,[0-9]{2})|([0-9]+)"
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return 1.0
        }
        
        let nsRange = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: nsRange)
        
        // If we have at least 3 numbers (price, quantity, total), extract the middle one
        if matches.count >= 3,
           let range = Range(matches[1].range, in: text) {
            let quantityString = String(text[range])
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            
            if let quantity = Double(quantityString) {
                return quantity
            }
        }
        
        return 1.0
    }
    
    /// Extracts the line total (last decimal number on the line)
    private static func extractLineTotal(from text: String) -> Decimal? {
        let pattern = "([0-9]{1,3}(?:\\.[0-9]{3})*,[0-9]{2})(?!.*[0-9])"
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let numberString = String(text[range])
        let normalizedString = numberString
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        
        return Decimal(string: normalizedString)
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
