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
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                // Icon
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.green.gradient)
                    .padding(.top, 20)
                
                // Title
                Text("Add Balance")
                    .font(.system(.title2, design: .monospaced, weight: .bold))
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Amount (RSD)")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                    
                    HStack {
                        TextField("0", text: $amountText)
                            .font(.system(.title, design: .monospaced, weight: .semibold))
                            .keyboardType(.decimalPad)
                            .focused($isAmountFocused)
                            .multilineTextAlignment(.center)
                        
                        Text("RSD")
                            .font(.system(.title3, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .padding(.horizontal)
                
                Spacer()
                
                // Add Button
                Button {
                    addBalance()
                } label: {
                    Text("Add Balance")
                        .font(.system(.headline, design: .monospaced))
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(isValidAmount ? Color.green.gradient : Color.gray.gradient)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .disabled(!isValidAmount)
                .padding()
            }
            .navigationTitle("Add Balance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
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
    
    private func addBalance() {
        guard let amount = Decimal(string: amountText.replacingOccurrences(of: ",", with: ".")) else {
            return
        }
        
        onAdd(amount)
        dismiss()
    }
}

#Preview {
    AddBalanceSheet { amount in
        print("Adding balance: \(amount)")
    }
}
