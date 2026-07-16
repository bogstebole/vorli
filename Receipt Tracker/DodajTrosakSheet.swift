//
//  DodajTrosakSheet.swift
//  Receipt Tracker
//
//  Quick manual expense entry: the amount is the hero (big, centered,
//  keyboard up immediately), name via presets or typing, one real save
//  button. No generic form chrome.
//

import SwiftUI
import SwiftData

struct DodajTrosakSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var naziv: String = ""
    @State private var iznosDisplay: String = ""
    @State private var iznosRaw: String = ""
    @State private var datum: Date = Date()
    @FocusState private var amountFocused: Bool
    @FocusState private var nameFocused: Bool

    private let presets = ["Pijaca", "Kafa", "Prevoz", "Restoran", "Dostava", "Pokloni"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer(minLength: 12)

                // Amount — the hero of the screen
                VStack(spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        TextField("0", text: $iznosDisplay)
                            .keyboardType(.numberPad)
                            .focused($amountFocused)
                            .font(.system(size: 46, weight: .semibold, design: .monospaced))
                            .multilineTextAlignment(.center)
                            .fixedSize()
                            .onChange(of: iznosDisplay) { _, newValue in
                                let digits = newValue.filter(\.isNumber)
                                iznosRaw = digits
                                let formatted = MoneyFormat.grouped(digits)
                                if formatted != newValue { iznosDisplay = formatted }
                            }
                        Text("RSD")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Text("iznos")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity)

                // Name + presets
                VStack(spacing: 12) {
                    TextField("Naziv (npr. Pijaca)", text: $naziv)
                        .focused($nameFocused)
                        .font(.system(.body, design: .monospaced))
                        .multilineTextAlignment(.center)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 16)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                        .padding(.horizontal, 32)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                presetChip(preset)
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                    .scrollClipDisabled()
                }

                // Date
                HStack {
                    Text("Datum")
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    DatePicker("", selection: $datum, displayedComponents: .date)
                        .labelsHidden()
                }
                .padding(.horizontal, 32)

                Spacer()
            }
            .safeAreaInset(edge: .bottom) {
                Button {
                    save()
                } label: {
                    Text("Sačuvaj trošak")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.primary)
                .disabled(!isValid)
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }
            .navigationTitle("Dodaj trošak")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .onAppear { amountFocused = true }
        }
    }

    private func presetChip(_ preset: String) -> some View {
        let selected = naziv == preset
        return Group {
            if selected {
                Button {
                    naziv = ""
                } label: {
                    presetLabel(preset, selected: true)
                }
                .buttonStyle(.glassProminent)
                .tint(.primary)
            } else {
                Button {
                    naziv = preset
                    nameFocused = false
                } label: {
                    presetLabel(preset, selected: false)
                }
                .buttonStyle(.glass)
            }
        }
    }

    private func presetLabel(_ text: String, selected: Bool) -> some View {
        Text(text)
            .font(.system(.caption, design: .monospaced, weight: selected ? .semibold : .regular))
            .foregroundStyle(selected ? Color(uiColor: .systemBackground) : .primary)
            .padding(.horizontal, 4)
    }

    private var isValid: Bool {
        guard let value = Int(iznosRaw), value > 0 else { return false }
        return !naziv.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard let amount = Decimal(string: iznosRaw), amount > 0 else { return }
        let trimmed = naziv.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let receipt = Receipt(
            url: "",
            merchantName: trimmed,
            merchantAddress: "",
            merchantCity: "",
            timestamp: datum,
            totalAmount: amount,
            totalTax: 0,
            paymentMethod: "Ručni unos",
            receiptNumber: "",
            cashRegisterNumber: ""
        )
        modelContext.insert(receipt)
        try? modelContext.save()
        dismiss()
    }
}

#Preview {
    DodajTrosakSheet()
        .modelContainer(for: [Receipt.self], inMemory: true)
}
