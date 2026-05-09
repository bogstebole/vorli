//
//  AddBalanceSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct AddBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onAdd: (Decimal) -> Void

    @State private var displayText: String = ""
    @State private var rawDigits: String = ""
    @FocusState private var isAmountFocused: Bool

    @AppStorage("monthlyIncomeAmount") private var storedAmount: String = ""
    @AppStorage("monthlyIncomeAutoAdd") private var autoAdd: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("0", text: $displayText)
                        .keyboardType(.numberPad)
                        .focused($isAmountFocused)
                        .font(.system(.subheadline, design: .monospaced))
                        .onChange(of: displayText) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            let reformatted = formatted(digits)
                            rawDigits = digits
                            if reformatted != newValue {
                                displayText = reformatted
                            }
                        }
                } header: {
                    Text("Iznos (RSD)")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    Toggle(isOn: $autoAdd) {
                        Text("Automatski dodaj svaki mesec")
                            .font(.system(.subheadline, design: .monospaced))
                    }
                } footer: {
                    Text("Kada je uključeno, iznos se automatski dodaje na početku svakog meseca.")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .navigationTitle("Mesečna zarada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(.body, weight: .medium))
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        Image(systemName: "checkmark")
                            .font(.system(.body, weight: .semibold))
                    }
                    .disabled(!isValidAmount)
                }
            }
            .onAppear {
                if !storedAmount.isEmpty {
                    rawDigits = storedAmount
                    displayText = formatted(storedAmount)
                }
                isAmountFocused = true
            }
        }
    }

    private var isValidAmount: Bool {
        guard let value = Int(rawDigits) else { return false }
        return value > 0
    }

    private func formatted(_ digits: String) -> String {
        guard !digits.isEmpty else { return "" }
        let reversed = Array(digits.reversed())
        var groups: [String] = []
        var chunk = ""
        for (i, char) in reversed.enumerated() {
            chunk.append(char)
            if (i + 1) % 3 == 0 && i + 1 < reversed.count {
                groups.append(String(chunk.reversed()))
                chunk = ""
            }
        }
        if !chunk.isEmpty { groups.append(String(chunk.reversed())) }
        return groups.reversed().joined(separator: ".")
    }

    private func save() {
        guard let amount = Decimal(string: rawDigits), amount > 0 else { return }

        if autoAdd {
            storedAmount = rawDigits
            MonthlyIncomeScheduler.recordAutoAdd()
        } else {
            storedAmount = ""
        }

        onAdd(amount)
        dismiss()
    }
}
