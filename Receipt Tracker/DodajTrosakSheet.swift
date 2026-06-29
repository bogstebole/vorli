//
//  DodajTrosakSheet.swift
//  Receipt Tracker
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
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Naziv (npr. Pijaca)", text: $naziv)
                        .font(.system(.subheadline, design: .monospaced))
                        .focused($nameFocused)
                } header: {
                    Text("Naziv")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    TextField("0", text: $iznosDisplay)
                        .keyboardType(.numberPad)
                        .font(.system(.subheadline, design: .monospaced))
                        .onChange(of: iznosDisplay) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            iznosRaw = digits
                            let formatted = MoneyFormat.grouped(digits)
                            if formatted != newValue { iznosDisplay = formatted }
                        }
                } header: {
                    Text("Iznos (RSD)")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    DatePicker("Datum", selection: $datum, displayedComponents: .date)
                        .font(.system(.subheadline, design: .monospaced))
                }
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
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(.body, weight: .semibold))
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear { nameFocused = true }
        }
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
