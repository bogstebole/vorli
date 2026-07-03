//
//  PriceHistory.swift
//  Receipt Tracker
//
//  Matches the same product across receipts of the same merchant chain and
//  computes price changes over time. Only QR receipts participate — OCR item
//  prices are too noisy and would produce false price changes.
//

import Foundation

enum PriceHistory {

    // MARK: - Matching keys

    /// Normalized product key: transliterated to Latin, lowercased, diacritics
    /// folded, punctuation collapsed to single spaces. Transliteration makes
    /// "Млеко" and "Mleko" the same key — receipts mix both scripts. The same
    /// chain prints the same name on every receipt, so this key is stable
    /// within a merchant.
    static func normalize(_ name: String) -> String {
        (name.applyingTransform(StringTransform("Any-Latin; Latin-ASCII"), reverse: false) ?? name)
            .lowercased()
            .folding(options: .diacriticInsensitive, locale: Locale(identifier: "sr_Latn_RS"))
            .map { $0.isLetter || $0.isNumber ? $0 : " " }
            .reduce(into: "") { result, char in
                if char == " " && result.hasSuffix(" ") { return }
                result.append(char)
            }
            .trimmingCharacters(in: .whitespaces)
    }

    /// Chain key from the merchant name (company name is identical across a
    /// chain's stores; only the address differs).
    static func merchantKey(_ merchantName: String) -> String {
        normalize(merchantName)
    }

    /// Only QR receipts have trustworthy item prices. OCR receipts use
    /// "ocr://…" URLs and manual entries have none.
    static func isComparable(_ receipt: Receipt) -> Bool {
        receipt.url.hasPrefix("http")
    }

    // MARK: - History

    struct Entry: Identifiable {
        let id: UUID
        let date: Date
        let unitPrice: Decimal
    }

    /// All purchases of the given item within the same merchant chain,
    /// oldest first. Includes the item itself. One entry per receipt —
    /// if a receipt lists the product twice, the first occurrence wins.
    static func history(for item: ReceiptItem, in receipts: [Receipt]) -> [Entry] {
        guard let receipt = item.receipt, isComparable(receipt) else { return [] }
        let key = itemKey(item)
        guard !key.isEmpty else { return [] }
        let chain = merchantKey(receipt.merchantName)

        return receipts
            .filter { isComparable($0) && merchantKey($0.merchantName) == chain }
            .compactMap { r -> Entry? in
                guard let match = r.items.first(where: { itemKey($0) == key && $0.unitPrice > 0 }) else {
                    return nil
                }
                return Entry(id: match.id, date: r.timestamp, unitPrice: match.unitPrice)
            }
            .sorted { $0.date < $1.date }
    }

    // MARK: - Change vs previous purchase

    struct Change {
        let previousPrice: Decimal
        let currentPrice: Decimal
        let previousDate: Date

        var isIncrease: Bool { currentPrice > previousPrice }

        /// Percent change, e.g. 14.0 for +14%, -5.2 for −5.2%.
        var percentValue: Double {
            let prev = (previousPrice as NSDecimalNumber).doubleValue
            let curr = (currentPrice as NSDecimalNumber).doubleValue
            guard prev > 0 else { return 0 }
            return (curr - prev) / prev * 100
        }

        /// Display string without sign, e.g. "14" or "0,4" for sub-1% changes
        /// (whole-number rounding would show a misleading "0").
        var percentText: String {
            let magnitude = abs(percentValue)
            if magnitude >= 0.95 {
                return String(Int(magnitude.rounded()))
            }
            return String(format: "%.1f", magnitude).replacingOccurrences(of: ".", with: ",")
        }
    }

    /// Price change of this item against the most recent earlier purchase of
    /// the same product in the same chain. Nil when there is no earlier
    /// purchase or the price is unchanged.
    static func change(for item: ReceiptItem, in receipts: [Receipt]) -> Change? {
        guard let receipt = item.receipt, item.unitPrice > 0 else { return nil }
        let previous = history(for: item, in: receipts)
            .filter { $0.date < receipt.timestamp }
            .last
        guard let previous, previous.unitPrice != item.unitPrice else { return nil }
        return Change(previousPrice: previous.unitPrice,
                      currentPrice: item.unitPrice,
                      previousDate: previous.date)
    }

    // MARK: - Helpers

    /// Falls back to normalizing on the fly for records the backfill hasn't
    /// touched yet.
    private static func itemKey(_ item: ReceiptItem) -> String {
        item.normalizedName.isEmpty ? normalize(item.name) : item.normalizedName
    }
}
