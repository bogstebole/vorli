//
//  ReceiptService.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import Foundation
import SwiftData
import UIKit

/// Service for managing receipts and budget
@MainActor
class ReceiptService {
    private let modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    /// Scans and saves a receipt from a QR code URL
    func processReceipt(from url: String) async throws -> Receipt {
        // Parse the receipt
        let parsed = try await ReceiptParser.parseReceipt(from: url)
        
        // Check if receipt already exists
        let descriptor = FetchDescriptor<Receipt>(
            predicate: #Predicate { $0.url == url }
        )
        
        if (try? modelContext.fetch(descriptor).first) != nil {
            throw ReceiptError.duplicateReceipt
        }
        
        // Create receipt items
        let items = parsed.items.map { parsedItem in
            ReceiptItem(
                name: parsedItem.name,
                quantity: parsedItem.quantity,
                unitPrice: parsedItem.unitPrice,
                lineTotal: parsedItem.lineTotal
            )
        }
        
        // Create receipt
        let receipt = Receipt(
            url: parsed.url,
            merchantName: parsed.merchantName,
            merchantAddress: parsed.merchantAddress,
            merchantCity: parsed.merchantCity,
            timestamp: parsed.timestamp,
            totalAmount: parsed.totalAmount,
            totalTax: parsed.totalTax,
            paymentMethod: parsed.paymentMethod,
            receiptNumber: parsed.receiptNumber,
            cashRegisterNumber: parsed.cashRegisterNumber,
            items: items
        )
        
        // Save to SwiftData
        modelContext.insert(receipt)
        try modelContext.save()

        return receipt
    }

    /// Scans and saves a receipt from an image using OCR
    func processReceiptImage(_ image: UIImage) async throws -> Receipt {
        debugLog("🚀 ReceiptService.processReceiptImage called")
        debugLog("📐 Image size: \(image.size)")
        
        // Parse the receipt using OCR
        debugLog("🔄 About to call ReceiptOCRParser.parseReceipt")
        let parsed = try await ReceiptOCRParser.parseReceipt(from: image)
        debugLog("✅ ReceiptOCRParser returned successfully")

        return try await save(parsed: parsed)
    }

    /// Persists an already-parsed receipt (used by the OCR confirmation flow,
    /// where the user may have edited the fields before saving).
    func save(parsed: ParsedReceipt) async throws -> Receipt {
        // Check if receipt already exists (by receipt number if available)
        if !parsed.receiptNumber.isEmpty {
            let receiptNumber = parsed.receiptNumber
            let descriptor = FetchDescriptor<Receipt>(
                predicate: #Predicate { $0.receiptNumber == receiptNumber }
            )

            if (try? modelContext.fetch(descriptor).first) != nil {
                throw ReceiptError.duplicateReceipt
            }
        }

        // Create receipt items
        let items = parsed.items.map { parsedItem in
            ReceiptItem(
                name: parsedItem.name,
                quantity: parsedItem.quantity,
                unitPrice: parsedItem.unitPrice,
                lineTotal: parsedItem.lineTotal
            )
        }

        // Create receipt
        let receipt = Receipt(
            url: parsed.url,
            merchantName: parsed.merchantName,
            merchantAddress: parsed.merchantAddress,
            merchantCity: parsed.merchantCity,
            timestamp: parsed.timestamp,
            totalAmount: parsed.totalAmount,
            totalTax: parsed.totalTax,
            paymentMethod: parsed.paymentMethod,
            receiptNumber: parsed.receiptNumber,
            cashRegisterNumber: parsed.cashRegisterNumber,
            items: items
        )

        // Save to SwiftData
        modelContext.insert(receipt)
        try modelContext.save()

        return receipt
    }
    
    /// Fetches all budget entries sorted by date
    func fetchBudgetEntries() throws -> [BudgetEntry] {
        let descriptor = FetchDescriptor<BudgetEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Fetches all receipts sorted by date
    func fetchAllReceipts() throws -> [Receipt] {
        let descriptor = FetchDescriptor<Receipt>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Deletes a receipt. Balances are derived from receipts and budget
    /// entries, so no bookkeeping is needed beyond the delete itself.
    func deleteReceipt(_ receipt: Receipt) throws {
        modelContext.delete(receipt)
        try modelContext.save()
    }
}

// MARK: - Errors

enum ReceiptError: LocalizedError {
    case duplicateReceipt
    case budgetNotFound
    
    var errorDescription: String? {
        switch self {
        case .duplicateReceipt:
            return "Овај рачун је већ скениран"
        case .budgetNotFound:
            return "Буџет није пронађен"
        }
    }
}
