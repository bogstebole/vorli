//
//  ListaZeljaSheet.swift
//  Receipt Tracker
//

import SwiftUI
import SwiftData

struct ListaZeljaSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @Query(filter: #Predicate<Wish> { !$0.isArchived }, sort: \Wish.createdAt)
    private var wishes: [Wish]
    @Query private var receipts: [Receipt]
    @Query private var budgetEntries: [BudgetEntry]
    @Query private var fixedCosts: [FixedCost]

    @State private var showAdd = false
    @State private var editingWish: Wish?

    var body: some View {
        NavigationStack {
            Form {
                if wishes.isEmpty {
                    emptySection
                } else {
                    summarySection
                    listSection
                }
            }
            .navigationTitle("Lista želja")
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
                    Button { showAdd = true } label: {
                        Image(systemName: "plus")
                            .font(.system(.body, weight: .semibold))
                    }
                }
            }
            .sheet(isPresented: $showAdd) { WishEditSheet(wish: nil) }
            .sheet(item: $editingWish) { wish in WishEditSheet(wish: wish) }
        }
    }

    // MARK: - Sections

    private var summarySection: some View {
        Section {
            HStack {
                Text("Ukupna ušteđevina")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MoneyFormat.signed(totalSavings) + " RSD")
                    .font(.system(.subheadline, design: .monospaced))
            }
            HStack {
                Text("Odvojeno za želje")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MoneyFormat.signed(totalReserved) + " RSD")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            }
            HStack {
                Text("Raspoloživo")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MoneyFormat.signed(available) + " RSD")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(available < 0 ? .orange : .primary)
            }
            if available < 0 {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Text("Odvojio si više nego što ti je ukupno ostalo od zarade.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        } footer: {
            Text("Ušteđevina = zbir svega što ti je ostalo na kraju svakog meseca. Raspoloživo = ušteđevina minus odvojeno za želje.")
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var listSection: some View {
        Section {
            ForEach(wishes) { wish in
                Button {
                    editingWish = wish
                } label: {
                    WishRowView(wish: wish, avgLeftover: avgLeftover)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        delete(wish)
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
                Text("Nema želja.")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text("Dodaj nešto što želiš da kupiš i prati koliko si uštedeo za to.")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 8)
        }
    }

    // MARK: - Computed

    private var totalReserved: Decimal { FinanceCalculator.totalReserved(wishes) }

    /// All-time savings: sum of monthly leftovers across every month with activity.
    private var totalSavings: Decimal {
        FinanceCalculator.totalLeftover(receipts: receipts, entries: budgetEntries, fixed: fixedCosts)
    }

    private var available: Decimal { totalSavings - totalReserved }

    private var avgLeftover: Decimal {
        FinanceCalculator.averageMonthlyLeftover(receipts: receipts, entries: budgetEntries, fixed: fixedCosts)
    }

    // MARK: - Actions

    private func delete(_ wish: Wish) {
        modelContext.delete(wish)
        try? modelContext.save()
    }
}

// MARK: - Row

struct WishRowView: View {
    let wish: Wish
    let avgLeftover: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(wish.naziv)
                    .font(.system(.subheadline, design: .monospaced))
                Spacer()
                Text("\(MoneyFormat.grouped(wish.usteceno)) / \(MoneyFormat.grouped(wish.cilj)) RSD")
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: fraction)
                .tint(.accentColor)

            Text(projectionText)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            if let rok = wish.rok {
                Text("Rok: \(rok.formatted(.dateTime.day().month(.abbreviated).year()))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    private var fraction: Double {
        let cilj = (wish.cilj as NSDecimalNumber).doubleValue
        guard cilj > 0 else { return 0 }
        let saved = (wish.usteceno as NSDecimalNumber).doubleValue
        return min(max(saved / cilj, 0), 1)
    }

    private var projectionText: String {
        let remaining = wish.cilj - wish.usteceno
        if remaining <= 0 { return "Cilj dostignut ✓" }

        let remainingD = (remaining as NSDecimalNumber).doubleValue
        let avgD = (avgLeftover as NSDecimalNumber).doubleValue

        var base: String
        if avgD > 0 {
            let months = Int(ceil(remainingD / avgD))
            base = "Po proseku (~\(MoneyFormat.grouped(avgLeftover))/mes) — još ~\(months) mes."
        } else {
            base = "Nema dovoljno mesečnog viška za projekciju."
        }

        if let rok = wish.rok {
            let monthsLeft = max(1, Calendar.current.dateComponents([.month], from: Date(), to: rok).month ?? 0)
            let required = remainingD / Double(monthsLeft)
            let onTrack = avgD >= required
            base += "\nTreba ~\(MoneyFormat.grouped(Decimal(required)))/mes do roka — " + (onTrack ? "stižeš." : "ne stižeš.")
        }
        return base
    }
}

// MARK: - Add / Edit

struct WishEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let wish: Wish?

    @State private var naziv: String = ""
    @State private var ciljDisplay: String = ""
    @State private var ciljRaw: String = ""
    @State private var hasRok: Bool = false
    @State private var rok: Date = Date()

    @State private var odvojiDisplay: String = ""
    @State private var odvojiRaw: String = ""
    @State private var ustecenoSoFar: Decimal = 0
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Naziv (npr. Minđuše)", text: $naziv)
                        .font(.system(.subheadline, design: .monospaced))
                        .focused($nameFocused)
                } header: {
                    Text("Naziv")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    TextField("0", text: $ciljDisplay)
                        .keyboardType(.numberPad)
                        .font(.system(.subheadline, design: .monospaced))
                        .onChange(of: ciljDisplay) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            ciljRaw = digits
                            let formatted = MoneyFormat.grouped(digits)
                            if formatted != newValue { ciljDisplay = formatted }
                        }
                } header: {
                    Text("Cilj (RSD)")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    Toggle(isOn: $hasRok) {
                        Text("Rok")
                            .font(.system(.subheadline, design: .monospaced))
                    }
                    if hasRok {
                        DatePicker("Datum", selection: $rok, displayedComponents: .date)
                            .font(.system(.subheadline, design: .monospaced))
                    }
                } footer: {
                    Text("Opciono. Koristi se za projekciju koliko mesečno treba da štediš.")
                        .font(.system(.caption, design: .monospaced))
                }

                if wish != nil {
                    savingsSection
                    Section {
                        Button(role: .destructive) {
                            deleteWish()
                        } label: {
                            Label("Obriši želju", systemImage: "trash")
                                .font(.system(.subheadline, design: .monospaced))
                        }
                    }
                }
            }
            .navigationTitle(wish == nil ? "Nova želja" : "Izmeni želju")
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
            .onAppear {
                if let wish {
                    naziv = wish.naziv
                    ciljRaw = MoneyFormat.digits(wish.cilj)
                    ciljDisplay = MoneyFormat.grouped(ciljRaw)
                    ustecenoSoFar = wish.usteceno
                    if let r = wish.rok { hasRok = true; rok = r }
                } else {
                    nameFocused = true
                }
            }
        }
    }

    private var savingsSection: some View {
        Section {
            HStack {
                Text("Ušteđeno")
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(MoneyFormat.grouped(ustecenoSoFar) + " RSD")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
            }

            HStack(spacing: 8) {
                TextField("Iznos", text: $odvojiDisplay)
                    .keyboardType(.numberPad)
                    .font(.system(.subheadline, design: .monospaced))
                    .onChange(of: odvojiDisplay) { _, newValue in
                        let digits = newValue.filter(\.isNumber)
                        odvojiRaw = digits
                        let formatted = MoneyFormat.grouped(digits)
                        if formatted != newValue { odvojiDisplay = formatted }
                    }
                Button("Odvojio sam") { odvoji() }
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                    .disabled((Int(odvojiRaw) ?? 0) <= 0)
            }

            if let wish, wish.cilj > 0, wish.usteceno >= wish.cilj {
                Button {
                    archive()
                } label: {
                    Label("Ostvareno 🎉", systemImage: "checkmark.circle.fill")
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                }
            }
        } header: {
            Text("Štednja")
                .font(.system(.caption, design: .monospaced))
        } footer: {
            Text("Upiši koliko si odvojio za ovu želju. Kad dostigneš cilj, označi kao ostvareno.")
                .font(.system(.caption, design: .monospaced))
        }
    }

    private var isValid: Bool {
        guard let value = Int(ciljRaw), value > 0 else { return false }
        return !naziv.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Actions

    private func save() {
        guard let cilj = Decimal(string: ciljRaw), cilj > 0 else { return }
        let trimmed = naziv.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if let wish {
            wish.naziv = trimmed
            wish.cilj = cilj
            wish.rok = hasRok ? rok : nil
        } else {
            let new = Wish(naziv: trimmed, cilj: cilj, rok: hasRok ? rok : nil)
            modelContext.insert(new)
        }
        try? modelContext.save()
        dismiss()
    }

    private func odvoji() {
        guard let wish, let amount = Decimal(string: odvojiRaw), amount > 0 else { return }
        wish.usteceno += amount
        try? modelContext.save()
        ustecenoSoFar = wish.usteceno
        odvojiDisplay = ""
        odvojiRaw = ""
    }

    private func archive() {
        wish?.isArchived = true
        try? modelContext.save()
        dismiss()
    }

    private func deleteWish() {
        if let wish { modelContext.delete(wish) }
        try? modelContext.save()
        dismiss()
    }
}
