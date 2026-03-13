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
//
// Five 48.5×48.5pt cards in a 66×77pt frame, absolutely positioned per Figma node 148:15218.
// Offsets derived from Figma absolute positions relative to container center (33, 38.5):
//   148:15219  -20.8°  (-11, -7)   opacity 0.7   bg: white
//   148:15223  +7.72°  (+6,  -1)                 bg: #fdfdfd
//   148:15227  -15°    (+2,  +9)                 bg: #fdfdfd
//   148:15231  +15°    (-14, +18)                bg: #fbfbfb
//   148:15235  +0.61°  (+1,  +16)   front card   bg: white
//   148:15237  scroll indicator gradient at bottom

struct CardThumbnailView: View {
    let cardType: VorliCardPayload.CardType
    let actionState: VorliCardPayload.ActionState

    // Figma: size-[48.512px], rounded-[5.513px]
    private let sz: CGFloat = 48.5
    private let cr: CGFloat = 5.5

    var body: some View {
        ZStack {
            // 148:15219 — back-most, -20.8°, 70% opacity, white
            backCard(.white, rotation: -20.8, dx: -11, dy: -7)
                .opacity(0.7)

            // 148:15223 — +7.72°, #fdfdfd
            backCard(Color(hex: "#FDFDFD"), rotation: 7.72, dx: 6, dy: -1)

            // 148:15227 — -15°, #fdfdfd
            backCard(Color(hex: "#FDFDFD"), rotation: -15, dx: 2, dy: 9)

            // 148:15231 — +15°, #fbfbfb
            backCard(Color(hex: "#FBFBFB"), rotation: 15, dx: -14, dy: 18)

            // 148:15235 — front card, +0.61°, white, unique inward shadow
            RoundedRectangle(cornerRadius: cr)
                .fill(.white)
                .frame(width: sz, height: sz)
                .overlay(frontLabel)
                .shadow(color: Color(red: 0.56, green: 0.56, blue: 0.56).opacity(0.01), radius: 2.21, x: -4.41, y: -3.86)
                .shadow(color: Color(red: 0.56, green: 0.56, blue: 0.56).opacity(0.05), radius: 1.65, x: -2.21, y: -2.21)
                .shadow(color: Color(red: 0.56, green: 0.56, blue: 0.56).opacity(0.09), radius: 1.65, x: -1.10, y: -1.10)
                .shadow(color: Color(red: 0.56, green: 0.56, blue: 0.56).opacity(0.10), radius: 0.55, x:  0,    y:  0)
                .rotationEffect(.degrees(0.61))
                .offset(x: 1, y: 16)

            // 148:15237 — scroll indicator: gradient fade at bottom center
            LinearGradient(
                colors: [Color(hex: "#F2F2F7"), .clear],
                startPoint: .bottom,
                endPoint: .top
            )
            .frame(width: 57, height: CGFloat.infinity)
            .allowsHitTesting(false)
            .offset(x: 2.5, y: 27)
        }
        .shimmer(isActive: actionState == .loading)
        .frame(width: 66, height: 77, alignment: .bottom)
        .clipped()
    }

    // Background cards — downward shadow per Figma, doc icon placeholder
    private func backCard(_ fill: Color, rotation: Double, dx: CGFloat, dy: CGFloat) -> some View {
        let gray = Color(red: 0.52, green: 0.52, blue: 0.52)
        return RoundedRectangle(cornerRadius: cr)
            .fill(fill)
            .frame(width: sz, height: sz)
            .overlay(
                Image(systemName: "doc.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(Color(hex: "#5B8CCC").opacity(0.6))
            )
            .shadow(color: gray.opacity(0.01), radius: 2.76, x: 0, y: 6.06)
            .shadow(color: gray.opacity(0.05), radius: 2.21, x: 0, y: 3.31)
            .shadow(color: gray.opacity(0.09), radius: 1.65, x: 0, y: 1.65)
            .shadow(color: gray.opacity(0.10), radius: 1.10, x: 0, y: 0.55)
            .rotationEffect(.degrees(rotation))
            .offset(x: dx, y: dy)
    }

    @ViewBuilder
    private var frontLabel: some View {
        switch cardType {
        case .pdf:
            Text("PDF")
                .font(.system(size: 15.9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color(hex: "#EB4322"))
        case .shoppingList:
            Image(systemName: "cart.fill")
                .font(.system(size: 16))
                .foregroundStyle(Color(.systemGray2))
        }
    }
}

// MARK: - ActionItemCardView

struct ActionItemCardView: View {
    let payload: VorliCardPayload

    private var actionSymbol: String {
        switch payload.cardType {
        case .pdf:          return "square.and.arrow.down.fill"
        case .shoppingList: return "square.and.arrow.up"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            CardThumbnailView(cardType: payload.cardType, actionState: payload.actionState)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(payload.title)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundStyle(Color(hex: "#111110"))
                    Spacer()
                    Button {
                        // Phase 4/5: trigger export / share sheet
                    } label: {
                        Image(systemName: actionSymbol)
                            .font(.system(size: 13))
                    }
                    .buttonStyle(.bordered)
                    .buttonBorderShape(.circle)
                    .tint(.secondary)
                    .controlSize(.small)
                    .disabled(payload.actionState != .ready)
                }

                Text(payload.mainText)
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color(hex: "#111110"))

                Text(payload.metaLine)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundStyle(Color(hex: "#8A8A82"))
            }
            .padding(.vertical, 8)
            .padding(.trailing, 8)
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
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.03), radius: 3,   x: 0, y: 6)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.02), radius: 4,   x: 0, y: 13)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.01), radius: 4.5, x: 0, y: 24)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0),    radius: 5,   x: 0, y: 37)
    }
}

// MARK: - Preview

#Preview("Action Item Cards") {
    VStack(spacing: 24) {
        ActionItemCardView(
            payload: VorliCardPayload(
                cardType: .pdf,
                title: "PDF izveštaj",
                mainText: "Mart 2026",
                metaLine: "12 računa · 45.320 RSD",
                actionState: .ready
            )
        )

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
