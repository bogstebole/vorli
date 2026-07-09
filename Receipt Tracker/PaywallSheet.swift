//
//  PaywallSheet.swift
//  Receipt Tracker
//
//  Premium upsell. App Review requirements live here: visible price and
//  period, auto-renewal disclosure, Restore button, and links to the
//  privacy policy and terms of use.
//

import SwiftUI
import StoreKit

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(PremiumStore.self) private var store

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    features
                    productButtons
                    restoreAndLinks
                }
                .padding(20)
            }
            .navigationTitle("Premium")
            .navigationBarTitleDisplayMode(.inline)
            .tint(.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onChange(of: store.isPremium) { _, premium in
                if premium { dismiss() }
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 44))
                .foregroundStyle(.primary)
            Text("Tvoji podaci kroz vreme")
                .font(.system(.title3, design: .monospaced, weight: .semibold))
            Text("Skeniranje i tekući mesec su besplatni zauvek. Premium otključava sve što raste sa upotrebom.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var features: some View {
        VStack(alignment: .leading, spacing: 12) {
            featureRow("calendar", "Istorija svih meseci — ne samo poslednja dva")
            featureRow("chart.line.uptrend.xyaxis", "Istorija cena artikala — vidi šta ti poskupljuje")
            featureRow("square.grid.2x2", "Potrošnja po kategorijama na kontrolnoj tabli")
            featureRow("magnifyingglass", "Pretraga kroz sve račune")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func featureRow(_ icon: String, _ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .frame(width: 22)
                .foregroundStyle(.primary)
            Text(text)
                .font(.system(.caption, design: .monospaced))
        }
    }

    @ViewBuilder
    private var productButtons: some View {
        if store.products.isEmpty {
            if store.isLoadingProducts {
                ProgressView()
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 8) {
                    Text(store.lastError ?? "Proizvodi trenutno nisu dostupni.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button("Pokušaj ponovo") {
                        Task { await store.loadProducts() }
                    }
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                }
                .padding(.vertical, 12)
            }
        } else {
            VStack(spacing: 10) {
                ForEach(store.products, id: \.id) { product in
                    productButton(product)
                }
                if let error = store.lastError {
                    Text(error)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                }
                if store.products.contains(where: { $0.type == .autoRenewable }) {
                    Text("Pretplata se automatski obnavlja dok je ne otkažeš u podešavanjima App Store naloga, najkasnije 24h pre isteka perioda.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                }
            }
        }
    }

    private func productButton(_ product: Product) -> some View {
        let highlighted = product.id == PremiumStore.ProductID.yearly
        return Button {
            Task { await store.purchase(product) }
        } label: {
            VStack(spacing: 2) {
                HStack {
                    Text(title(for: product))
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    Spacer()
                    Text(price(for: product))
                        .font(.system(.subheadline, design: .monospaced))
                }
                if let note = note(for: product) {
                    HStack {
                        Text(note)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(highlighted ? .primary : .secondary)
                        Spacer()
                    }
                }
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(highlighted ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .disabled(store.purchaseInFlight)
    }

    private var restoreAndLinks: some View {
        VStack(spacing: 12) {
            Button("Vrati kupovine") {
                Task { await store.restorePurchases() }
            }
            .font(.system(.caption, design: .monospaced, weight: .semibold))
            .foregroundStyle(.primary)

            HStack(spacing: 16) {
                Button("Politika privatnosti") { openURL(AppInfo.privacyPolicyURL) }
                Button("Uslovi korišćenja") { openURL(Self.termsURL) }
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Product display helpers

    private func title(for product: Product) -> String {
        switch product.id {
        case PremiumStore.ProductID.monthly: return "Mesečno"
        case PremiumStore.ProductID.yearly: return "Godišnje"
        case PremiumStore.ProductID.lifetime: return "Zauvek"
        default: return product.displayName
        }
    }

    private func price(for product: Product) -> String {
        switch product.id {
        case PremiumStore.ProductID.monthly: return product.displayPrice + "/mes"
        case PremiumStore.ProductID.yearly: return product.displayPrice + "/god"
        default: return product.displayPrice
        }
    }

    private func note(for product: Product) -> String? {
        switch product.id {
        case PremiumStore.ProductID.yearly:
            if product.subscription?.introductoryOffer?.paymentMode == .freeTrial {
                return "7 dana besplatno, pa se naplaćuje godišnje"
            }
            return "Naplaćuje se jednom godišnje"
        case PremiumStore.ProductID.lifetime:
            return "Jednokratna kupovina, bez pretplate"
        default:
            return nil
        }
    }
}
