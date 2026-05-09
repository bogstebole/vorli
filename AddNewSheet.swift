//
//  AddNewSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 11. 3. 2026.
//

import SwiftUI

struct AddNewSheet: View {
    @Environment(\.dismiss) private var dismiss

    var onAddBalance: () -> Void = {}

    @State private var showFiksniTroskovi = false
    @State private var showDodajTrosak = false
    @State private var showListaZelja = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    AddNewRow(icon: "wallet.bifold.fill", title: "Mesečna zarada") {
                        dismiss()
                        onAddBalance()
                    }
                    AddNewRow(icon: "repeat", title: "Fiksni mesečni troškovi") {
                        showFiksniTroskovi = true
                    }
                    AddNewRow(icon: "plus.circle", title: "Dodaj trošak ručno") {
                        showDodajTrosak = true
                    }
                    AddNewRow(icon: "app.gift.fill", title: "Lista želja") {
                        showListaZelja = true
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Dodaj")
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
            }
            .sheet(isPresented: $showFiksniTroskovi) {
                FiksniTroskoviSheet()
            }
            .sheet(isPresented: $showDodajTrosak) {
                DodajTrosakSheet()
            }
            .sheet(isPresented: $showListaZelja) {
                ListaZeljaSheet()
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Row

struct AddNewRow: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(.body, weight: .medium))
                    .frame(width: 24, alignment: .center)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 13, design: .monospaced))
                    .tracking(-0.43)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .contentShape(Rectangle())
        }
        .buttonStyle(AddNewRowButtonStyle())
    }
}

struct AddNewRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Color.primary.opacity(0.08) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

#Preview {
    AddNewSheet()
}
