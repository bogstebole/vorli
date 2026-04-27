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
        
        // Update budget
        try await deductFromBudget(amount: parsed.totalAmount)
        
        // Save to SwiftData
        modelContext.insert(receipt)
        try modelContext.save()
        
        return receipt
    }
    
    /// Scans and saves a receipt from an image using OCR
    func processReceiptImage(_ image: UIImage) async throws -> Receipt {
        print("🚀 ReceiptService.processReceiptImage called")
        print("📐 Image size: \(image.size)")
        
        // Parse the receipt using OCR
        print("🔄 About to call ReceiptOCRParser.parseReceipt")
        let parsed = try await ReceiptOCRParser.parseReceipt(from: image)
        print("✅ ReceiptOCRParser returned successfully")
        
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
        
        // Update budget
        try await deductFromBudget(amount: parsed.totalAmount)
        
        // Save to SwiftData
        modelContext.insert(receipt)
        try modelContext.save()
        
        return receipt
    }
    
    /// Gets or creates the user's budget
    func getBudget() throws -> Budget {
        let descriptor = FetchDescriptor<Budget>()
        let budgets = try modelContext.fetch(descriptor)
        
        if let budget = budgets.first {
            return budget
        }
        
        // Create initial budget
        let newBudget = Budget(currentBalance: 0)
        modelContext.insert(newBudget)
        try modelContext.save()
        return newBudget
    }
    
    /// Updates the budget balance
    func updateBudget(newBalance: Decimal) throws {
        let budget = try getBudget()
        budget.currentBalance = newBalance
        budget.lastUpdated = Date()
        try modelContext.save()
    }
    
    /// Adds balance and creates a budget entry for tracking
    func addBalanceEntry(amount: Decimal) throws {
        let budget = try getBudget()
        budget.currentBalance += amount
        budget.lastUpdated = Date()
        
        // Create a budget entry to track this addition
        let entry = BudgetEntry(amount: amount, timestamp: Date())
        modelContext.insert(entry)
        
        try modelContext.save()
    }
    
    /// Fetches all budget entries sorted by date
    func fetchBudgetEntries() throws -> [BudgetEntry] {
        let descriptor = FetchDescriptor<BudgetEntry>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Deducts an amount from the budget
    private func deductFromBudget(amount: Decimal) async throws {
        let budget = try getBudget()
        budget.currentBalance -= amount
        budget.lastUpdated = Date()
        try modelContext.save()
    }
    
    /// Fetches all receipts sorted by date
    func fetchAllReceipts() throws -> [Receipt] {
        let descriptor = FetchDescriptor<Receipt>(
            sortBy: [SortDescriptor(\.timestamp, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }
    
    /// Deletes a receipt and refunds to budget
    func deleteReceipt(_ receipt: Receipt) throws {
        // Refund to budget
        let budget = try getBudget()
        budget.currentBalance += receipt.totalAmount
        budget.lastUpdated = Date()
        
        // Delete receipt
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
