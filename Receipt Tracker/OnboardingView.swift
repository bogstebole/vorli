//
//  OnboardingView.swift
//  Receipt Tracker
//
//  Reel-style first launch: a 10s intro video (crumpled receipts falling on
//  black) dissolves into three value lines on the same black, each typed in
//  character by character out of a soft blur — like a fiscal printer — then
//  a single CTA into the scanner.
//
//  Minimal by design: one small monospaced sentence at a time, no chrome.
//  Tap anywhere to advance; skip is always available.
//

import SwiftUI
import AVFoundation

struct OnboardingView: View {
    /// `startScanning` is true when the user tapped the scan CTA.
    var onFinish: (_ startScanning: Bool) -> Void

    // 0 = video, 1...3 = value lines, 4 = CTA
    @State private var step = 0
    @State private var videoSentenceVisible = false
    @State private var blackout = false
    @State private var lineRevealed = false
    @State private var ctaVisible = false
    /// Invalidation token: bumping it cancels every scheduled step, so a tap
    /// can jump the sequence without ghosts firing later.
    @State private var seq = 0

    private static let lines: [String] = [
        "Skeniraš račun.\nDve sekunde — sve je unutra.",
        "Svaki artikal. Svaka cena.\nMesec za mesecom.",
        "I znaš kad možeš da priuštiš\nono što želiš."
    ]
    private static let ctaLine = "Sledeći račun nemoj da baciš."

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if step == 0 {
                IntroPlayerView()
                    .ignoresSafeArea()
                    .opacity(blackout ? 0 : 1)
            }

            // One small sentence over the video.
            if step == 0 {
                Text("Gde odoše pare?")
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .opacity(videoSentenceVisible && !blackout ? 1 : 0)
                    .blur(radius: videoSentenceVisible && !blackout ? 0 : 3)
            }

            // Value lines, one at a time, typed out of a blur.
            if (1...3).contains(step) {
                StaggeredText(text: Self.lines[step - 1], revealed: lineRevealed)
            }

            // Final: one line + the only real button in the whole flow.
            if step == 4 {
                VStack(spacing: 48) {
                    StaggeredText(text: Self.ctaLine, revealed: ctaVisible)

                    VStack(spacing: 14) {
                        Button {
                            onFinish(true)
                        } label: {
                            Text("Skeniraj prvi račun")
                                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.glassProminent)
                        .tint(.white)

                        Button("Kasnije") { onFinish(false) }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    .opacity(ctaVisible ? 1 : 0)
                    .offset(y: ctaVisible ? 0 : 10)
                }
                .padding(.horizontal, 32)
            }

            // Skip — tiny, top right, gone on the last step.
            VStack {
                HStack {
                    Spacer()
                    if step < 4 {
                        Button("Preskoči") { onFinish(false) }
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(20)
                    }
                }
                Spacer()
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .preferredColorScheme(.dark)
        .onAppear { runVideoPhase() }
    }

    // MARK: - Sequencing

    private func schedule(after delay: Double, _ action: @escaping () -> Void) {
        let token = seq
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            if token == seq { action() }
        }
    }

    private func runVideoPhase() {
        schedule(after: 1.2) {
            withAnimation(.easeOut(duration: 0.9)) { videoSentenceVisible = true }
        }
        // Start dissolving before the clip ends so the cut is never visible.
        schedule(after: 8.2) {
            withAnimation(.easeInOut(duration: 1.4)) { blackout = true }
        }
        schedule(after: 9.7) { show(step: 1) }
    }

    private func show(step newStep: Int) {
        step = newStep
        if newStep == 4 {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.85).delay(0.15)) { ctaVisible = true }
            return
        }
        lineRevealed = false
        withAnimation(.easeOut(duration: 0.05).delay(0.15)) { lineRevealed = true }
        // Hold, then dissolve out and move on. Reveal takes ~1s of stagger,
        // reading time ~2.5s, exit 0.4s.
        schedule(after: 4.2) { dissolveToNext() }
    }

    private func dissolveToNext() {
        withAnimation(.easeIn(duration: 0.4)) { lineRevealed = false }
        schedule(after: 0.45) { show(step: step + 1) }
    }

    /// Tap anywhere: cancel pending steps and jump forward immediately.
    private func advance() {
        guard step < 4 else { return }
        seq += 1
        if step == 0 {
            withAnimation(.easeInOut(duration: 0.6)) { blackout = true }
            schedule(after: 0.6) { show(step: 1) }
        } else {
            dissolveToNext()
        }
    }
}

// MARK: - Per-character staged text

/// A sentence that materializes character by character — each glyph fades in
/// out of a soft blur with a slight rise, staggered left to right, like a
/// receipt printer with taste. Exits as one soft dissolve.
private struct StaggeredText: View {
    let text: String
    let revealed: Bool

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(text.components(separatedBy: "\n").enumerated()), id: \.offset) { lineIndex, line in
                HStack(spacing: 0) {
                    ForEach(Array(line.enumerated()), id: \.offset) { charIndex, character in
                        Text(String(character))
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white)
                            .opacity(revealed ? 1 : 0)
                            .blur(radius: revealed ? 0 : 4)
                            .offset(y: revealed ? 0 : 4)
                            .animation(
                                revealed
                                    ? .easeOut(duration: 0.5).delay(Double(lineIndex) * 0.35 + Double(charIndex) * 0.018)
                                    : .easeIn(duration: 0.35),
                                value: revealed
                            )
                    }
                }
            }
        }
        .multilineTextAlignment(.center)
    }
}

// MARK: - Video player (plays once, holds last frame)

private struct IntroPlayerView: UIViewRepresentable {
    func makeUIView(context: Context) -> PlayerContainerView {
        PlayerContainerView()
    }

    func updateUIView(_ uiView: PlayerContainerView, context: Context) {}

    final class PlayerContainerView: UIView {
        private var player: AVPlayer?

        override init(frame: CGRect) {
            super.init(frame: frame)
            guard let url = Bundle.main.url(forResource: "OnboardingIntro", withExtension: "mp4") else { return }
            let player = AVPlayer(url: url)
            player.isMuted = true
            player.actionAtItemEnd = .pause // hold last frame under the fade
            self.player = player

            let layer = AVPlayerLayer(player: player)
            layer.videoGravity = .resizeAspectFill
            self.layer.addSublayer(layer)
            player.play()
        }

        required init?(coder: NSCoder) { fatalError() }

        override func layoutSubviews() {
            super.layoutSubviews()
            layer.sublayers?.first?.frame = bounds
        }
    }
}

#Preview {
    OnboardingView { _ in }
}
