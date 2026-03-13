//
//  ActionItemCardView.swift
//  Receipt Tracker
//
//  Action item card component for Vorli chat — renders VorliCardPayload
//  as a visually distinct card with thumbnail, text rows, and action button.
//

import SwiftUI

// MARK: - Color(hex:) initializer

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - ShimmerModifier

struct ShimmerModifier: ViewModifier {
    let isActive: Bool
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                Group {
                    if isActive {
                        LinearGradient(
                            stops: [
                                .init(color: .clear, location: phase - 0.3),
                                .init(color: .white.opacity(0.5), location: phase),
                                .init(color: .clear, location: phase + 0.3)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .clipped()
            .onAppear {
                if isActive {
                    withAnimation(.linear(duration: 1.2).repeatForever(autoreverses: false)) {
                        phase = 1.3
                    }
                }
            }
    }
}

extension View {
    func shimmer(isActive: Bool) -> some View {
        modifier(ShimmerModifier(isActive: isActive))
    }
}

// MARK: - CardThumbnailView

struct CardThumbnailView: View {
    let cardType: VorliCardPayload.CardType
    let actionState: VorliCardPayload.ActionState

    var body: some View {
        ZStack {
            // Back card
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray5))
                .frame(width: 44, height: 56)
                .rotationEffect(.degrees(-8))
                .offset(x: -4, y: 2)

            // Middle card
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.systemGray4))
                .frame(width: 44, height: 56)
                .rotationEffect(.degrees(-3))
                .offset(x: -2, y: 1)

            // Front card
            RoundedRectangle(cornerRadius: 6)
                .fill(.white)
                .frame(width: 44, height: 56)
                .overlay(frontCardLabel)
        }
        .shimmer(isActive: actionState == .loading)
        .frame(width: 66, height: 72)
    }

    @ViewBuilder
    private var frontCardLabel: some View {
        switch cardType {
        case .pdf:
            Text("PDF")
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#EB4322"))
        case .shoppingList:
            Image(systemName: "cart.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(.systemGray2))
        }
    }
}

// MARK: - CardActionButton

struct CardActionButton: View {
    let payload: VorliCardPayload
    let onTap: () -> Void
    @State private var showShareSheet = false

    private var symbolName: String {
        switch payload.cardType {
        case .pdf:
            return "arrow.down.to.line.compact"
        case .shoppingList:
            return "square.and.arrow.up"
        }
    }

    var body: some View {
        Button {
            showShareSheet = true
            onTap()
        } label: {
            Image(systemName: symbolName)
                .font(.system(size: 13))
                .frame(width: 28, height: 28)
                .background(Circle().fill(.tertiary))
        }
        .opacity(payload.actionState == .loading || payload.actionState == .disabled ? 0.35 : 1.0)
        .disabled(payload.actionState == .loading || payload.actionState == .disabled)
        .sheet(isPresented: $showShareSheet) {
            // Phase 3 stub — Phase 4/5 will replace with real content
            ShareLink(
                item: URL(string: "https://vorli.app")!,
                label: { Text(payload.title) }
            )
        }
    }
}

// MARK: - ActionItemCardView

struct ActionItemCardView: View {
    let payload: VorliCardPayload

    var body: some View {
        HStack(spacing: 0) {
            CardThumbnailView(cardType: payload.cardType, actionState: payload.actionState)
                .frame(width: 66)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .center) {
                    Text(payload.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    CardActionButton(payload: payload, onTap: {})
                }
                .padding(.bottom, 2)

                Text(payload.mainText)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#111110"))

                Text(payload.metaLine)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8A8A82"))
            }
            .padding(.vertical, 8)
            .padding(.leading, 10)
            .padding(.trailing, 12)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [Color(hex: "#F2F1F1"), .white],
                startPoint: UnitPoint(x: 0, y: 0.5),
                endPoint: UnitPoint(x: 1, y: 0.7)
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.04), radius: 1.5, x: 0, y: 1)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.03), radius: 3, x: 0, y: 6)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.02), radius: 4, x: 0, y: 13)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.01), radius: 4.5, x: 0, y: 24)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0), radius: 5, x: 0, y: 37)
    }
}

// MARK: - Preview

#Preview("Action Item Cards") {
    VStack(spacing: 24) {
        // PDF card — ready state
        ActionItemCardView(
            payload: VorliCardPayload(
                cardType: .pdf,
                title: "PDF izveštaj",
                mainText: "Mart 2026",
                metaLine: "12 računa · 45.320 RSD",
                actionState: .ready
            )
        )

        // Shopping list card — loading state
        ActionItemCardView(
            payload: VorliCardPayload(
                cardType: .shoppingList,
                title: "Lista za kupovinu",
                mainText: "Nedeljni plan",
                metaLine: "8 artikala · ~3.200 RSD",
                actionState: .loading
            )
        )
    }
    .padding(20)
    .background(Color(.systemGroupedBackground))
}
