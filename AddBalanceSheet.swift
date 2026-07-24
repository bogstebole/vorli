//
//  AddBalanceSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI
import SwiftData

private enum IncomeMode {
    case display, adding, editing
}

struct AddBalanceSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<BudgetEntry> { $0.note == "mesecna_zarada" },
           sort: \BudgetEntry.timestamp)
    private var allIncomeEntries: [BudgetEntry]

    @State private var mode: IncomeMode = .display
    @State private var displayText: String = ""
    @State private var rawDigits: String = ""
    @FocusState private var isInputFocused: Bool

    @AppStorage("monthlyIncomeAutoAdd") private var autoAdd: Bool = false
    @AppStorage("monthlyIncomeAmount") private var storedAmount: String = ""

    var body: some View {
        NavigationStack {
            Form {
                if hasIncome && mode == .display {
                    totalSection
                    actionsSection
                    toggleSection
                } else {
                    if hasIncome && mode == .adding {
                        currentTotalRow
                    }
                    inputSection
                    if !hasIncome {
                        toggleSection
                    }
                }
            }
            .navigationTitle("Mesečna zarada")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        if mode == .display || !hasIncome {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                mode = .display
                                displayText = ""
                                rawDigits = ""
                            }
                        }
                    } label: {
                        TablerIcon((mode == .display || !hasIncome) ? "x" : "chevron-left", size: 18)
                            .foregroundStyle(.primary)
                    }
                }

                if !hasIncome || mode != .display {
                    ToolbarItem(placement: .confirmationAction) {
                        Button { save() } label: {
                            TablerIcon("check", size: 18)
                                .foregroundStyle(.primary)
                        }
                        .disabled(!isValidAmount)
                    }
                }
            }
            .onAppear {
                if !hasIncome { isInputFocused = true }
            }
        }
    }

    // MARK: - Sections

    private var totalSection: some View {
        Section {
            VStack(spacing: 6) {
                Text(formattedTotal + " RSD")
                    .font(.system(.title2, design: .monospaced, weight: .semibold))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)

                Text(currentMonthName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 8)
            }
        }
    }

    private var actionsSection: some View {
        Section {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    mode = .adding
                    displayText = ""
                    rawDigits = ""
                    isInputFocused = true
                }
            } label: {
                Label {
                    Text("Dodaj iznos")
                } icon: {
                    TablerIcon("plus", size: 16)
                }
                .font(.system(.subheadline, design: .monospaced))
            }

            Button {
                withAnimation(.spring(response: 0.3)) {
                    mode = .editing
                    displayText = ""
                    rawDigits = ""
                    isInputFocused = true
                }
            } label: {
                Label {
                    Text("Izmeni iznos")
                } icon: {
                    TablerIcon("pencil", size: 16)
                }
                .font(.system(.subheadline, design: .monospaced))
            }

            Button(role: .destructive) {
                removeIncome()
            } label: {
                Label {
                    Text("Ukloni")
                } icon: {
                    TablerIcon("trash", size: 16)
                }
                .font(.system(.subheadline, design: .monospaced))
            }
        }
    }

    private var currentTotalRow: some View {
        Section {
            HStack {
                Text("Trenutno")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedTotal + " RSD")
                    .font(.system(.subheadline, design: .monospaced))
            }
        }
    }

    private var inputSection: some View {
        Section {
            TextField("0", text: $displayText)
                .keyboardType(.numberPad)
                .focused($isInputFocused)
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
            Text(mode == .adding ? "Dodaj iznos (RSD)" : "Iznos (RSD)")
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var toggleSection: some View {
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

    // MARK: - Computed

    private var currentMonthEntries: [BudgetEntry] {
        let calendar = Calendar.current
        return allIncomeEntries.filter {
            calendar.isDate($0.timestamp, equalTo: Date(), toGranularity: .month)
        }
    }

    private var currentTotal: Decimal {
        currentMonthEntries.reduce(0) { $0 + $1.amount }
    }

    private var formattedTotal: String {
        let intValue = NSDecimalNumber(decimal: currentTotal).int64Value
        return formatted(String(intValue))
    }

    private var hasIncome: Bool { !currentMonthEntries.isEmpty }

    private var isValidAmount: Bool {
        guard let value = Int(rawDigits) else { return false }
        return value > 0
    }

    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        formatter.locale = Locale(identifier: "sr_Latn_RS")
        return formatter.string(from: Date())
    }

    // MARK: - Helpers

    private func formatted(_ digits: String) -> String {
        let onlyDigits = digits.filter(\.isNumber)
        guard !onlyDigits.isEmpty else { return "" }
        let reversed = Array(onlyDigits.reversed())
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

    // MARK: - Actions

    private func save() {
        guard let amount = Decimal(string: rawDigits), amount > 0 else { return }

        if mode == .editing {
            for entry in currentMonthEntries { modelContext.delete(entry) }
        }

        let entry = BudgetEntry(amount: amount, timestamp: Date(), note: "mesecna_zarada")
        modelContext.insert(entry)
        try? modelContext.save()

        if autoAdd {
            storedAmount = rawDigits
            MonthlyIncomeScheduler.recordAutoAdd()
        } else {
            storedAmount = ""
        }

        withAnimation(.spring(response: 0.3)) {
            mode = .display
            displayText = ""
            rawDigits = ""
        }
    }

    private func removeIncome() {
        for entry in currentMonthEntries { modelContext.delete(entry) }
        storedAmount = ""
        try? modelContext.save()
    }
}
