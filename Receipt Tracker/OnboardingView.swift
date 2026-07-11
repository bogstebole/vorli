//
//  OnboardingView.swift
//  Receipt Tracker
//
//  First-launch story, built around the job the app is hired for:
//  "Kad neko pita gde su pare — imam odgovor."
//
//  Page 1: the question everyone knows + a receipt that fills itself in.
//  Page 2: the hope — wishes funded by what's left over.
//  Page 3: one action — scan your first receipt.
//
//  All motion is native SwiftUI (no video): staged reveals, spring settles,
//  digits that roll into place. Shown once; skippable at any point.
//

import SwiftUI

struct OnboardingView: View {
    /// `startScanning` is true when the user tapped the scan CTA.
    var onFinish: (_ startScanning: Bool) -> Void

    @State private var page = 0

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                // Skip — always available, never nagging.
                HStack {
                    Spacer()
                    if page < 2 {
                        Button("Preskoči") { onFinish(false) }
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 20)
                            .padding(.top, 8)
                    } else {
                        // Reserve the space so pages don't jump.
                        Text(" ")
                            .font(.system(.caption, design: .monospaced))
                            .padding(.top, 8)
                    }
                }

                TabView(selection: $page) {
                    QuestionPage(isActive: page == 0).tag(0)
                    WishPage(isActive: page == 1).tag(1)
                    ScanPage(isActive: page == 2).tag(2)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                pageDots

                bottomBar
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 12)
            }
        }
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Capsule()
                    .fill(index == page ? Color.primary : Color.secondary.opacity(0.3))
                    .frame(width: index == page ? 20 : 7, height: 7)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: page)
    }

    @ViewBuilder
    private var bottomBar: some View {
        if page < 2 {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.85)) { page += 1 }
            } label: {
                Text("Dalje")
                    .font(.system(.body, design: .monospaced, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.glass)
        } else {
            VStack(spacing: 10) {
                Button {
                    onFinish(true)
                } label: {
                    Text("Skeniraj prvi račun")
                        .font(.system(.body, design: .monospaced, weight: .semibold))
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(.primary)

                Button("Kasnije") { onFinish(false) }
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Page 1: the question

private struct QuestionPage: View {
    let isActive: Bool
    @State private var showTitle = false
    @State private var showReceipt = false
    @State private var showAnswer = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("Gde odoše pare?")
                .font(.system(.largeTitle, design: .monospaced, weight: .semibold))
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 12)
                .blur(radius: showTitle ? 0 : 4)

            AnimatedReceiptCard(isActive: isActive)
                .opacity(showReceipt ? 1 : 0)
                .scaleEffect(showReceipt ? 1 : 0.96)

            Text("Svaki račun. Svaki artikal. Svaki dinar.\nSkeniraš — i znaš.")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showAnswer ? 1 : 0)
                .offset(y: showAnswer ? 0 : 8)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            run()
        }
    }

    // Staging: question first, then the receipt answers it, then the words.
    private func run() {
        showTitle = false; showReceipt = false; showAnswer = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) { showTitle = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.45)) { showReceipt = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(1.7)) { showAnswer = true }
    }
}

/// A receipt that fills itself in: items land one by one, then the total
/// rolls into place — the app's core promise in three seconds.
private struct AnimatedReceiptCard: View {
    let isActive: Bool

    private static let items: [(String, String)] = [
        ("MLEKO 2,8% 1L", "119,90"),
        ("HLEB SA SEMENKAMA", "75,00"),
        ("JOGURT 950G", "89,00"),
        ("KAFA MLEVENA 200G", "349,99")
    ]

    @State private var revealedCount = 0
    @State private var total = "0,00"
    @State private var showTotal = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DOMAĆA TRGOVINA")
                .font(.system(.caption, design: .monospaced, weight: .semibold))
                .frame(maxWidth: .infinity)

            Divider()

