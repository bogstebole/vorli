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
