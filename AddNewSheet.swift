//
//  AddNewSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 11. 3. 2026.
//
//  Hosts the "Planiranje" tab: the manual side of money — income, fixed
//  costs, manual expense entry, and the wishlist. (File name kept for the
//  Xcode project reference; the view is PlaniranjeView.)
//

import SwiftUI

struct PlaniranjeView: View {
    @State private var showMesecnaZarada = false
    @State private var showFiksniTroskovi = false
    @State private var showDodajTrosak = false
    @State private var showListaZelja = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    AddNewRow(icon: "wallet", title: "Mesečna zarada") {
                        showMesecnaZarada = true
                    }
                    AddNewRow(icon: "repeat", title: "Fiksni mesečni troškovi") {
                        showFiksniTroskovi = true
                    }
                    AddNewRow(icon: "circle-plus", title: "Dodaj trošak ručno") {
                        showDodajTrosak = true
                    }
                    AddNewRow(icon: "gift", title: "Lista želja") {
                        showListaZelja = true
                    }
                }
                .padding(.horizontal, 8)
                .padding(.top, 8)

                Spacer()
            }
            .navigationTitle("Planiranje")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMesecnaZarada) {
                AddBalanceSheet()
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
                TablerIcon(icon, size: 20)
                    .frame(width: 24, alignment: .center)
                    .foregroundStyle(.primary)

                Text(title)
                    .font(.system(size: 13, design: .monospaced))
                    .tracking(-0.43)
                    .foregroundStyle(.primary)

                Spacer()

                TablerIcon("chevron-right", size: 13)
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
    PlaniranjeView()
}
