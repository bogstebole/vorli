//
//  ReturnToNowTab.swift
//  Receipt Tracker
//
//  The way back to the current month once you have paged away from it: a tab
//  that grows out of the trailing screen edge, halfway down the screen.
//
//  It pops rather than slides. Once the swipe is more than half a month away
//  from now the tab springs out of the edge the way the volume indicator
//  springs out beside the volume buttons: it shoots a little past its depth
//  while it is still short, then fills out along the edge as it settles, so it
//  reads as the edge stretching rather than a button fading in. Going back it
//  tucks away quickly and without the bounce.
//

import SwiftUI

/// Reads the pager's live position and decides whether the tab is out. Its
/// own view so that, like the indicator, only it is redrawn during a swipe.
struct LiveReturnTab: View {
    let progress: PagerProgress
    /// Page index of the current month, or nil if it has no page.
    let nowIndex: Int?
    var action: () -> Void

    @State private var shown = false

    var body: some View {
        // Out past 0.6 of a month away, back in under 0.35: the gap keeps a
        // finger resting near halfway from popping the tab in and out.
        let wantsOut = shown ? away > 0.35 : away > 0.6
        ReturnToNowTab(shown: shown, action: action)
            .onChange(of: wantsOut, initial: true) { _, out in shown = out }
    }

    /// 0 on the current month, 1 once a full month away or further.
    private var away: Double {
        guard let nowIndex else { return 0 }
        return min(1, max(0, Double(nowIndex) - progress.value))
    }
}

struct ReturnToNowTab: View {
    let shown: Bool
    var action: () -> Void

    /// How far the tab reaches in from the edge when out.
    static let maxDepth: CGFloat = 26
    static let height: CGFloat = 80
    /// Wider than the tab itself so the tap target clears 44pt, and no wider:
    /// the tab sits over the pager, and a swipe that starts on it does not
    /// reach the pages.
    private static let hitWidth: CGFloat = 44

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            ZStack {
                EdgeBump(depth: shown ? Self.maxDepth : 0)
                    .fill(Color.primary)
                    // Depth on a loose spring: it overshoots, bulging past its
                    // resting depth before it settles back.
                    .animation(depthAnimation, value: shown)
                    // Length along the edge on a slower, firmer one, so it is
                    // still short while the depth overshoots — the stretch.
                    .scaleEffect(y: shown ? 1 : 0.3)
                    .animation(lengthAnimation, value: shown)

                TablerIcon("arrow-right", size: 14)
                    // Ink of the screen behind, so it inverts with the
                    // appearance exactly as the tab does.
                    .foregroundStyle(Color(uiColor: .systemBackground))
                    .scaleEffect(shown ? 1 : 0.4)
                    .opacity(shown ? 1 : 0)
                    // Rides out with the tip, a beat behind it.
                    .position(
                        x: shown ? Self.hitWidth - Self.maxDepth * 0.46 : Self.hitWidth + 6,
                        y: Self.height / 2
                    )
                    .animation(arrowAnimation, value: shown)
            }
            .frame(width: Self.hitWidth, height: Self.height)
            .contentShape(Rectangle())
        }
        .buttonStyle(EdgeTabButtonStyle())
        .allowsHitTesting(shown)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("Na tekući mesec")
        .accessibilityHidden(!shown)
    }

    private var depthAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return shown ? .spring(response: 0.36, dampingFraction: 0.55) : Self.tuckIn
    }

    private var lengthAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return shown ? .spring(response: 0.46, dampingFraction: 0.74) : Self.tuckIn
    }

    private var arrowAnimation: Animation {
        if reduceMotion { return .easeOut(duration: 0.2) }
        return shown ? .spring(response: 0.34, dampingFraction: 0.66).delay(0.04) : Self.tuckIn
    }

    private static let tuckIn = Animation.spring(response: 0.26, dampingFraction: 0.92)
}

/// A bump growing out of the trailing edge: concave where it leaves the edge,
/// round at its tip, so it reads as part of the screen edge being pulled in
/// rather than a separate button placed next to it.
struct EdgeBump: Shape {
    /// How far the bump reaches in from the edge, in points.
    var depth: CGFloat

    var animatableData: CGFloat {
        get { depth }
        set { depth = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let edge = rect.maxX
        let mid = rect.midY
        let half = rect.height / 2
        let tip = edge - depth

        var path = Path()
        path.move(to: CGPoint(x: edge, y: rect.minY))
        // Leaves along the edge, so the join has no seam, then swings out to a
        // tip that is vertical too, which is what makes the head round.
        path.addCurve(
            to: CGPoint(x: tip, y: mid),
            control1: CGPoint(x: edge, y: rect.minY + half * 0.5),
            control2: CGPoint(x: tip, y: mid - half * 0.55)
        )
        path.addCurve(
            to: CGPoint(x: edge, y: rect.maxY),
            control1: CGPoint(x: tip, y: mid + half * 0.55),
            control2: CGPoint(x: edge, y: rect.maxY - half * 0.5)
        )
        path.closeSubpath()
        return path
    }
}

/// Under the finger the tab stretches further out of the edge and thins a
/// little, as if pulled; on release it springs back.
private struct EdgeTabButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(
                x: configuration.isPressed ? 1.16 : 1,
                y: configuration.isPressed ? 0.92 : 1,
                anchor: .trailing
            )
            .animation(.spring(response: 0.3, dampingFraction: 0.55), value: configuration.isPressed)
    }
}

#Preview {
    @Previewable @State var shown = false
    VStack {
        Button(shown ? "Sakrij" : "Prikaži") { shown.toggle() }
            .font(.system(size: 13, design: .monospaced))
        HStack {
            Spacer()
            ReturnToNowTab(shown: shown) {}
        }
    }
    .frame(maxHeight: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
}
