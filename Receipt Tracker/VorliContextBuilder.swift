//
//  VorliContextBuilder.swift
//  Receipt Tracker
//
//  Serializes SwiftData receipts and budget entries into compact JSON
//  suitable for injection into Claude API prompts.
//

import Foundation

struct VorliContextBuilder {

    // MARK: - JSON models (Encodable only — no SwiftData dependency in output)

    private struct ReceiptJSON: Encodable {
        let prodavnica: String
        let datum: String
        let vreme: String
        let ukupno_rsd: Double
        let stavke: [ItemJSON]
    }

    private struct ItemJSON: Encodable {
        let naziv: String
        let cena: Double
        let kolicina: Double
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    // MARK: - Build context string

    /// Builds a JSON context string for a REPORT or SEARCH request.
    /// - Parameters:
    ///   - currentReceipts: Receipts for the primary period (e.g. current month/week).
    ///   - previousReceipts: Receipts for comparison period (previous month/week). Pass empty for search.
    ///   - requestType: One of REPORT | PLAN | PRETRAGA
    static func build(
        currentReceipts: [Receipt],
        previousReceipts: [Receipt] = [],
        requestType: String = "REPORT"
    ) -> String {
        let currentJSON = currentReceipts.map { encode($0) }
        let previousJSON = previousReceipts.map { encode($0) }

        var dict: [String: Any] = [
            "tip_zahteva": requestType,
            "racuni_period": toJSONArray(currentJSON)
        ]

        if !previousJSON.isEmpty {
            dict["racuni_prethodni"] = toJSONArray(previousJSON)
        }

        guard let data = try? JSONSerialization.data(withJSONObject: dict, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8)
        else { return "" }

        return string
    }

    // MARK: - Period helpers

    static func receiptsForCurrentMonth(from receipts: [Receipt]) -> [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        return receipts.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month) }
    }

    static func receiptsForPreviousMonth(from receipts: [Receipt]) -> [Receipt] {
        let calendar = Calendar.current
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: Date()) else { return [] }
        return receipts.filter { calendar.isDate($0.timestamp, equalTo: previousMonth, toGranularity: .month) }
    }

    static func receiptsForCurrentWeek(from receipts: [Receipt]) -> [Receipt] {
        let calendar = Calendar.current
        let now = Date()
        return receipts.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear) }
    }

    static func receiptsForPreviousWeek(from receipts: [Receipt]) -> [Receipt] {
        let calendar = Calendar.current
        guard let previousWeek = calendar.date(byAdding: .weekOfYear, value: -1, to: Date()) else { return [] }
        return receipts.filter { calendar.isDate($0.timestamp, equalTo: previousWeek, toGranularity: .weekOfYear) }
    }

    // MARK: - Private

    private static func encode(_ receipt: Receipt) -> ReceiptJSON {
        let stavke = receipt.items.map {
            ItemJSON(
                naziv: $0.name,
                cena: Double(truncating: $0.lineTotal as NSDecimalNumber),
                kolicina: $0.quantity
            )
        }
        return ReceiptJSON(
            prodavnica: receipt.merchantName,
            datum: dateFormatter.string(from: receipt.timestamp),
            vreme: timeFormatter.string(from: receipt.timestamp),
            ukupno_rsd: Double(truncating: receipt.totalAmount as NSDecimalNumber),
            stavke: stavke
        )
    }

    private static func toJSONArray(_ items: [ReceiptJSON]) -> [[String: Any]] {
        items.compactMap { item -> [String: Any]? in
            guard let data = try? JSONEncoder().encode(item),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            else { return nil }
            return dict
        }
    }
}
