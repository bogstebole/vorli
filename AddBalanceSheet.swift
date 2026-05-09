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

    @State private var amountText: String = ""
    @FocusState private var isAmountFocused: Bool

    @AppStorage("monthlyIncomeAmount") private var storedAmount: String = ""
    @AppStorage("monthlyIncomeAutoAdd") private var autoAdd: Bool = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Iznos (RSD)") {
                    TextField("0", text: $amountText)
                        .keyboardType(.decimalPad)
                        .focused($isAmountFocused)
                        .font(.system(.title3, design: .monospaced))
                }

                Section {
                    Toggle("Automatski dodaj svaki mesec", isOn: $autoAdd)
                } footer: {
                    Text("Kada je uključeno, iznos se automatski dodaje na početku svakog meseca.")
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
                    Button("Dodaj") {
                        save()
                    }
                    .disabled(!isValidAmount)
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if !storedAmount.isEmpty {
                    amountText = storedAmount
                }
                isAmountFocused = true
            }
        }
    }

    private var isValidAmount: Bool {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else {
            return false
        }
        return amount > 0
    }

    private func save() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else { return }

        if autoAdd {
            storedAmount = amountText
            MonthlyIncomeScheduler.recordAutoAdd()
        } else {
            storedAmount = ""
        }

        onAdd(amount)
        dismiss()
    }
}
