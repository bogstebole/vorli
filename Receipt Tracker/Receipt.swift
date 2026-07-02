//
//  Receipt.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import Foundation
import SwiftData

@Model
final class Receipt {
    var id: UUID
    var url: String
    var merchantName: String
    var merchantAddress: String
    var merchantCity: String
    var timestamp: Date
    var totalAmount: Decimal
    var totalTax: Decimal
    var paymentMethod: String
    var receiptNumber: String
    var cashRegisterNumber: String

    @Relationship(deleteRule: .cascade, inverse: \ReceiptItem.receipt)
    var items: [ReceiptItem]

    init(
        id: UUID = UUID(),
        url: String,
        merchantName: String,
        merchantAddress: String,
        merchantCity: String,
        timestamp: Date,
        totalAmount: Decimal,
        totalTax: Decimal,
        paymentMethod: String,
        receiptNumber: String,
        cashRegisterNumber: String,
        items: [ReceiptItem] = []
    ) {
        self.id = id
        self.url = url
        self.merchantName = merchantName
        self.merchantAddress = merchantAddress
        self.merchantCity = merchantCity
        self.timestamp = timestamp
        self.totalAmount = totalAmount
        self.totalTax = totalTax
        self.paymentMethod = paymentMethod
        self.receiptNumber = receiptNumber
        self.cashRegisterNumber = cashRegisterNumber
        self.items = items
    }
}

@Model
final class ReceiptItem {
    var id: UUID
    var name: String
    var quantity: Double
    var unitPrice: Decimal
    var lineTotal: Decimal
    /// Normalized form of `name` used to match the same product across
    /// receipts (price history). Empty on records created before the feature —
    /// backfilled once at app start.
    var normalizedName: String = ""

    var receipt: Receipt?

    init(
        id: UUID = UUID(),
        name: String,
        quantity: Double,
        unitPrice: Decimal,
        lineTotal: Decimal
    ) {
        self.id = id
        self.name = name
        self.quantity = quantity
        self.unitPrice = unitPrice
        self.lineTotal = lineTotal
        self.normalizedName = PriceHistory.normalize(name)
    }
}

@Model
final class Budget {
    var id: UUID
    var currentBalance: Decimal
    var lastUpdated: Date

    init(
        id: UUID = UUID(),
        currentBalance: Decimal,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.currentBalance = currentBalance
        self.lastUpdated = lastUpdated
    }
}

@Model
final class BudgetEntry {
    var id: UUID
    var amount: Decimal
    var timestamp: Date
    var note: String

    init(
        id: UUID = UUID(),
        amount: Decimal,
        timestamp: Date = Date(),
        note: String = ""
    ) {
        self.id = id
        self.amount = amount
        self.timestamp = timestamp
        self.note = note
    }
}

@Model
final class SavingsGoal {
    var naziv: String
    var ciljniIznos: Decimal
    var rok: Date

    init(naziv: String = "", ciljniIznos: Decimal = 0, rok: Date = Date()) {
        self.naziv = naziv
        self.ciljniIznos = ciljniIznos
        self.rok = rok
    }
}

@Model
final class Wish {
    var id: UUID
    var naziv: String
    var cilj: Decimal
    var usteceno: Decimal
    var rok: Date?
    var createdAt: Date
    var isArchived: Bool

    init(
        id: UUID = UUID(),
        naziv: String = "",
        cilj: Decimal = 0,
        usteceno: Decimal = 0,
        rok: Date? = nil,
        createdAt: Date = Date(),
        isArchived: Bool = false
    ) {
        self.id = id
        self.naziv = naziv
        self.cilj = cilj
        self.usteceno = usteceno
        self.rok = rok
        self.createdAt = createdAt
        self.isArchived = isArchived
    }
}

@Model
final class FixedCost {
    var id: UUID
    var naziv: String
    var iznos: Decimal
    var isActive: Bool
    var createdAt: Date

    init(
        id: UUID = UUID(),
        naziv: String = "",
        iznos: Decimal = 0,
        isActive: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.naziv = naziv
        self.iznos = iznos
        self.isActive = isActive
        self.createdAt = createdAt
    }
}
