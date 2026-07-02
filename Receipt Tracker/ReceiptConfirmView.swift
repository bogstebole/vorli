//
//  ReceiptConfirmView.swift
//  Receipt Tracker
//
//  Editable confirmation shown after an OCR scan (the fallback when the QR
//  code can't be read). The user verifies/corrects the extracted fields
//  before the receipt is saved.
//

import SwiftUI
import SwiftData

struct ReceiptConfirmView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let parsed: ParsedReceipt
    var onSaved: (Receipt) -> Void = { _ in }

    @State private var merchant: String = ""
    @State private var amountText: String = ""
    @State private var amountRaw: String = ""
    @State private var date: Date = Date()
    @State private var saving = false
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Prodavac", text: $merchant)
                        .font(.system(.subheadline, design: .monospaced))
                } header: {
                    Text("Prodavac")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    TextField("0,00", text: $amountText)
                        .keyboardType(.numberPad)
                        .font(.system(.subheadline, design: .monospaced))
                        .onChange(of: amountText) { _, newValue in
                            let digits = newValue.filter(\.isNumber)
                            amountRaw = digits
                            let formatted = MoneyFormat.centsDisplay(digits)
                            if formatted != newValue { amountText = formatted }
                        }
                } header: {
                    Text("Ukupan iznos (RSD)")
                        .font(.system(.caption, design: .monospaced))
                }

                Section {
                    DatePicker("Datum", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .font(.system(.subheadline, design: .monospaced))
                }

                if !parsed.items.isEmpty {
                    Section {
                        ForEach(parsed.items.indices, id: \.self) { idx in
                            HStack {
                                Text(parsed.items[idx].name)
                                    .font(.system(.caption, design: .monospaced))
                                    .lineLimit(1)
                                Spacer()
                                Text(MoneyFormat.decimalString(parsed.items[idx].lineTotal))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    } header: {
                        Text("Stavke (\(parsed.items.count))")
                            .font(.system(.caption, design: .monospaced))
                    } footer: {
                        Text("OCR može da pogreši — proveri iznos pre čuvanja. QR kod daje tačnije podatke.")
                            .font(.system(.caption, design: .monospaced))
                    }
                }
            }
            .navigationTitle("Potvrdi račun")
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
                        if saving {
                            ProgressView()
                        } else {
                            Image(systemName: "checkmark")
                                .font(.system(.body, weight: .semibold))
                        }
                    }
                    .disabled(!isValid || saving)
                }
            }
            .onAppear(perform: prefill)
            .alert("Greška", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    private var amountValue: Decimal? {
        guard !amountRaw.isEmpty, let cents = Decimal(string: amountRaw) else { return nil }
        return cents / 100
    }

    private var isValid: Bool {
        guard let amount = amountValue, amount > 0 else { return false }
        return !merchant.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func prefill() {
        merchant = parsed.merchantName
        amountRaw = MoneyFormat.digits(parsed.totalAmount * 100)
        amountText = MoneyFormat.centsDisplay(amountRaw)
        date = parsed.timestamp
    }

    private func save() {
        guard let amount = amountValue, amount > 0 else { return }
        let trimmedMerchant = merchant.trimmingCharacters(in: .whitespaces)

        let edited = ParsedReceipt(
            url: parsed.url,
            merchantName: trimmedMerchant,
            merchantAddress: parsed.merchantAddress,
            merchantCity: parsed.merchantCity,
            timestamp: date,
            totalAmount: amount,
            totalTax: parsed.totalTax,
            paymentMethod: parsed.paymentMethod,
            receiptNumber: parsed.receiptNumber,
            cashRegisterNumber: parsed.cashRegisterNumber,
            items: parsed.items
        )

        saving = true
        Task {
            do {
                let service = ReceiptService(modelContext: modelContext)
                let receipt = try await service.save(parsed: edited)
                saving = false
                onSaved(receipt)
                dismiss()
            } catch ReceiptError.duplicateReceipt {
                saving = false
                errorMessage = "Ovaj račun je već sačuvan."
                showError = true
            } catch {
                saving = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
