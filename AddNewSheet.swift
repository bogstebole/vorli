//
//  AddNewSheet.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 11. 3. 2026.
//

import SwiftUI

struct AddNewSheet: View {
    @Environment(\.dismiss) private var dismiss
    
    // Action closures
    var onAddBalance: () -> Void = {}
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Bento grid - 2x2
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 12),
                    GridItem(.flexible(), spacing: 12)
                ], spacing: 12) {
                    BentoActionTile(
                        title: "Mesečni priliv",
                        icon: "arrow.down.circle.fill",
                        color: .green
                    ) {
                        dismiss()
                        onAddBalance()
                    }
                    
                    BentoActionTile(
                        title: "Dodaj trošak ručno",
                        icon: "pencil.circle.fill",
                        color: .orange
                    ) {
                        // TODO: Manual expense entry
                        dismiss()
                    }
                    
                    BentoActionTile(
                        title: "Lista želja",
                        icon: "heart.circle.fill",
                        color: .pink
                    ) {
                        // TODO: Wishlist
                        dismiss()
                    }
                    
                    BentoActionTile(
                        title: "Fiksni mesečni troškovi",
                        icon: "repeat.circle.fill",
                        color: .purple
                    ) {
                        // TODO: Fixed monthly expenses
                        dismiss()
                    }
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .padding(.top, 20)
            .navigationTitle("Dodaj novo")
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
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Bento Action Tile

struct BentoActionTile: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 32))
                    .foregroundStyle(color)
                
                Text(title)
                    .font(.system(.subheadline, design: .monospaced, weight: .medium))
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AddNewSheet()
}