            ForEach(Array(Self.items.enumerated()), id: \.offset) { index, item in
                HStack {
                    Text(item.0)
                        .font(.system(.caption, design: .monospaced))
                    Spacer()
                    Text(item.1)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .opacity(index < revealedCount ? 1 : 0)
                .offset(y: index < revealedCount ? 0 : 6)
            }

            Divider()

            HStack {
                Text("UKUPNO")
                    .font(.system(.caption, design: .monospaced, weight: .semibold))
                Spacer()
                Text(total + " RSD")
                    .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                    .contentTransition(.numericText())
            }
            .opacity(showTotal ? 1 : 0)
        }
        .padding(18)
        .frame(maxWidth: 300)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            run()
        }
    }

    private func run() {
        revealedCount = 0; total = "0,00"; showTotal = false

        // Items land one by one — first-time reveal, stagger is earned here.
        for index in Self.items.indices {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8).delay(0.7 + Double(index) * 0.14)) {
                revealedCount = index + 1
            }
        }
        // Then the total rolls in.
        withAnimation(.spring(response: 0.45, dampingFraction: 0.85).delay(1.35)) { showTotal = true }
        withAnimation(.spring(response: 0.7, dampingFraction: 0.9).delay(1.5)) { total = "633,89" }
    }
}

// MARK: - Page 2: the hope

private struct WishPage: View {
    let isActive: Bool
    @State private var showTitle = false
    @State private var showCard = false
    @State private var progress: Double = 0
    @State private var showCaption = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Text("I znaš kad možeš da priuštiš\nono što želiš")
                .font(.system(.title2, design: .monospaced, weight: .semibold))
                .multilineTextAlignment(.center)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 12)
                .blur(radius: showTitle ? 0 : 4)

            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Slušalice")
                        .font(.system(.subheadline, design: .monospaced))
                    Spacer()
                    Text("21.000 / 30.000 RSD")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                ProgressView(value: progress)
                    .tint(.accentColor)
                Text("Po tvom proseku — još ~2 meseca.")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .opacity(showCaption ? 1 : 0)
            }
            .padding(18)
            .frame(maxWidth: 300)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .opacity(showCard ? 1 : 0)
            .scaleEffect(showCard ? 1 : 0.96)

            Text("Ono što ti ostane na kraju meseca\npostaje ono što želiš.")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showCaption ? 1 : 0)
                .offset(y: showCaption ? 0 : 8)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            run()
        }
    }

    private func run() {
        showTitle = false; showCard = false; progress = 0; showCaption = false
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.1)) { showTitle = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.4)) { showCard = true }
        withAnimation(.easeOut(duration: 0.9).delay(0.7)) { progress = 0.7 }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(1.3)) { showCaption = true }
    }
}

// MARK: - Page 3: the action

private struct ScanPage: View {
    let isActive: Bool
    @State private var showIcon = false
    @State private var showTitle = false

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 72, weight: .light))
                .opacity(showIcon ? 1 : 0)
                .scaleEffect(showIcon ? 1 : 0.85)

            Text("Prvi račun te čeka\nu novčaniku")
                .font(.system(.title2, design: .monospaced, weight: .semibold))
                .multilineTextAlignment(.center)
                .opacity(showTitle ? 1 : 0)
                .offset(y: showTitle ? 0 : 12)
                .blur(radius: showTitle ? 0 : 4)

            Text("QR kod sa fiskalnog računa — dve sekunde,\ni sve je unutra.")
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .opacity(showTitle ? 1 : 0)

            Spacer()
        }
        .padding(.horizontal, 32)
        .onChange(of: isActive, initial: true) { _, active in
            guard active else { return }
            run()
        }
    }

    private func run() {
        showIcon = false; showTitle = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75).delay(0.1)) { showIcon = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.85).delay(0.35)) { showTitle = true }
    }
}

#Preview {
    OnboardingView { _ in }
}
