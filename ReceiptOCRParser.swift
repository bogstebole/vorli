//
//  ReceiptOCRParser.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 16. 1. 2026..
//

import Foundation
import Vision
import UIKit

/// Parses Serbian fiscal receipts using OCR (Optical Character Recognition)
struct ReceiptOCRParser {
    
    enum OCRError: LocalizedError {
        case imageProcessingFailed
        case noTextFound
        case parsingError(String)
        case invalidReceiptFormat
        
        var errorDescription: String? {
            switch self {
            case .imageProcessingFailed:
                return "Neuspešna obrada slike"
            case .noTextFound:
                return "Nije pronađen tekst na slici"
            case .parsingError(let message):
                return "Greška pri parsiranju: \(message)"
            case .invalidReceiptFormat:
                return "Nevažeći format računa"
            }
        }
    }
    
    /// Performs OCR on an image and parses the receipt
    static func parseReceipt(from image: UIImage) async throws -> ParsedReceipt {
        // Step 1: Extract text from image using Vision
        let recognizedText = try await performOCR(on: image)
        
        // Step 2: Parse the recognized text
        return try parseText(recognizedText)
    }
    
    /// Performs OCR on an image using Vision framework
    private static func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(throwing: OCRError.noTextFound)
                    return
                }
                
                // Combine all recognized text
                let recognizedStrings = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }
                
                if recognizedStrings.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    let fullText = recognizedStrings.joined(separator: "\n")
                    continuation.resume(returning: fullText)
                }
            }
            
            // Configure for Serbian/Latin script
            request.recognitionLanguages = ["sr-Latn", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            do {
                try requestHandler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    /// Parses extracted text into receipt data
    private static func parseText(_ text: String) throws -> ParsedReceipt {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        
        print("📄 OCR Extracted \(lines.count) lines")
        
        // Parse components
        let merchantInfo = try parseMerchantInfo(from: lines)
        let timestamp = try parseTimestamp(from: lines)
        let totals = try parseTotals(from: lines)
        let items = try parseLineItems(from: lines)
        let receiptNumber = parseReceiptNumber(from: lines)
        let cashRegister = parseCashRegister(from: lines)
        
        return ParsedReceipt(
            url: "ocr://receipt/\(UUID().uuidString)", // Generate unique URL for OCR receipts
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
    
    // MARK: - Parsing Helpers
    
    /// Parses merchant information
    private static func parseMerchantInfo(from lines: [String]) throws -> (name: String, address: String, city: String) {
        var name = ""
        var address = ""
        var city = ""
        
        // Look for merchant name (usually in uppercase, near the top)
        for (index, line) in lines.enumerated() {
            if line.contains("ФИСКАЛНИ РАЧУН") || line.contains("FISKALNI RACUN") {
                // Merchant name is typically a few lines after the header
                if index + 2 < lines.count {
                    name = lines[index + 2]
                }
                if index + 3 < lines.count {
                    address = lines[index + 3]
                }
                if index + 4 < lines.count {
                    city = lines[index + 4]
                }
                break
            }
        }
        
        // Fallback: look for common patterns
        if name.isEmpty {
            for line in lines {
                if line.count > 5 && line.uppercased() == line && !line.contains("РАЧУН") && !line.allSatisfy({ !$0.isLetter }) {
                    name = line
                    break
                }
            }
        }
        
        return (name: name, address: address, city: city)
    }
    
    /// Parses timestamp from receipt
    private static func parseTimestamp(from lines: [String]) throws -> Date {
        // Look for timestamp pattern: "ПФР време:" or date pattern DD.MM.YYYY.
        for line in lines {
            if line.contains("ПФР време") || line.contains("PFR vreme") {
                // Extract date/time after the label
                let components = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
                let dateString = components.trimmingCharacters(in: .whitespaces)
                
                // Try parsing Serbian format: DD.MM.YYYY. HH:mm:ss
                let formatter = DateFormatter()
                formatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
                formatter.locale = Locale(identifier: "sr_RS")
                
                if let date = formatter.date(from: dateString) {
                    return date
                }
            }
            
            // Look for date pattern directly
            if let date = extractDate(from: line) {
                return date
            }
        }
        
        // Fallback to current date if not found
        print("⚠️ Could not parse timestamp, using current date")
        return Date()
    }
    
    /// Extracts date from a line of text
    private static func extractDate(from text: String) -> Date? {
        // Pattern: DD.MM.YYYY. HH:mm:ss
        let pattern = #"(\d{2}\.\d{2}\.\d{4}\.\s+\d{2}:\d{2}:\d{2})"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let dateString = String(text[range])
        let formatter = DateFormatter()
        formatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
        formatter.locale = Locale(identifier: "sr_RS")
        
        return formatter.date(from: dateString)
    }
    
    /// Parses total amount and tax
    private static func parseTotals(from lines: [String]) throws -> (total: Decimal, tax: Decimal, paymentMethod: String) {
        var total: Decimal = 0
        var tax: Decimal = 0
        var paymentMethod = "Neodređeno"
        
        for line in lines {
            // Total amount
            if line.contains("Укупан износ") || line.contains("Ukupan iznos") {
                if !line.contains("пореза") && !line.contains("poreza") {
                    if let amount = extractDecimal(from: line) {
                        total = amount
                    }
                }
            }
            
            // Tax
            if line.contains("пореза") || line.contains("poreza") {
                if let amount = extractDecimal(from: line) {
                    tax = amount
                }
            }
            
            // Payment method
            if line.contains("безготовинско") || line.contains("bezgotovinsko") || line.contains("kartica") {
                paymentMethod = "Bezgotovinsko plaćanje"
            } else if line.contains("Готовина") || line.contains("Gotovina") || line.contains("keš") {
                paymentMethod = "Gotovina"
            }
        }
        
        if total == 0 {
            throw OCRError.parsingError("Nije pronađen ukupan iznos")
        }
        
        return (total: total, tax: tax, paymentMethod: paymentMethod)
    }
    
    /// Parses line items
    private static func parseLineItems(from lines: [String]) throws -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        
        // Find items section
        guard let itemsStart = lines.firstIndex(where: { $0.contains("Артикли") || $0.contains("Artikli") }) else {
            print("⚠️ Could not find items section")
            return []
        }
        
        guard let itemsEnd = lines.firstIndex(where: { $0.contains("Укупан износ") || $0.contains("Ukupan iznos") }) else {
            print("⚠️ Could not find end of items section")
            return []
        }
        
        var i = itemsStart + 1
        
        while i < itemsEnd {
            let line = lines[i]
            
            // Skip separators and headers
            if line.contains("===") || line.contains("---") || 
               line.contains("Назив") || line.contains("Naziv") ||
               line.contains("Цена") || line.contains("Cena") {
                i += 1
                continue
            }
            
            // Check if this line has price pattern (3 numbers)
            if let prices = extractPrices(from: line), prices.count >= 2 {
                // This is a price line, previous line should be the item name
                if i > 0 {
                    let itemName = lines[i - 1]
                    let unitPrice = prices[0]
                    let quantity = prices.count >= 3 ? Double(truncating: prices[1] as NSDecimalNumber) : 1.0
                    let lineTotal = prices.count >= 3 ? prices[2] : prices[1]
                    
                    let item = ParsedReceiptItem(
                        name: itemName,
                        quantity: quantity,
                        unitPrice: unitPrice,
                        lineTotal: lineTotal
                    )
                    
                    items.append(item)
                }
            }
            
            i += 1
        }
        
        print("✅ Parsed \(items.count) items")
        return items
    }
    
    /// Extracts multiple decimal numbers from text
    private static func extractPrices(from text: String) -> [Decimal]? {
        let pattern = #"(\d{1,3}(?:\.\d{3})*,\d{2})"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        
        let decimals = matches.compactMap { match -> Decimal? in
            guard let range = Range(match.range, in: text) else { return nil }
            let numberString = String(text[range])
            return parseDecimal(from: numberString)
        }
        
        return decimals.isEmpty ? nil : decimals
    }
    
    /// Extracts first decimal number from text
    private static func extractDecimal(from text: String) -> Decimal? {
        let pattern = #"(\d{1,3}(?:\.\d{3})*,\d{2})"#
        
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else {
            return nil
        }
        
        let numberString = String(text[range])
        return parseDecimal(from: numberString)
    }
    
    /// Parses a Decimal from Serbian number format (1.234,56)
    private static func parseDecimal(from string: String) -> Decimal? {
        let cleaned = string
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespaces)
        
        return Decimal(string: cleaned)
    }
    
    /// Parses receipt number
    private static func parseReceiptNumber(from lines: [String]) -> String {
        for line in lines {
            if line.contains("ПФР број рачуна") || line.contains("PFR broj racuna") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
    
    /// Parses cash register number
    private static func parseCashRegister(from lines: [String]) -> String {
        for line in lines {
            if line.contains("ЕСИР број") || line.contains("ESIR broj") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
}
