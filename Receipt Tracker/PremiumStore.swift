//
//  PremiumStore.swift
//  Receipt Tracker
//
//  StoreKit 2 premium entitlement. No server: Apple cryptographically
//  verifies transactions on-device via Transaction.currentEntitlements.
//
//  Free tier: unlimited scanning + current and previous calendar month.
//  Premium: full history, item price history, dashboard category breakdown.
//

import Foundation
import StoreKit

@MainActor
@Observable
final class PremiumStore {

    enum ProductID {
        static let monthly = "bogste.ReceiptTracker.premium.monthly"
        static let yearly = "bogste.ReceiptTracker.premium.yearly"
        static let lifetime = "bogste.ReceiptTracker.premium.lifetime"
        static let all: Set<String> = [monthly, yearly, lifetime]
    }

    /// True when a verified StoreKit entitlement exists.
    private(set) var hasEntitlement = false

    #if DEBUG
    /// Dev-only override so daily development use isn't gated — the developer
    /// runs debug builds from the home screen where local StoreKit test
    /// purchases are not visible. Compiled out of release builds entirely.
    var debugPremiumOverride: Bool = UserDefaults.standard.bool(forKey: "debugPremiumOverride") {
        didSet { UserDefaults.standard.set(debugPremiumOverride, forKey: "debugPremiumOverride") }
    }
    #endif

    var isPremium: Bool {
        #if DEBUG
        if debugPremiumOverride { return true }
        #endif
        return hasEntitlement
    }

    /// Sorted by price ascending (monthly, yearly, lifetime).
    private(set) var products: [Product] = []
    private(set) var isLoadingProducts = false
    private(set) var purchaseInFlight = false
    var lastError: String?

    // Created once at app root and lives for the app's lifetime, so the
    // transaction listener task is never cancelled.
    private var updatesTask: Task<Void, Never>?

    init() {
        updatesTask = Task { await listenForTransactionUpdates() }
        Task {
            await refreshEntitlement()
            await loadProducts()
        }
    }

    // MARK: - Products

    func loadProducts() async {
        guard products.isEmpty, !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }
        do {
            products = try await Product.products(for: ProductID.all)
                .sorted { $0.price < $1.price }
        } catch {
            debugLog("💳 Failed to load products: \(error)")
            lastError = "Proizvodi trenutno nisu dostupni. Pokušaj kasnije."
        }
    }

    // MARK: - Purchase / Restore

    func purchase(_ product: Product) async {
        guard !purchaseInFlight else { return }
        purchaseInFlight = true
        defer { purchaseInFlight = false }
        lastError = nil

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlement()
            case .userCancelled, .pending:
                break
            @unknown default:
                break
            }
        } catch {
            debugLog("💳 Purchase failed: \(error)")
            lastError = "Kupovina nije uspela. Pokušaj ponovo."
        }
    }

    func restorePurchases() async {
        lastError = nil
        do {
            try await AppStore.sync()
        } catch {
            debugLog("💳 Restore failed: \(error)")
        }
        await refreshEntitlement()
        if !isPremium {
            lastError = "Nije pronađena ranija kupovina."
        }
    }

    // MARK: - Entitlement

    func refreshEntitlement() async {
        var premium = false
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result,
                  ProductID.all.contains(transaction.productID),
                  transaction.revocationDate == nil else { continue }
            premium = true
        }
        hasEntitlement = premium
    }

    private func listenForTransactionUpdates() async {
        for await result in Transaction.updates {
            if case .verified(let transaction) = result {
                await transaction.finish()
            }
            await refreshEntitlement()
        }
    }

    // MARK: - Free window

    /// Whether a given month's data is viewable. Free tier always sees the
    /// current and previous calendar month (and empty future months);
    /// premium sees everything. Data older than the window is still stored
    /// and still feeds derived numbers (savings, wishes) — only the detailed
    /// view is gated.
    nonisolated static func isMonthUnlocked(_ month: Date, isPremium: Bool,
                                            calendar: Calendar = .current, now: Date = Date()) -> Bool {
        if isPremium { return true }
        guard let previousMonth = calendar.date(byAdding: .month, value: -1, to: now),
              let windowStart = calendar.date(from: calendar.dateComponents([.year, .month], from: previousMonth))
        else { return false }
        return month >= windowStart
    }
}
