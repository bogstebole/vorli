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
        print("🔍 Starting OCR on image...")
        let recognizedText = try await performOCR(on: image)
        
        print("📝 OCR completed. Extracted text:")
        print(String(repeating: "=", count: 50))
        print(recognizedText)
        print(String(repeating: "=", count: 50))
        
        // Step 2: Parse the recognized text
        print("🔧 Starting to parse text...")
        return try parseText(recognizedText)
    }
    
    /// Public test method to get just the OCR text
    static func performOCRTest(on image: UIImage) async throws -> String {
        return try await performOCR(on: image)
    }
    
    /// Performs OCR on an image using Vision framework
    private static func performOCR(on image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.imageProcessingFailed
        }
        
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
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
                let recognizedStrings = observations.compactMap { observation -> String? in
                    // Get top candidate with confidence
                    guard let topCandidate = observation.topCandidates(1).first else {
                        return nil
                    }
                    
                    // Decode HTML entities from OCR text
                    let decodedString = topCandidate.string.decodingHTMLEntities()
                    
                    print("📝 OCR Line (confidence: \(String(format: "%.2f", topCandidate.confidence))): \(decodedString)")
                    return decodedString
                }
                
                if recognizedStrings.isEmpty {
                    continuation.resume(throwing: OCRError.noTextFound)
                } else {
                    let fullText = recognizedStrings.joined(separator: "\n")
                    print("\n✅ OCR completed with \(recognizedStrings.count) lines")
                    continuation.resume(returning: fullText)
                }
            }
            
            // Configure for Serbian/Latin script and better accuracy
            request.recognitionLanguages = ["sr-Latn", "sr", "en-US"]
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = false // Disable to avoid autocorrect changing numbers
            request.automaticallyDetectsLanguage = true
            request.revision = VNRecognizeTextRequestRevision3 // Use latest OCR version
            
            // Improve accuracy for receipts
            request.customWords = [
                // Serbian words commonly on receipts
                "Рачун", "Фискални", "Укупно", "Артикал", "Количина", "Цена",
                "racun", "fiskalni", "ukupno", "artikal", "kolicina", "cena",
                "PIB", "ESIR", "PFR", "PDV", "Gotovina", "Bezgotovinsko",
                "Улица", "Град", "Порез"
            ]
            
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
        print("Lines:")
        for (i, line) in lines.enumerated() {
            print("  [\(i)]: \(line)")
        }
        
        // Parse components
        print("\n🔍 Parsing merchant info...")
        let merchantInfo = parseMerchantInfo(from: lines)
        print("✅ Merchant: \(merchantInfo.name)")
        
        print("\n🔍 Parsing timestamp...")
        let timestamp = parseTimestamp(from: lines)
        print("✅ Timestamp: \(timestamp)")
        
        print("\n🔍 Parsing totals...")
        let totals = try parseTotals(from: lines)
        print("✅ Totals: \(totals.total)")
        
        print("\n🔍 Parsing items...")
        let items = parseLineItems(from: lines)
        print("✅ Items: \(items.count)")
        
        print("\n🔍 Parsing receipt number...")
        let receiptNumber = parseReceiptNumber(from: lines)
        print("✅ Receipt number: \(receiptNumber)")
        
        print("\n🔍 Parsing cash register...")
        let cashRegister = parseCashRegister(from: lines)
        print("✅ Cash register: \(cashRegister)")
        
        let receipt = ParsedReceipt(
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
        
        print("\n✅ Successfully parsed receipt!")
        return receipt
    }
    
    // MARK: - Parsing Helpers
    
    /// Parses merchant information
    private static func parseMerchantInfo(from lines: [String]) -> (name: String, address: String, city: String) {
        var name = ""
        var address = ""
        var city = ""
        
        print("🏪 Looking for merchant info...")
        
        // Strategy 1: Look for company name with DOO/D.O.O. first (most reliable)
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Look for company type indicators
            if (lowercased.contains("doo") || lowercased.contains("d.o.o") || 
                lowercased.contains("d. o. o")) && line.count > 5 {
                name = line
                print("  Found name (company type): \(name)")
                
                // Try to get address and city from next lines
                var addressIndex = index + 1
                
                // Skip any ID numbers or office/branch info
                while addressIndex < lines.count {
                    let nextLine = lines[addressIndex]
                    let nextLowercased = nextLine.lowercased()
                        .folding(options: .diacriticInsensitive, locale: .current)
                    
                    // Skip PIB, MB, tax office numbers, branch info
                    if nextLowercased.contains("pib") || 
                       nextLowercased.contains("mb:") ||
                       nextLine.contains("700/") ||
                       nextLowercased.contains("matični") ||
                       nextLowercased.contains("prodajno mesto") ||
                       nextLowercased.contains("fo ") || // Filijala/office
                       nextLine.trimmingCharacters(in: .decimalDigits).isEmpty {
                        addressIndex += 1
                        continue
                    }
                    
                    // First valid line after company name is likely address
                    if address.isEmpty && nextLine.rangeOfCharacter(from: .letters) != nil {
                        address = nextLine
                        print("  Found address: \(address)")
                        addressIndex += 1
                        
                        // Next line is likely city/postal code
                        if addressIndex < lines.count {
                            let cityLine = lines[addressIndex]
                            let cityLowercased = cityLine.lowercased()
                                .folding(options: .diacriticInsensitive, locale: .current)
                            
                            // Skip more ID lines
                            if !cityLowercased.contains("pib") && 
                               !cityLine.contains("700/") &&
                               cityLine.rangeOfCharacter(from: .letters) != nil {
                                city = cityLine
                                print("  Found city: \(city)")
                            }
                        }
                        break
                    }
                    
                    addressIndex += 1
                }
                
                if !name.isEmpty {
                    break
                }
            }
        }
        
        // Strategy 2: Look near fiscal header if DOO not found
        if name.isEmpty {
            for (index, line) in lines.enumerated() {
                let lowercased = line.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                
                // Look for fiscal receipt header
                if lowercased.contains("fiskalni racun") || lowercased.contains("fiskalni") || 
                   lowercased.contains("fiskalnog") {
                    print("  Found fiscal header at line \(index): \(line)")
                    
                    // Look for merchant info in nearby lines
                    for offset in 1...10 {
                        if index + offset < lines.count {
                            let nextLine = lines[index + offset]
                            let nextLowercased = nextLine.lowercased()
                            
                            // Skip ID numbers, headers, and separators
                            if nextLowercased.contains("pib") || 
                               nextLine.contains("700/") ||
                               nextLowercased.contains("esir") ||
                               nextLowercased.contains("kasir") ||
                               nextLine.trimmingCharacters(in: .decimalDigits).isEmpty ||
                               nextLine.contains("===") || nextLine.contains("---") {
                                continue
                            }
                            
                            // Look for company name - usually in uppercase or has company type
                            if name.isEmpty && nextLine.count > 5 && 
                               nextLine.rangeOfCharacter(from: .letters) != nil &&
                               (nextLine.uppercased() == nextLine || 
                                nextLowercased.contains("doo") || 
                                nextLowercased.contains("d.o.o")) {
                                name = nextLine
                                print("  Found name: \(name)")
                            } else if !name.isEmpty && address.isEmpty && 
                                      nextLine.rangeOfCharacter(from: .letters) != nil &&
                                      !nextLine.contains("-") { // Skip lines with dashes (often org units)
                                address = nextLine
                                print("  Found address: \(address)")
                            } else if !name.isEmpty && !address.isEmpty && city.isEmpty &&
                                      nextLine.rangeOfCharacter(from: .letters) != nil {
                                city = nextLine
                                print("  Found city: \(city)")
                                break
                            }
                        }
                    }
                    break
                }
            }
        }
        
        // Strategy 3: Fallback - look for uppercase company names
        if name.isEmpty {
            for (index, line) in lines.enumerated() {
                let lowercased = line.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                
                // Skip the first few lines and look for uppercase text
                if index > 2 && line.count > 5 && 
                   line.uppercased() == line && 
                   !lowercased.contains("racun") &&
                   !lowercased.contains("fiskalni") &&
                   !line.contains("===") &&
                   !line.contains("---") &&
                   line.rangeOfCharacter(from: .letters) != nil {
                    name = line
                    print("  Found name (uppercase fallback): \(name)")
                    
                    // Try to get address and city from next lines
                    if index + 1 < lines.count {
                        let nextLine = lines[index + 1]
                        if !nextLine.contains("700/") && 
                           !nextLine.lowercased().contains("esir") &&
                           !nextLine.lowercased().contains("pib") {
                            address = nextLine
                            print("  Found address (fallback): \(address)")
                        }
                    }
                    if index + 2 < lines.count {
                        city = lines[index + 2]
                        print("  Found city (fallback): \(city)")
                    }
                    break
                }
            }
        }
        
        return (name: name, address: address, city: city)
    }
    
    /// Parses timestamp from receipt
    private static func parseTimestamp(from lines: [String]) -> Date {
        // Priority 1: Look for "ПФР време:" (PFR time) - this is the official receipt timestamp
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Check for "ПФР време:" specifically (fiscal receipt time)
            if (lowercased.contains("pfr") && lowercased.contains("vreme")) || 
               (line.contains("ПФР") && line.contains("време")) {
                print("  Found PFR time label at line \(index): \(line)")
                
                // Check next line for the actual timestamp
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    print("  Checking next line for PFR date: \(nextLine)")
                    
                    if let date = extractDate(from: nextLine) {
                        print("  ✅ Parsed PFR date from next line: \(date)")
                        return date
                    }
                }
                
                // Also try parsing from the same line (after colon)
                let components = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
                let dateString = components.trimmingCharacters(in: .whitespaces)
                
                if !dateString.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
                    formatter.locale = Locale(identifier: "sr_RS")
                    
                    if let date = formatter.date(from: dateString) {
                        print("  ✅ Parsed PFR date from same line: \(date)")
                        return date
                    }
                }
            }
        }
        
        // Priority 2: Look for general "време:" or "vreme:" labels
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            if lowercased.contains("vreme:") || line.contains("време:") {
                print("  Found time label at line \(index): \(line)")
                
                // Check next line for the actual timestamp
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    print("  Checking next line for date: \(nextLine)")
                    
                    if let date = extractDate(from: nextLine) {
                        print("  ✅ Parsed date from next line: \(date)")
                        return date
                    }
                }
                
                // Also try parsing from the same line (after colon)
                let components = line.components(separatedBy: ":").dropFirst().joined(separator: ":")
                let dateString = components.trimmingCharacters(in: .whitespaces)
                
                if !dateString.isEmpty {
                    let formatter = DateFormatter()
                    formatter.dateFormat = "dd.MM.yyyy. HH:mm:ss"
                    formatter.locale = Locale(identifier: "sr_RS")
                    
                    if let date = formatter.date(from: dateString) {
                        print("  ✅ Parsed date from same line: \(date)")
                        return date
                    }
                }
            }
        }
        
        // Priority 3: Look for date pattern directly in any line (but skip parking tickets)
        for (index, line) in lines.enumerated() {
            // Skip parking ticket dates and registration info
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            if lowercased.contains("reg") || lowercased.contains("parking") ||
               lowercased.contains("datum") || lowercased.contains("uatue") {
                continue
            }
            
            if let date = extractDate(from: line) {
                // Validate that date is reasonable (not from 2020 if we're in 2026)
                let calendar = Calendar.current
                let currentYear = calendar.component(.year, from: Date())
                let dateYear = calendar.component(.year, from: date)
                
                // Only accept dates within 1 year of current date
                if abs(currentYear - dateYear) <= 1 {
                    print("  ✅ Found valid date pattern in line \(index): \(date)")
                    return date
                } else {
                    print("  ⚠️ Skipping date from line \(index) (year \(dateYear) is too far from current year \(currentYear)): \(line)")
                }
            }
        }
        
        // Fallback to current date if not found
        print("⚠️ Could not parse timestamp, using current date")
        return Date()
    }
    
    /// Extracts date from a line of text
    private static func extractDate(from text: String) -> Date? {
        // Try multiple date patterns
        let patterns = [
            #"(\d{2}\.\d{2}\.\d{4}\.\s+\d{2}:\d{2}:\d{2})"#,  // DD.MM.YYYY. HH:mm:ss (with dot and space)
            #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2}:\d{2})"#,    // DD.MM.YYYY HH:mm:ss (without dot before time)
            #"(\d{2}\.\d{2}\.\d{4})"#                          // DD.MM.YYYY (date only)
        ]
        
        let dateFormatters = [
            "dd.MM.yyyy. HH:mm:ss",
            "dd.MM.yyyy HH:mm:ss",
            "dd.MM.yyyy"
        ]
        
        for (index, pattern) in patterns.enumerated() {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else {
                continue
            }
            
            let dateString = String(text[range])
            print("    Found date string: '\(dateString)' with pattern \(index)")
            
            let formatter = DateFormatter()
            formatter.dateFormat = dateFormatters[index]
            formatter.locale = Locale(identifier: "sr_RS")
            
            if let date = formatter.date(from: dateString) {
                return date
            }
        }
        
        return nil
    }
    
    /// Parses total amount and tax
    private static func parseTotals(from lines: [String]) throws -> (total: Decimal, tax: Decimal, paymentMethod: String) {
        var total: Decimal = 0
        var tax: Decimal = 0
        var paymentMethod = "Neodređeno"
        var foundPaymentAmount = false
        
        // Print all lines for debugging
        print("🔍 Looking for total in \(lines.count) lines:")
        for (index, line) in lines.enumerated() {
            print("  Line \(index): \(line)")
        }
        
        // Strategy: Look for multiple total patterns in priority order
        // Priority 1: "За уплату:" / "Za uplatu:"
        // Priority 2: "Ukupan iznos:" / "Укупан износ:" (total amount to pay)
        // Priority 3: "УКУПНО:" / "Ukupno:"
        // Note: Skip "Gotovina" amounts (cash given) and "Povracaj" (change)
        
        let totalPatterns = [
            ("uplatu", "За уплату"),
            ("ukupan iznos:", "Укупан износ:"),
            ("ukupan iznos", "Укупан износ"),
            ("ukupno za naplatu", "Ukupno za naplatu"),
            ("ukupno:", "УКУПНО")
        ]
        
        // First pass - look for explicit payment amount markers
        for (pattern, description) in totalPatterns {
            if foundPaymentAmount { break }
            
            for (index, line) in lines.enumerated() {
                let lowercasedLine = line.lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                
                // Check if this line matches the pattern
                if lowercasedLine.contains(pattern) || line.contains(description) {
                    print("  Found '\(description)' pattern at line \(index): \(line)")
                    
                    // Special handling for "Ukupan iznos:" - may be on same line or next line
                    // But skip if followed by "Gotovina:" or "Povracaj:"
                    if pattern.contains("ukupan iznos") {
                        // Check if this is followed by "Gotovina:" or "Povracaj:" labels
                        var isActualTotal = true
                        for checkOffset in 1...3 {
                            if index + checkOffset < lines.count {
                                let checkLine = lines[index + checkOffset].lowercased()
                                    .folding(options: .diacriticInsensitive, locale: .current)
                                if checkLine.contains("gotovina:") || checkLine.contains("povracaj:") {
                                    isActualTotal = true // This IS the total we want!
                                    break
                                }
                            }
                        }
                    }
                    
                    // Try to extract amount from same line
                    if let amount = extractDecimal(from: line) {
                        print("✅ Found payment (same line): \(amount)")
                        total = amount
                        foundPaymentAmount = true
                        break
                    } else {
                        // Search next 10 lines for the amount
                        print("  Checking next 10 lines for amount...")
                        for offset in 1...10 {
                            if index + offset >= lines.count { break }
                            let nextLine = lines[index + offset]
                            let nextLowercased = nextLine.lowercased()
                                .folding(options: .diacriticInsensitive, locale: .current)
                            
                            // Skip separator lines and OCR artifacts
                            if nextLine.contains("===") || nextLine.contains("ニニ") ||
                               nextLine.contains("111") || nextLine.contains("215") || 
                               nextLine.contains("日") || nextLine.contains("---") {
                                print("    Skipping separator line: \(nextLine)")
                                continue
                            }
                            
                            // Skip header/label lines but continue looking
                            if nextLowercased.contains("ukupno") && !nextLowercased.contains("iznos") ||
                               nextLowercased.contains("pdv") ||
                               nextLowercased.contains("oznaka") {
                                print("    Skipping header line: \(nextLine)")
                                continue
                            }
                            
                            // Skip payment method labels (gotovina, kartica)
                            if nextLowercased == "gotovina" || nextLowercased == "kartica" ||
                               nextLowercased == "karticu" || nextLowercased == "bezgotovinsko" ||
                               nextLowercased == "povracaj" || nextLowercased.contains("povracaj") {
                                print("    Skipping payment method label: \(nextLine)")
                                continue
                            }
                            
                            // Also skip if the line contains "gotovina:" or "povracaj:" (payment details)
                            if nextLowercased.contains("gotovina:") || 
                               nextLowercased.contains("povracaj:") ||
                               nextLowercased.contains("povrahaj:") { // OCR error
                                print("    Skipping payment detail line: \(nextLine)")
                                continue
                            }
                            
                            // Try to extract amount from this line
                            if let amount = extractDecimal(from: nextLine) {
                                // For "ukupan iznos" pattern, accept smaller amounts (50+ RSD)
                                // For "za uplatu" pattern, require larger amounts (100+ RSD)
                                let minAmount: Decimal = pattern.contains("uplatu") ? 100 : 50
                                
                                if amount >= minAmount {
                                    print("✅ Found payment (\(offset) lines down): \(amount) from line: \(nextLine)")
                                    total = amount
                                    foundPaymentAmount = true
                                    break
                                } else {
                                    print("    Found amount \(amount) but too small (< \(minAmount)), continuing...")
                                }
                            }
                        }
                        if foundPaymentAmount {
                            break
                        }
                    }
                }
            }
        }
        
        // Second pass - look for tax and payment method
        for (index, line) in lines.enumerated() {
            let lowercasedLine = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Tax - look for "Ukupan iznos poreza" or similar
            if (lowercasedLine.contains("porez") || lowercasedLine.contains("pdv") ||
                line.contains("Порез") || line.contains("порез")) && 
               (lowercasedLine.contains("ukupan") || lowercasedLine.contains("iznos") ||
                line.contains("Укупан") || line.contains("укупан") ||
                line.contains("износ")) {
                print("  Found tax header at line \(index): \(line)")
                if let amount = extractDecimal(from: line) {
                    print("✅ Found tax (same line): \(amount)")
                    tax = amount
                } else {
                    // Check next few lines for tax amount
                    for offset in 1...5 {
                        if index + offset >= lines.count { break }
                        let nextLine = lines[index + offset]
                        let nextLowercased = nextLine.lowercased()
                            .folding(options: .diacriticInsensitive, locale: .current)
                        
                        // Skip separator lines
                        if nextLine.contains("===") || nextLine.contains("ニニ") ||
                           nextLine.contains("---") {
                            print("    Skipping separator: \(nextLine)")
                            continue
                        }
                        
                        // Skip other headers/labels
                        if nextLowercased.contains("pfr") || nextLowercased.contains("vreme") ||
                           nextLowercased.contains("racuna") {
                            print("    Skipping header: \(nextLine)")
                            continue
                        }
                        
                        if let amount = extractDecimal(from: nextLine) {
                            // Make sure it's a reasonable tax amount
                            // Tax should be less than total, and typically 5-30% of total
                            if total > 0 {
                                let taxPercentage = (amount / total) * 100
                                if taxPercentage > 50 {
                                    print("    Amount \(amount) = \(taxPercentage)% of total, seems too large for tax, skipping...")
                                    continue
                                }
                            }
                            print("✅ Found tax (\(offset) lines down): \(amount) from line: \(nextLine)")
                            tax = amount
                            break
                        }
                    }
                }
            }
            
            // Tax label check (standalone "Porez" line)
            if (lowercasedLine == "porez" || lowercasedLine == "porea") {
                print("  Found standalone tax label at line \(index): \(line)")
                if index + 1 < lines.count, let amount = extractDecimal(from: lines[index + 1]) {
                    print("✅ Found tax (next line): \(amount)")
                    tax = amount
                }
            }
            
            // Total amount - only use if more specific pattern wasn't found
            if !foundPaymentAmount {
                if (lowercasedLine.contains("ukupan") && 
                    !lowercasedLine.contains("porez")) ||
                   lowercasedLine.contains("total") || 
                   lowercasedLine.contains("svega") {
                    if let amount = extractDecimal(from: line) {
                        print("✅ Found total: \(amount) in line: \(line)")
                        total = amount
                    }
                }
            }
            
            // Payment method - improved detection  
            if lowercasedLine.contains("gotovina") || lowercasedLine.contains("kes") ||
               line.contains("Готовина") || line.contains("готовина") {
                // For cash payments, check if there's a return/change amount
                // If "povracaj" or "kusur" is mentioned after, it's cash
                paymentMethod = "Gotovina"
                print("✅ Found payment method: cash")
            } else if lowercasedLine.contains("bezgotovinsko") || 
                      lowercasedLine.contains("kartic") || 
                      lowercasedLine.contains("platna kartica") ||
                      lowercasedLine.contains("debitna") ||
                      lowercasedLine.contains("kreditna") ||
                      line.contains("Платна") || line.contains("платна") {
                paymentMethod = "Bezgotovinsko plaćanje"
                print("✅ Found payment method: card")
            }
        }
        
        // Last resort: try to find the largest reasonable number on the receipt
        if total == 0 {
            print("⚠️ Could not find total with standard patterns, looking for largest amount...")
            var largestAmount: Decimal = 0
            
            for line in lines {
                if let amount = extractDecimal(from: line), amount > largestAmount && amount < 1000000 {
                    largestAmount = amount
                    print("  Found amount: \(amount) in line: \(line)")
                }
            }
            
            if largestAmount > 0 {
                print("⚠️ Using largest amount as total: \(largestAmount)")
                total = largestAmount
            } else {
                throw OCRError.parsingError("Nije pronađen ukupan iznos")
            }
        }
        
        print("💰 Final parsed totals - Total: \(total), Tax: \(tax), Payment: \(paymentMethod)")
        return (total: total, tax: tax, paymentMethod: paymentMethod)
    }
    
    /// Parses line items
    private static func parseLineItems(from lines: [String]) -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []
        
        print("🔍 Looking for items section...")
        
        // Find items section - look for various header patterns
        var itemsStart: Int?
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Look for item header variations - can be on same or separate lines
            // Check both Latin and Cyrillic
            if lowercased.contains("artikl") || 
               lowercased.contains("naziv") ||
               lowercased.contains("naэiv") || // OCR error for "naziv"
               lowercased.contains("promet") ||
               line.contains("Артикли") || line.contains("артикли") || // Cyrillic
               line.contains("Назив") || line.contains("назив") {  // Cyrillic
                itemsStart = index
                print("✅ Found items header at line \(index): \(line)")
                break
            }
            
            // Check if "naziv" is split across lines (like "Наэив" on one line and "артикла" on next)
            if index + 1 < lines.count {
                let nextLowercased = lines[index + 1].lowercased()
                    .folding(options: .diacriticInsensitive, locale: .current)
                if (lowercased.contains("naziv") || lowercased.contains("naэiv")) && 
                   nextLowercased.contains("artikl") {
                    itemsStart = index
                    print("✅ Found split items header at lines \(index)-\(index+1): \(line) / \(lines[index+1])")
                    break
                }
            }
        }
        
        guard let start = itemsStart else {
            print("⚠️ Could not find items section header")
            return []
        }
        
        // Find end of items section - look for summary section
        var itemsEnd: Int?
        for (index, line) in lines.enumerated() where index > start {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // End markers - be more specific to avoid false positives
            if (lowercased.contains("oznaka") && !lowercased.contains("pdv")) ||
               (lowercased.contains("ukupan") && lowercased.contains("iznos") && !lowercased.contains("artikl")) ||
               lowercased.contains("stopa") ||
               line.contains("Ознака") || line.contains("ознака") || // Cyrillic
               line.contains("Укупан износ:") || line.contains("укупан износ:") { // Cyrillic
                itemsEnd = index
                print("✅ Found items end at line \(index): \(line)")
                break
            }
        }
        
        let end: Int
        if let itemsEnd = itemsEnd {
            end = itemsEnd
        } else {
            print("⚠️ Could not find end of items section, using all remaining lines")
            end = lines.count
        }
        
        var i = start + 1
        
        print("📦 Parsing items from line \(i) to \(end)...")
        
        // Skip column headers (Кол., Jед. цена, Укупно, etc.)
        while i < end {
            let line = lines[i]
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Skip known header rows
            if lowercased.contains("kol.") || lowercased.contains("jed") || 
               lowercased.contains("ukupno") || lowercased.contains("pdv") ||
               lowercased.contains("oznaka") {
                i += 1
                continue
            }
            
            break
        }
        
        print("  Starting item parsing from line \(i)")
        
        while i < end {
            let line = lines[i]
            
            // Skip separators, empty lines, and headers
            if line.contains("===") || line.contains("---") || line.contains("____") ||
               line.contains("はニニ") || line.contains("月") || // OCR artifacts
               line.trimmingCharacters(in: .whitespaces).isEmpty {
                i += 1
                continue
            }
            
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Skip if this looks like a summary line
            if lowercased.contains("oznaka") || lowercased.contains("ukupan") ||
               lowercased.contains("stopa") {
                print("  Reached summary section at line \(i): \(line)")
                break
            }
            
            // Skip OCR garbage (Japanese characters, too many digits)
            let hasJapanese = line.range(of: "[\\p{Hiragana}\\p{Katakana}\\p{Han}]", options: .regularExpression) != nil
            if hasJapanese {
                print("  Skipping OCR artifact at line \(i): \(line)")
                i += 1
                continue
            }
            
            // Look for item name followed by quantity/price line
            // Serbian receipts often have format:
            // Item Name (with possible barcode)
            // price or (quantity kom. x unit_price RSD) [optional] total_price
            
            // Check if current line looks like an item name (has letters, not just numbers/symbols)
            let hasLetters = line.rangeOfCharacter(from: .letters) != nil
            let hasPrices = extractPrices(from: line) != nil
            
            // Check if this line contains a barcode followed by text (common pattern)
            let barcodeWithTextPattern = #"\d{10,}\s+([a-zA-Zа-яА-ЯčćžšđČĆŽŠĐ\s]+)"#
            let hasBarcodeWithText = line.range(of: barcodeWithTextPattern, options: .regularExpression) != nil
            
            if (hasLetters && !hasPrices) || hasBarcodeWithText {
                // This could be an item name, check next line for prices
                print("  Potential item name at line \(i): \(line)")
                
                if i + 1 < end {
                    let nextLine = lines[i + 1]
                    print("    Checking detail line: \(nextLine)")
                    
                    // Check if next line has quantity pattern like "(2,000 kom. x 429,00 RSD)"
                    if let itemData = parseItemLine(name: line, detailLine: nextLine) {
                        items.append(itemData)
                        print("  ✓ Found item: \(itemData.name) - \(itemData.lineTotal)")
                        i += 2 // Skip both name and detail line
                        continue
                    } else if let prices = extractPrices(from: nextLine), !prices.isEmpty {
                        // Fallback: just use the price from next line
                        // But clean up the item name first
                        var cleanedName = line
                        
                        // Remove barcode
                        let barcodePattern = #"\b\d{10,}\b"#
                        if let regex = try? NSRegularExpression(pattern: barcodePattern) {
                            cleanedName = regex.stringByReplacingMatches(
                                in: cleanedName,
                                range: NSRange(cleanedName.startIndex..., in: cleanedName),
                                withTemplate: ""
                            )
                        }
                        
                        cleanedName = cleanedName
                            .replacingOccurrences(of: #"\s*[\(\[]$"#, with: "", options: .regularExpression)
                            .trimmingCharacters(in: .whitespaces)
                        
                        let item = ParsedReceiptItem(
                            name: cleanedName,
                            quantity: 1.0,
                            unitPrice: prices.last ?? 0,
                            lineTotal: prices.last ?? 0
                        )
                        items.append(item)
                        print("  ✓ Found simple item: \(item.name) - \(item.lineTotal)")
                        i += 2
                        continue
                    }
                }
            }
            
            i += 1
        }
        
        print("✅ Parsed \(items.count) items total")
        return items
    }
    
    /// Parses an item from name and detail line
    private static func parseItemLine(name: String, detailLine: String) -> ParsedReceiptItem? {
        // Pattern: (quantity kom. x unit_price RSD) [optional_tax] total_price
        // Example: "(2,000 kom. x 429,00 RSD) [Đ]" followed by total
        
        var quantity: Double = 1.0
        var unitPrice: Decimal = 0
        var lineTotal: Decimal = 0
        
        // Clean up the item name - remove barcodes and extra characters
        var cleanedName = name
        
        // Remove barcode patterns (long sequences of digits)
        let barcodePattern = #"\b\d{10,}\b"#
        if let regex = try? NSRegularExpression(pattern: barcodePattern) {
            cleanedName = regex.stringByReplacingMatches(
                in: cleanedName,
                range: NSRange(cleanedName.startIndex..., in: cleanedName),
                withTemplate: ""
            )
        }
        
        // Remove trailing incomplete parentheses or brackets
        cleanedName = cleanedName
            .replacingOccurrences(of: #"\s*[\(\[]$"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
        
        // Extract all prices from the detail line
        guard let prices = extractPrices(from: detailLine), !prices.isEmpty else {
            return nil
        }
        
        // Look for quantity pattern
        let quantityPattern = #"(\d{1,3}(?:[\.,]\d{3})*)"#
        if let regex = try? NSRegularExpression(pattern: quantityPattern),
           let match = regex.firstMatch(in: detailLine, range: NSRange(detailLine.startIndex..., in: detailLine)),
           let range = Range(match.range, in: detailLine) {
            let quantityString = String(detailLine[range])
                .replacingOccurrences(of: ".", with: "")
                .replacingOccurrences(of: ",", with: ".")
            quantity = Double(quantityString) ?? 1.0
        }
        
        // Parse prices based on count
        if prices.count >= 2 {
            // Has unit price and total
            unitPrice = prices[0]
            lineTotal = prices[prices.count - 1] // Last price is usually the total
        } else if prices.count == 1 {
            // Only one price, use it as both
            unitPrice = prices[0]
            lineTotal = prices[0]
        } else {
            return nil
        }
        
        return ParsedReceiptItem(
            name: cleanedName,
            quantity: quantity,
            unitPrice: unitPrice,
            lineTotal: lineTotal
        )
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
        // Try multiple patterns to catch OCR errors
        let patterns = [
            #"(\d{1,3}(?:\.\d{3})*,\d{2})"#,     // Serbian: 1.234,56
            #"(\d{1,3}(?:,\d{3})*\.\d{2})"#,     // English: 1,234.56
            #"(\d+,\d{2})"#,                      // Simple: 1234,56
            #"(\d+\.\d{2})"#                      // Simple: 1234.56
        ]
        
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern),
                  let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
                  let range = Range(match.range, in: text) else {
                continue
            }
            
            let numberString = String(text[range])
            
            // Try to parse as Serbian format first (. = thousands, , = decimal)
            if numberString.contains(",") {
                if let decimal = parseDecimal(from: numberString) {
                    return decimal
                }
            }
            
            // Try to parse as English format (. = decimal)
            if numberString.contains(".") && !numberString.contains(",") {
                let cleaned = numberString
                    .replacingOccurrences(of: ",", with: "")
                    .trimmingCharacters(in: .whitespaces)
                if let decimal = Decimal(string: cleaned) {
                    return decimal
                }
            }
        }
        
        return nil
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
        for (index, line) in lines.enumerated() {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            // Look for receipt number patterns with OCR error tolerance
            if lowercased.contains("broj racuna") || 
               lowercased.contains("broj racuna") ||
               line.contains("број рачуна") ||
               line.contains("броj рачуна") || // OCR error: j instead of ј
               line.contains("броз рачуна") || // OCR error: з instead of ј
               lowercased.contains("pfr broj") ||
               lowercased.contains("pfr broz") { // OCR error tolerance
                
                print("  Found receipt number label: \(line)")
                
                // Try to extract after colon
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    let number = components[1].trimmingCharacters(in: .whitespaces)
                    if !number.isEmpty {
                        print("  Extracted receipt number: \(number)")
                        return number
                    }
                }
                
                // If no colon or empty after colon, check next line
                if index + 1 < lines.count {
                    let nextLine = lines[index + 1]
                    // Check if next line has alphanumeric pattern
                    let pattern = #"([A-Z0-9\-]{10,})"#
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: nextLine, range: NSRange(nextLine.startIndex..., in: nextLine)),
                       let range = Range(match.range, in: nextLine) {
                        let number = String(nextLine[range])
                        print("  Extracted receipt number from next line: \(number)")
                        return number
                    }
                }
                
                // Try to extract alphanumeric pattern (like WBDHLUCT-WBDHLUCT-42511) from same line
                let pattern = #"([A-Z0-9\-]{10,})"#
                if let regex = try? NSRegularExpression(pattern: pattern),
                   let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range, in: line) {
                    let number = String(line[range])
                    print("  Extracted receipt number (regex): \(number)")
                    return number
                }
            }
        }
        return ""
    }
    
    /// Parses cash register number
    private static func parseCashRegister(from lines: [String]) -> String {
        for line in lines {
            let lowercased = line.lowercased()
                .folding(options: .diacriticInsensitive, locale: .current)
            
            if lowercased.contains("esir") && lowercased.contains("broj") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
            
            // Also check for ESIR at start of line
            if line.hasPrefix("ЕСИР") || line.hasPrefix("ESIR") {
                let components = line.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return ""
    }
}
