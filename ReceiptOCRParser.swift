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
        
        // Pass the image's display orientation so Vision reads upright text.
        // Without this, a portrait photo (orientation .right) is processed
        // rotated 90°, which collapses recognition quality.
        let cgOrientation = CGImagePropertyOrientation(image.imageOrientation)

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, orientation: cgOrientation, options: [:])
            
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

                    // Drop low-confidence lines — these are OCR noise (stray
                    // symbols, garbled separators) that corrupt parsing.
                    guard topCandidate.confidence >= 0.45 else {
                        print("🗑️ Skipping low-confidence line (\(String(format: "%.2f", topCandidate.confidence))): \(topCandidate.string)")
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
            // Force the configured languages; auto-detect overrides recognitionLanguages
            // and can pick the wrong script for short, number-heavy receipt lines.
            request.automaticallyDetectsLanguage = false
            // Catch small fine-print lines on long thermal receipts.
            request.minimumTextHeight = 0.012
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
        let rawLines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        let lines = mergeSplitDecimals(rawLines)

        print("📄 OCR Extracted \(lines.count) lines")
        print("Lines:")
        for (i, line) in lines.enumerated() {
            print("  [\(i)]: \(line)")
        }

        return try parseLines(lines)
    }

    /// Merges OCR lines where a decimal amount was split across two lines,
    /// e.g. "661" followed by ",95" → "661,95". Common on LIDL-style receipts.
    private static func mergeSplitDecimals(_ lines: [String]) -> [String] {
        var result: [String] = []
        var i = 0
        while i < lines.count {
            let line = lines[i]
            if i + 1 < lines.count,
               lines[i + 1].range(of: #"^[.,]\d{2}$"#, options: .regularExpression) != nil,
               line.range(of: #"^\d[\d.,]*\d$|^\d$"#, options: .regularExpression) != nil {
                result.append(line + lines[i + 1])
                i += 2
            } else {
                result.append(line)
                i += 1
            }
        }
        return result
    }

    private static func parseLines(_ lines: [String]) throws -> ParsedReceipt {

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
        
        // The total is the largest money amount on the receipt. Prefer it when
        // it's larger than whatever the label-based logic found — this corrects
        // cases where OCR split the decimals (661 vs 661,95) or matched an item.
        let largestMoney = findTotalRobust(from: lines)
        if let largestMoney, largestMoney > total {
            print("✅ Using largest money value as total: \(largestMoney) (was \(total))")
            total = largestMoney
        }
        if total == 0 {
            throw OCRError.parsingError("Nije pronađen ukupan iznos")
        }

        print("💰 Final parsed totals - Total: \(total), Tax: \(tax), Payment: \(paymentMethod)")
        return (total: total, tax: tax, paymentMethod: paymentMethod)
    }

    /// The receipt total is the largest well-formed money amount on the ticket:
    /// every line item and the tax are ≤ the total, and IDs / counters /
    /// quantities are excluded because they lack a 2-decimal money shape.
    /// This is the single most consistent signal across jumbled OCR layouts.
    ///
    /// Exception: cash tendered ("Gotovina") and change ("Povraćaj") are the
    /// only amounts that can legitimately EXCEED the total (paying 2.000 for a
    /// 1.319,50 bill), so those lines — and a bare amount on the line right
    /// after such a label — must not participate in the max.
    private static func findTotalRobust(from lines: [String]) -> Decimal? {
        var candidates: [Decimal] = []
        var skipNextBareAmount = false

        for line in lines {
            let folded = latinFolded(line)
            // "gotovin" also matches "bezgotovinsko" — safe to exclude, since a
            // card-payment line only ever repeats the total printed elsewhere.
            let isPaymentLine = folded.contains("gotovin") || folded.contains("povra")
                || folded.contains("kusur") || folded.contains("predato")
                || folded.contains("uplaceno") || folded.contains("placeno")

            if isPaymentLine {
                // Amount may be on this line or alone on the next one.
                skipNextBareAmount = moneyValues(in: line).isEmpty
                continue
            }

            let values = moneyValues(in: line)
            if skipNextBareAmount {
                skipNextBareAmount = false
                // A line that is nothing but the amount belongs to the payment
                // label above it; a line with other text is a regular line.
                let stripped = line.replacingOccurrences(of: #"[\d.,\s]"#, with: "", options: .regularExpression)
                if stripped.isEmpty && !values.isEmpty { continue }
            }
            candidates.append(contentsOf: values)
        }

        let largest = candidates.max()
        return (largest ?? 0) > 0 ? largest : nil
    }

    /// Transliterates Cyrillic → Latin, lowercases and strips diacritics, so
    /// keyword checks work on both scripts ("Назив" → "naziv", "Плаћено" →
    /// "placeno"). Serbian receipts freely mix the two.
    private static func latinFolded(_ text: String) -> String {
        let latin = text.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? text
        return latin.lowercased().folding(options: .diacriticInsensitive, locale: .current)
    }

    /// All well-formed money amounts on a line (1.750,00 / 1750.00 / 661,95).
    /// Requires either plain digits or proper 3-digit thousands groups before a
    /// 2-decimal ending, so garbage like "12.08.09.60" is rejected.
    private static func moneyValues(in text: String) -> [Decimal] {
        let pattern = #"(?<![\d.,])(?:\d{1,3}(?:[.,]\d{3})+|\d+)[.,]\d{2}(?![\d.,])"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        return matches.compactMap { match -> Decimal? in
            guard let range = Range(match.range, in: text) else { return nil }
            return normalizeAmount(String(text[range]))
        }
    }
    
    /// Parses line items. Internal (not private) so tests can exercise it
    /// with raw OCR lines directly.
    static func parseLineItems(from lines: [String]) -> [ParsedReceiptItem] {
        var items: [ParsedReceiptItem] = []

        print("🔍 Looking for items section...")

        // Find items section - look for various header patterns. latinFolded
        // handles Cyrillic receipts ("Артикли" → "artikli").
        var itemsStart: Int?
        for (index, line) in lines.enumerated() {
            let folded = latinFolded(line)

            if folded.contains("artikl") ||
               folded.contains("naziv") ||
               folded.contains("naeiv") || // OCR error for "naziv" (Cyrillic э)
               folded.contains("promet") {
                itemsStart = index
                print("✅ Found items header at line \(index): \(line)")
                break
            }
        }

        guard let start = itemsStart else {
            print("⚠️ Could not find items section header")
            return []
        }

        // Find end of items section - look for summary section
        var itemsEnd: Int?
        for (index, line) in lines.enumerated() where index > start {
            let folded = latinFolded(line)

            // End markers - be more specific to avoid false positives
            if (folded.contains("oznaka") && !folded.contains("pdv")) ||
               (folded.contains("ukupan") && folded.contains("iznos") && !folded.contains("artikl")) ||
               folded.contains("stopa") {
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
        
        print("  Starting item parsing from line \(i)")

        // Column-header / noise line: EVERY word on it is a known header word
        // ("Назив Цена Кол. Укупно" → header; "KLAS RUZA / KOM" → item, since
        // "klas" and "ruza" are not header words). Word-level matching on the
        // transliterated line — substring matching would eat item names like
        // "PECENA PAPRIKA" (contains "cena").
        func isHeaderWord(_ s: String) -> Bool {
            let headers = ["naziv", "cena", "kol", "kal", "kolicina", "ukupno", "artikl", "jed",
                           "kom", "barkod", "sifra", "konobar", "kasir", "esir", "promet",
                           "prodaja", "brojac", "pdv", "rsd", "din"]
            let words = latinFolded(s)
                .split { !$0.isLetter && !$0.isNumber }
                .map(String.init)
                .filter { $0.count >= 2 && $0.contains(where: \.isLetter) }
            guard !words.isEmpty else { return false }
            return words.allSatisfy { word in
                headers.contains { word == $0 || word.hasPrefix($0) }
            }
        }
        // A summary/total marker means we've left the items section.
        func isSummaryMarker(_ s: String) -> Bool {
            let l = latinFolded(s)
            return (l.contains("ukup") && l.contains("iznos")) || l.contains("gotovin") ||
                   l.contains("kartic") || l.contains("placen") || l.contains("povrat") ||
                   l.contains("oznaka") || l.contains("porez") || l.contains("stopa")
        }
        // 2-decimal token = money; 3-decimal token = quantity.
        func moneyValue(_ s: String) -> Decimal? {
            let t = s.trimmingCharacters(in: .whitespaces)
            guard t.range(of: #"^\d[\d.,]*\d$"#, options: .regularExpression) != nil else { return nil }
            if t.range(of: #"[.,]\d{3}$"#, options: .regularExpression) != nil { return nil } // quantity
            return normalizeAmount(t)
        }
        func quantityValue(_ s: String) -> Double? {
            let t = s.trimmingCharacters(in: .whitespaces)
            guard t.range(of: #"^\d+[.,]\d{3}$"#, options: .regularExpression) != nil else { return nil }
            return Double(t.replacingOccurrences(of: ",", with: "."))
        }
        func cleanName(_ s: String) -> String {
            s.replacingOccurrences(of: #"(\s*\([^)]*\))+\s*$"#, with: "", options: .regularExpression)
                // Barcodes/PLU codes printed before the product name.
                .replacingOccurrences(of: #"\b\d{8,}\b"#, with: "", options: .regularExpression)
                .replacingOccurrences(of: #"\s{2,}"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespaces)
        }

        struct ItemDraft { var name: String; var monies: [Decimal]; var qty: Double }
        var current: ItemDraft?

        func flush() {
            defer { current = nil }
            guard let d = current, !d.monies.isEmpty else { return }
            let name = cleanName(d.name)
            guard !name.isEmpty, name.rangeOfCharacter(from: .letters) != nil else { return }
            let lineTotal = d.monies.last ?? 0
            let unit = d.monies.first ?? lineTotal
            items.append(ParsedReceiptItem(name: name, quantity: d.qty > 0 ? d.qty : 1.0,
                                           unitPrice: unit, lineTotal: lineTotal))
        }

        while i < end {
            let line = lines[i].trimmingCharacters(in: .whitespaces)
            i += 1

            if line.isEmpty || line.contains("===") || line.contains("---") || line.contains("____") { continue }
            if isSummaryMarker(line) { break } // totals section may appear before the detected end
            // Tax-rate label like "(11)", "(Ђ)" on its own line.
            if line.range(of: #"^\([^)]*\)$"#, options: .regularExpression) != nil { continue }

            if let money = moneyValue(line) {
                current?.monies.append(money)
                continue
            }
            if let qty = quantityValue(line) {
                current?.qty = qty
                continue
            }
            if isHeaderWord(line) { continue }
            guard line.rangeOfCharacter(from: .letters) != nil else { continue } // stray symbols

            if var draft = current, draft.monies.isEmpty {
                // Name wrapped across lines — append.
                draft.name += " " + line
                current = draft
            } else {
                // A new item begins.
                flush()
                current = ItemDraft(name: line, monies: [], qty: 1.0)
            }
        }
        flush()
        
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
    
    /// Extracts a decimal amount from a line. Finds all numeric tokens
    /// (any number of digits, "." or "," separators) and returns the last one
    /// normalized — amounts are typically right-aligned on receipts.
    private static func extractDecimal(from text: String) -> Decimal? {
        let pattern = #"\d[\d.,]*\d|\d"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
        let values = matches.compactMap { match -> Decimal? in
            guard let range = Range(match.range, in: text) else { return nil }
            return normalizeAmount(String(text[range]))
        }
        return values.last
    }

    /// Backwards-compatible alias used by item/price parsing.
    private static func parseDecimal(from string: String) -> Decimal? {
        normalizeAmount(string)
    }

    /// Normalizes a numeric token into a Decimal, tolerant of both Serbian
    /// (1.234,56) and English (1,234.56) grouping, plain integers, and plain
    /// decimals (1750.00). Rule: when both separators are present the LAST one
    /// is the decimal separator; a lone separator with exactly two trailing
    /// digits is decimal, otherwise it is thousands grouping.
    private static func normalizeAmount(_ raw: String) -> Decimal? {
        var s = raw.filter { $0.isNumber || $0 == "." || $0 == "," }
        guard s.contains(where: \.isNumber) else { return nil }

        let hasDot = s.contains(".")
        let hasComma = s.contains(",")

        if hasDot && hasComma {
            if s.lastIndex(of: ",")! > s.lastIndex(of: ".")! {
                // comma is the decimal separator
                s = s.replacingOccurrences(of: ".", with: "").replacingOccurrences(of: ",", with: ".")
            } else {
                // dot is the decimal separator
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if hasComma {
            let parts = s.split(separator: ",", omittingEmptySubsequences: false)
            if parts.count == 2, parts.last?.count == 2 {
                s = s.replacingOccurrences(of: ",", with: ".")
            } else {
                s = s.replacingOccurrences(of: ",", with: "")
            }
        } else if hasDot {
            let parts = s.split(separator: ".", omittingEmptySubsequences: false)
            if !(parts.count == 2 && parts.last?.count == 2) {
                // not a plain decimal → treat dots as thousands grouping
                s = s.replacingOccurrences(of: ".", with: "")
            }
        }

        return Decimal(string: s)
    }
    
    /// Parses receipt number
    private static func parseReceiptNumber(from lines: [String]) -> String {
        // Primary: the PFR receipt number has a distinctive shape —
        // two alphanumeric blocks plus a counter, e.g. "96J62P13-96J62P13-26589".
        // Match it directly regardless of how the label OCR'd.
        let pfrPattern = #"\b[A-Z0-9]{6,}-[A-Z0-9]{6,}-\d{2,}\b"#
        if let regex = try? NSRegularExpression(pattern: pfrPattern) {
            for line in lines {
                if let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
                   let range = Range(match.range, in: line) {
                    let number = String(line[range])
                    print("  Extracted PFR receipt number (signature): \(number)")
                    return number
                }
            }
        }

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

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
