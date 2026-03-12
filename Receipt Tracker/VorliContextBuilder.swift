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

    private struct FinansijeJSON: Encodable {
        let stanje: Double
        let poslednji_unos: String
        let mesecni_prihod: Int
        let budzet_model: BudzetModelJSON
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
    ///   - budget: Optional budget model; when provided, adds balance and last-updated to "finansije" block.
    ///   - userProfile: Optional user profile; when provided, adds income and budget split to "finansije" block.
    static func build(
        currentReceipts: [Receipt],
        previousReceipts: [Receipt] = [],
        requestType: String = "REPORT",
        budget: Budget? = nil,
        userProfile: VorliUserProfile? = nil
    ) -> String {
        let currentJSON = currentReceipts.map { encode($0) }
        let previousJSON = previousReceipts.map { encode($0) }

        // Build metadata so Claude always knows the exact scope of data it's working with
        let allReceipts = currentReceipts + previousReceipts
        let sortedDates = allReceipts.map(\.timestamp).sorted()
        let meta: [String: Any] = [
            "danasnji_datum": dateFormatter.string(from: Date()),
            "ukupno_racuna_period": currentReceipts.count,
            "ukupno_racuna_prethodni": previousReceipts.count,
            "datum_najstarijeg": sortedDates.first.map { dateFormatter.string(from: $0) } ?? "N/A",
            "datum_najnovijeg": sortedDates.last.map { dateFormatter.string(from: $0) } ?? "N/A"
        ]

        var dict: [String: Any] = [
            "tip_zahteva": requestType,
            "meta": meta,
            "racuni_period": toJSONArray(currentJSON)
        ]

        if !previousJSON.isEmpty {
            dict["racuni_prethodni"] = toJSONArray(previousJSON)
        }

        // Add finansije block if budget or income data is available
        if budget != nil || (userProfile?.mesecniPrihod ?? 0) > 0 {
            var finansijeDict: [String: Any] = [:]

            if let budget {
                finansijeDict["stanje"] = Double(truncating: budget.currentBalance as NSDecimalNumber)
                finansijeDict["poslednji_unos"] = dateFormatter.string(from: budget.lastUpdated)
            }

            if let profile = userProfile {
                finansijeDict["mesecni_prihod"] = profile.mesecniPrihod
                let parsed = profile.parsedBudzetModel
                finansijeDict["budzet_model"] = [
                    "potrebe": parsed.potrebe,
                    "zabava": parsed.zabava,
                    "stednja": parsed.stednja
                ]
            }

            if !finansijeDict.isEmpty {
                dict["finansije"] = finansijeDict
            }
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
