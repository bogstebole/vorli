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
            .monoNavigationTitle("Fiksni troškovi")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        TablerIcon("x", size: 20)
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        showAdd = true
                    } label: {
                        TablerIcon("plus", size: 20)
                            .foregroundStyle(.primary)
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
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
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
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(MoneyFormat.grouped(cost.iznos) + " RSD")
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
                        Label {
                            Text("Obriši")
                        } icon: {
                            TablerIcon("trash", size: 16)
                        }
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
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed

    private var formattedTotal: String {
        let total = fixedCosts.filter(\.isActive).reduce(Decimal(0)) { $0 + $1.iznos }
        return MoneyFormat.grouped(total)
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
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
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
                    // Chips scroll out to the sheet's edge instead of being
                    // cut off at the row's inset.
                    .scrollClipDisabled()
                    .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
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
                            let formatted = MoneyFormat.grouped(newValue)
                            if formatted != newValue { displayText = formatted }
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
            .monoNavigationTitle(cost == nil ? "Novi trošak" : "Izmeni trošak")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        TablerIcon("x", size: 20)
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { save() } label: {
                        TablerIcon("check", size: 20)
                            .foregroundStyle(.primary)
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if let cost {
                    naziv = cost.naziv
                    displayText = MoneyFormat.grouped(cost.iznos)
                    isActive = cost.isActive
                } else {
                    nameFocused = true
                }
            }
        }
    }

    /// Whole dinars, as everywhere else in the app.
    private var amount: Decimal? {
        Decimal(string: displayText.filter(\.isNumber))
    }

    private var isValid: Bool {
        guard let amount, amount > 0 else { return false }
        return !naziv.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() {
        guard let amount, amount > 0 else { return }
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
}
