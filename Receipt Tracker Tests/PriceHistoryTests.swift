//
//  PriceHistoryTests.swift
//  Receipt Tracker Tests
//
//  Logic tests for product matching and price-change computation.
//

import Testing
import Foundation
import SwiftData
@testable import Receipt_Tracker

// Serialized + in-memory container: the receipt↔item inverse relationship is
// only wired once models are inserted into a ModelContext, and container
// creation is not safe to run concurrently across tests.
@Suite(.serialized)
@MainActor
struct PriceHistoryTests {

    private let context: ModelContext

    init() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Receipt.self, configurations: config)
        context = ModelContext(container)
    }

    // MARK: - Helpers

    private func makeReceipt(merchant: String,
                             daysAgo: Int,
                             url: String = "https://suf.purs.gov.rs/v/?vl=test",
                             items: [ReceiptItem]) -> Receipt {
        let receipt = Receipt(
            url: url,
            merchantName: merchant,
            merchantAddress: "",
            merchantCity: "",
            timestamp: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!,
            totalAmount: items.reduce(Decimal(0)) { $0 + $1.lineTotal },
            totalTax: 0,
            paymentMethod: "",
            receiptNumber: "",
            cashRegisterNumber: "",
            items: items
        )
        context.insert(receipt)
        return receipt
    }

    private func item(_ name: String, _ price: Decimal) -> ReceiptItem {
        ReceiptItem(name: name, quantity: 1, unitPrice: price, lineTotal: price)
    }

    // MARK: - Normalization

    @Test func normalizeCollapsesPunctuationAndCase() {
        #expect(PriceHistory.normalize("MLEKO SV. 2,8% 1L") == "mleko sv 2 8 1l")
        #expect(PriceHistory.normalize("Mleko  sv 2.8%   1l") == "mleko sv 2 8 1l")
        #expect(PriceHistory.normalize("  Jogurt   ") == "jogurt")
    }

    @Test func normalizeFoldsDiacritics() {
        #expect(PriceHistory.normalize("Kačkavalj") == PriceHistory.normalize("Kackavalj"))
    }

    // MARK: - Comparability

    @Test func onlyQRReceiptsAreComparable() {
        let qr = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [])
        let ocr = makeReceipt(merchant: "LIDL", daysAgo: 0, url: "ocr://receipt/abc", items: [])
        let manual = makeReceipt(merchant: "Pijaca", daysAgo: 0, url: "", items: [])
        #expect(PriceHistory.isComparable(qr))
        #expect(!PriceHistory.isComparable(ocr))
        #expect(!PriceHistory.isComparable(manual))
    }

    // MARK: - Change

    @Test func changeAgainstMostRecentEarlierPurchase() {
        let old = makeReceipt(merchant: "LIDL SRBIJA KD", daysAgo: 60,
                              items: [item("Mleko 1L", 99)])
        let mid = makeReceipt(merchant: "LIDL SRBIJA KD", daysAgo: 30,
                              items: [item("Mleko 1L", 105)])
        let newest = makeReceipt(merchant: "LIDL SRBIJA KD", daysAgo: 0,
                                 items: [item("Mleko 1L", 119.9)])
        let receipts = [newest, old, mid]

        let change = PriceHistory.change(for: newest.items[0], in: receipts)
        #expect(change != nil)
        #expect(change?.previousPrice == 105)
        #expect(change?.isIncrease == true)
        #expect(change?.percentText == "14")
    }

    @Test func noChangeForFirstPurchase() {
        let only = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [item("Mleko 1L", 99)])
        #expect(PriceHistory.change(for: only.items[0], in: [only]) == nil)
    }

    @Test func noChangeWhenPriceIsSame() {
        let old = makeReceipt(merchant: "LIDL", daysAgo: 30, items: [item("Mleko 1L", 99)])
        let new = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [item("Mleko 1L", 99)])
        #expect(PriceHistory.change(for: new.items[0], in: [old, new]) == nil)
    }

    @Test func differentChainsDoNotMix() {
        let lidl = makeReceipt(merchant: "LIDL SRBIJA KD", daysAgo: 30, items: [item("Mleko 1L", 99)])
        let maxi = makeReceipt(merchant: "DELHAIZE SERBIA DOO", daysAgo: 0, items: [item("Mleko 1L", 120)])
        #expect(PriceHistory.change(for: maxi.items[0], in: [lidl, maxi]) == nil)
    }

    @Test func ocrReceiptsExcludedFromHistory() {
        let qr = makeReceipt(merchant: "LIDL", daysAgo: 30, items: [item("Mleko 1L", 99)])
        let ocr = makeReceipt(merchant: "LIDL", daysAgo: 15, url: "ocr://receipt/x",
                              items: [item("Mleko 1L", 500)])
        let new = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [item("Mleko 1L", 105)])

        let change = PriceHistory.change(for: new.items[0], in: [qr, ocr, new])
        #expect(change?.previousPrice == 99)
    }

    @Test func subPercentChangeShowsOneDecimal() {
        let old = makeReceipt(merchant: "LIDL", daysAgo: 30, items: [item("Ulje 1L", 500)])
        let new = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [item("Ulje 1L", 502)])
        let change = PriceHistory.change(for: new.items[0], in: [old, new])
        #expect(change?.percentText == "0,4")
    }

    @Test func historySortedOldestFirst() {
        let a = makeReceipt(merchant: "LIDL", daysAgo: 60, items: [item("Mleko 1L", 90)])
        let b = makeReceipt(merchant: "LIDL", daysAgo: 30, items: [item("Mleko 1L", 100)])
        let c = makeReceipt(merchant: "LIDL", daysAgo: 0, items: [item("Mleko 1L", 110)])

        let history = PriceHistory.history(for: c.items[0], in: [c, a, b])
        #expect(history.map(\.unitPrice) == [90, 100, 110])
    }
}
