//
//  SettingsSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 22. 12. 2025.
//

import SwiftUI
import SwiftData

/// App-level constants surfaced in Settings and App Store metadata.
/// ⚠️ Before submitting to TestFlight/App Store: the privacy policy page must
/// actually exist at this URL (App Store Connect requires the same link).
enum AppInfo {
    static let supportEmail = "bogstedsgn@gmail.com"
    static let privacyPolicyURL = URL(string: "https://bogstebole.github.io/vorli/privacy.html")!

    static var version: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

struct SettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @State private var showDeleteConfirmation = false
    @State private var showDeleteDone = false

    var body: some View {
        NavigationStack {
            List {
                // Data & privacy
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "iphone.and.arrow.forward.inward")
                            .foregroundStyle(.secondary)
                        Text("Svi podaci ostaju na ovom uređaju")
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    Button {
                        openURL(AppInfo.privacyPolicyURL)
                    } label: {
                        HStack {
                            Text("Politika privatnosti")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } header: {
                    Text("Privatnost")
                        .font(.system(.caption, design: .monospaced))
                } footer: {
                    Text("Računi, iznosi i kategorije se čuvaju isključivo lokalno. Aplikacija ne šalje podatke nigde.")
                        .font(.system(.caption2, design: .monospaced))
                }

                // Permissions
                Section {
                    Button {
                        if let url = URL(string: UIApplication.openSettingsURLString) {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("Dozvole aplikacije")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.system(.caption, weight: .medium))
                                .foregroundStyle(.tertiary)
                        }
                    }
                } footer: {
                    Text("Kamera se koristi samo za skeniranje QR koda i računa.")
                        .font(.system(.caption2, design: .monospaced))
                }

                // Support
                Section {
                    Button {
                        if let url = URL(string: "mailto:\(AppInfo.supportEmail)") {
                            openURL(url)
                        }
                    } label: {
                        HStack {
                            Text("Kontakt i podrška")
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(.primary)
                            Spacer()
                            Text(AppInfo.supportEmail)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Podrška")
                        .font(.system(.caption, design: .monospaced))
                }

                // Data management
                Section {
                    Button(role: .destructive) {
                        showDeleteConfirmation = true
                    } label: {
                        Label("Obriši sve podatke", systemImage: "trash")
                            .font(.system(.subheadline, design: .monospaced))
                    }
                } footer: {
                    Text("Trajno briše sve račune, zaradu, fiksne troškove, želje i kategorije sa uređaja.")
                        .font(.system(.caption2, design: .monospaced))
                }

                // About
                Section {
                    HStack {
                        Text("Verzija")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(AppInfo.version)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                } header: {
                    Text("O aplikaciji")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("Podešavanja")
            .navigationBarTitleDisplayMode(.inline)
            // List applies the accent tint to button/link rows even over an
            // explicit foregroundStyle — override the tint itself so every
            // row is monochrome (destructive stays red by role).
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
            .confirmationDialog(
                "Obriši sve podatke?",
                isPresented: $showDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Obriši sve", role: .destructive) { deleteAllData() }
                Button("Otkaži", role: .cancel) {}
            } message: {
                Text("Ova radnja je trajna i ne može da se opozove.")
            }
            .alert("Podaci obrisani", isPresented: $showDeleteDone) {
                Button("OK", role: .cancel) { dismiss() }
            }
        }
    }

    // MARK: - Actions

    private func deleteAllData() {
        // ReceiptItem rows go with their Receipt (cascade delete rule).
        try? modelContext.delete(model: Receipt.self)
        try? modelContext.delete(model: BudgetEntry.self)
        try? modelContext.delete(model: FixedCost.self)
        try? modelContext.delete(model: Wish.self)
        try? modelContext.delete(model: MerchantCategory.self)
        try? modelContext.delete(model: SavingsGoal.self)
        try? modelContext.delete(model: Budget.self)
        try? modelContext.save()
        showDeleteDone = true
    }
}

#Preview {
    SettingsSheet()
        .modelContainer(for: [Receipt.self, BudgetEntry.self, FixedCost.self, Wish.self, MerchantCategory.self], inMemory: true)
}
