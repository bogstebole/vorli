//
//  CategoryPickerSheet.swift
//  Receipt Tracker
//
//  Assigns a category to a merchant. The category lives on the merchant, not
//  the receipt — one choice covers every receipt of that chain, past and
//  future. Never assigned automatically; the user decides.
//

import SwiftUI
import SwiftData

struct CategoryPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let merchantName: String

    @Query private var categories: [MerchantCategory]
    @State private var customName: String = ""

    private var merchantKey: String { PriceHistory.merchantKey(merchantName) }
    private var existing: MerchantCategory? {
        categories.first { $0.merchantKey == merchantKey }
    }

    /// Presets plus every custom category the user has ever assigned —
    /// type "Pekara" once and it becomes a first-class option everywhere.
    private var allOptions: [String] {
        let custom = Set(categories.map(\.name)).subtracting(MerchantCategory.presets)
        return MerchantCategory.presets + custom.sorted()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ForEach(allOptions, id: \.self) { preset in
                        Button {
                            assign(preset)
                        } label: {
                            HStack {
                                Text(preset)
                                    .font(.system(.subheadline, design: .monospaced))
                                    .foregroundStyle(.primary)
                                Spacer()
                                if existing?.name == preset {
                                    TablerIcon("check", size: 16)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text(merchantName)
                        .font(.system(.caption, design: .monospaced))
                } footer: {
                    Text("Kategorija važi za sve račune ove prodavnice — i stare i buduće.")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    HStack(spacing: 8) {
                        TextField("Npr. Hobi", text: $customName)
                            .font(.system(.subheadline, design: .monospaced))
                        Button("Sačuvaj") {
                            let trimmed = customName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            assign(trimmed)
                        }
                        .font(.system(.caption, design: .monospaced, weight: .semibold))
                        .disabled(customName.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("Sopstvena kategorija")
                        .font(.system(.caption, design: .monospaced))
                }

                if existing != nil {
                    Section {
                        Button(role: .destructive) {
                            remove()
                        } label: {
                            Label {
                                Text("Ukloni kategoriju")
                            } icon: {
                                TablerIcon("trash", size: 16)
                            }
                            .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }
            }
            .monoNavigationTitle("Kategorija")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        TablerIcon("x", size: 18)
                            .foregroundStyle(.primary)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Actions

    private func assign(_ name: String) {
        if let existing {
            existing.name = name
        } else {
            modelContext.insert(MerchantCategory(merchantKey: merchantKey, name: name))
        }
        try? modelContext.save()
        dismiss()
    }

    private func remove() {
        if let existing { modelContext.delete(existing) }
        try? modelContext.save()
        dismiss()
    }
}
