//
//  PaywallSheet.swift
//  Receipt Tracker
//
//  Premium upsell, styled like the receipt detail page: monospaced,
//  centered header, section dividers, article-like rows. One selected
//  plan + one primary CTA pinned to the bottom.
//
//  App Review requirements live here: visible price and period,
//  auto-renewal disclosure, Restore button, privacy + terms links.
//

import SwiftUI
import StoreKit

struct PaywallSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Environment(PremiumStore.self) private var store

    @State private var selectedProductID: String = PremiumStore.ProductID.yearly

    private static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header

                    SectionDivider(title: "Šta dobijaš")
                    featureRows

                    SectionDivider(title: "Izaberi plan")
                    planRows

                    restoreAndLinks
                }
                .padding()
            }
            .safeAreaBar(edge: .bottom) { ctaBar }
            .monoNavigationTitle("Premium")
            .tint(.primary)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        TablerIcon("x", size: 18)
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onChange(of: store.isPremium) { _, premium in
                if premium { dismiss() }
            }
        }
    }

    // MARK: - Header (receipt-detail style)

    private var header: some View {
        VStack(spacing: 12) {
            Text("PREMIUM")
                .font(.system(.body, design: .monospaced, weight: .medium))

            Text("Otključaj celu istoriju")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)

            Text("Tekući i prošli mesec su uvek besplatni. Premium otključava sve starije od toga.")
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Features (article-row style)

    private var featureRows: some View {
        VStack(spacing: 0) {
            featureRow("Istorija svih meseci")
            featureRow("Istorija cena artikala")
            featureRow("Potrošnja po kategorijama")
            featureRow("Pretraga kroz sve račune")
        }
    }

    private func featureRow(_ text: String) -> some View {
        HStack {
            Text(text)
                .font(.system(.subheadline, design: .monospaced, weight: .medium))
            Spacer()
            TablerIcon("check", size: 16)
                .foregroundStyle(.primary)
        }
        .padding()
    }

    // MARK: - Plans

    @ViewBuilder
    private var planRows: some View {
        if store.products.isEmpty {
            if store.isLoadingProducts {
                ProgressView()
                    .padding(.vertical, 24)
            } else {
                VStack(spacing: 10) {
                    Text(store.lastError ?? "Proizvodi trenutno nisu dostupni.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Button("Pokušaj ponovo") {
                        Task { await store.loadProducts() }
                    }
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                }
                .padding(.vertical, 16)
            }
        } else {
            VStack(spacing: 8) {
                ForEach(store.products, id: \.id) { product in
                    planRow(product)
                }
            }
        }
    }

    private func planRow(_ product: Product) -> some View {
        let selected = product.id == selectedProductID
        return Button {
            selectedProductID = product.id
        } label: {
            HStack(spacing: 12) {
                TablerIcon(selected ? "circle-dot" : "circle", size: 20)
                    .foregroundStyle(selected ? .primary : .tertiary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title(for: product))
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    if let note = note(for: product) {
                        Text(note)
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(price(for: product))
                    .font(.system(.subheadline, design: .monospaced))
            }
            .padding(14)
            .background(Color(uiColor: .secondarySystemBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(selected ? Color.primary : Color.clear, lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - CTA (pinned, single primary action)

    @ViewBuilder
    private var ctaBar: some View {
        if let product = selectedProduct {
            VStack(spacing: 8) {
                Button {
                    Task { await store.purchase(product) }
                } label: {
                    Group {
                        if store.purchaseInFlight {
                            ProgressView()
                                .tint(Color(uiColor: .systemBackground))
                        } else {
                            Text(ctaTitle(for: product))
                                .font(.system(.body, design: .monospaced, weight: .semibold))
                                // The screen-level .tint(.primary) also fills
                                // the prominent glass, so the label must be
                                // the opposite color explicitly.
                                .foregroundStyle(Color(uiColor: .systemBackground))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .disabled(store.purchaseInFlight)

                Text(ctaFootnote(for: product))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)

                if let error = store.lastError, !store.products.isEmpty {
                    Text(error)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.orange)
                }
            }
            .padding(.horizontal)
            .padding(.top, 10)
            .padding(.bottom, 6)
        }
    }

    // MARK: - Restore & legal

    private var restoreAndLinks: some View {
        VStack(spacing: 16) {
            // A real capsule button — plain text didn't read as tappable.
            Button {
                Task { await store.restorePurchases() }
            } label: {
                Text("Već si platio? Povrati kupovinu")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.glass)

            HStack(spacing: 8) {
                Button {
                    openURL(AppInfo.privacyPolicyURL)
                } label: {
                    Text("Politika privatnosti").underline()
                }
                Text("·")
                Button {
                    openURL(Self.termsURL)
                } label: {
                    Text("Uslovi korišćenja").underline()
                }
            }
            .font(.system(.caption2, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 12)
    }

    // MARK: - Product display helpers

    private var selectedProduct: Product? {
        store.products.first { $0.id == selectedProductID } ?? store.products.first
    }

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
            return hasFreeTrial(product) ? "7 dana besplatno" : "Naplaćuje se jednom godišnje"
        case PremiumStore.ProductID.lifetime:
            return "Jednokratno, bez pretplate"
        default:
            return nil
        }
    }

    private func ctaTitle(for product: Product) -> String {
        switch product.id {
        case PremiumStore.ProductID.yearly where hasFreeTrial(product):
            return "Probaj 7 dana besplatno"
        case PremiumStore.ProductID.lifetime:
            return "Kupi zauvek — \(product.displayPrice)"
        default:
            return "Nastavi — \(price(for: product))"
        }
    }

    private func ctaFootnote(for product: Product) -> String {
        switch product.id {
        case PremiumStore.ProductID.monthly:
            return "Obnavlja se automatski \(product.displayPrice) mesečno dok ne otkažeš u App Store podešavanjima."
        case PremiumStore.ProductID.yearly:
            let trial = hasFreeTrial(product) ? "Posle probnog perioda obnavlja" : "Obnavlja"
            return "\(trial) se automatski \(product.displayPrice) godišnje dok ne otkažeš u App Store podešavanjima."
        default:
            return "Jednokratna kupovina. Bez pretplate, bez obnavljanja."
        }
    }

    private func hasFreeTrial(_ product: Product) -> Bool {
        product.subscription?.introductoryOffer?.paymentMode == .freeTrial
    }
}
