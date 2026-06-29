//
//  FiksniTroskoviSheet.swift
//  Receipt Tracker
//

import SwiftUI
import SwiftData

struct FiksniTroskoviSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \FixedCost.createdAt) private var fixedCosts: [FixedCost]

    @State private var showAdd = false
    @State private var editingCost: FixedCost?

    var body: some View {
        NavigationStack {
            Form {
                if !fixedCosts.isEmpty {
                    totalSection
                    listSection
                } else {
                    emptySection
                }
            }
            .navigationTitle("Fiksni troškovi")
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
                        showAdd = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                FixedCostEditSheet(cost: nil)
            }
            .sheet(item: $editingCost) { cost in
                FixedCostEditSheet(cost: cost)
            }
        }
    }

    // MARK: - Sections

    private var totalSection: some View {
        Section {
            HStack {
                Text("Ukupno mesečno")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formattedTotal + " RSD")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            }
        } footer: {
            Text("Automatski se oduzima od zarade svakog meseca.")
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var listSection: some View {
        Section {
            ForEach(fixedCosts) { cost in
                Button {
                    editingCost = cost
                } label: {
                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cost.naziv)
                                .font(.system(.subheadline, design: .monospaced))
                                .foregroundStyle(cost.isActive ? .primary : .secondary)
                            if !cost.isActive {
                                Text("Pauzirano")
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        Text(formatted(amountDigits(cost.iznos)) + " RSD")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(cost.isActive ? .primary : .secondary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(cost)
                    } label: {
                        Label("Obriši", systemImage: "trash")
                    }
                }
            }
        }
    }

    private var emptySection: some View {
        Section {
            VStack(spacing: 8) {
                Text("Nema fiksnih troškova.")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("Dodaj obavezne mesečne troškove (stan, računi, pretplate) i automatski se oduzimaju svakog meseca.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed

    private var formattedTotal: String {
        let total = fixedCosts.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.iznos }
        return formatted(amountDigits(total))
    }

    // MARK: - Helpers

    private func amountDigits(_ value: Decimal) -> String {
        String(NSDecimalNumber(decimal: value).int64Value)
    }

    private func formatted(_ digits: String) -> String {
        let onlyDigits = digits.filter(\.isNumber)
        guard !onlyDigits.isEmpty else { return "0" }
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

    private func delete(_ cost: FixedCost) {
        modelContext.delete(cost)
        try? modelContext.save()
    }
}

// MARK: - Add / Edit

struct FixedCostEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let cost: FixedCost?

    private let presets = [
        "Struja", "Kirija", "Kredit", "Namirnice", "Internet",
        "Telefon", "Voda", "Grejanje", "Pretplate", "Osiguranje"
    ]

    @State private var naziv: String = ""
    @State private var displayText: String = ""
    @State private var rawDigits: String = ""
    @State private var isActive: Bool = true
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(presets, id: \.self) { preset in
                                let selected = naziv == preset
                                Button {
                                    naziv = selected ? "" : preset
                                    nameFocused = false
                                } label: {
                                    Text(preset)
                                        .font(.system(.subheadline, design: .monospaced))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 9)
                                        .background(
                                            selected
                                                ? Color.accentColor.opacity(0.18)
                                                : Color.secondary.opacity(0.12)
                                        )
                                        .foregroundStyle(selected ? Color.accentColor : .primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                    .listRowBackground(Color.clear)
                } header: {
                    Text("Brzi izbor")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    TextField("Naziv (npr. Stan)", text: $naziv)
                        .font(.system(.subheadline, design: .monospaced))
                        .focused($nameFocused)
                } header: {
                    Text("Naziv")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    TextField("0", text: $displayText)
                        .keyboardType(.numberPad)
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

                if cost != nil {
                    Section {
                        Toggle(isOn: $isActive) {
                            Text("Aktivno")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    } footer: {
                        Text("Pauzirano se ne oduzima od zarade.")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle(cost == nil ? "Novi trošak" : "Izmeni trošak")
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
                    Button { save() } label: {
                        Image(systemName: "checkmark")
                            .font(.system(.body, weight: .semibold))
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let cost {
                    naziv = cost.naziv
                    rawDigits = amountDigits(cost.iznos)
                    displayText = formatted(rawDigits)
                    isActive = cost.isActive
                } else {
                    nameFocused = true
                }
            }
        }
    }

    private var isValid: Bool {
        guard let value = Int(rawDigits), value > 0 else { return false }
        return !naziv.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard let amount = Decimal(string: rawDigits), amount > 0 else { return }
        let trimmed = naziv.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let cost {
            cost.naziv = trimmed
            cost.iznos = amount
            cost.isActive = isActive
        } else {
            let new = FixedCost(naziv: trimmed, iznos: amount, isActive: true)
            modelContext.insert(new)
        }
        try? modelContext.save()
        dismiss()
    }

    // MARK: - Helpers

    private func amountDigits(_ value: Decimal) -> String {
        String(NSDecimalNumber(decimal: value).int64Value)
    }

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
}
