//
//  ReturnToNowTab.swift
//  Receipt Tracker
//
//  The way back to the current month once you have paged away from it: a tab
//  that grows out of the trailing screen edge, halfway down the screen.
//
//  It is driven by the pager's live position, like the month indicator, so it
//  does not pop in once a swipe has settled — it swells out of the edge as the
//  finger drags away from the current month, and sinks back into it on the way
//  home. Nothing about it animates on its own; the finger is the clock.
//

import SwiftUI

/// Reads the pager's live position and draws the tab. Its own view so that,
/// like the indicator, only it is redrawn while a swipe is in progress.
struct LiveReturnTab: View {
    let progress: PagerProgress
    /// Page index of the current month, or nil if it has no page.
    let nowIndex: Int?
    var action: () -> Void

    var body: some View {
        ReturnToNowTab(reveal: reveal, action: action)
    }

    /// 0 on the current month, 1 once a full month away or further.
    private var reveal: Double {
        guard let nowIndex else { return 0 }
        return min(1, max(0, Double(nowIndex) - progress.value))
    }
}

struct ReturnToNowTab: View {
    /// How far out of the edge the tab has come, 0...1.
    let reveal: Double
    var action: () -> Void

    /// How far the tab reaches in from the edge when fully out.
    static let maxDepth: CGFloat = 26
    static let height: CGFloat = 80
    /// Wider than the tab itself so the tap target clears 44pt, and no wider:
    /// the tab sits over the pager, and a swipe that starts on it does not
    /// reach the pages.
    private static let hitWidth: CGFloat = 44

    @State private var taps = 0

    var body: some View {
        // Smoothstep: the tab eases out of the edge instead of starting at
        // full speed, and settles into its full depth rather than stopping dead.
        let t = CGFloat(reveal * reveal * (3 - 2 * reveal))
        let depth = Self.maxDepth * t

        Button {
            taps += 1
            action()
        } label: {
            EdgeBump(depth: depth)
                .fill(Color.primary)
                .overlay {
                    TablerIcon("arrow-right", size: 14)
                        // Ink of the screen behind, so it inverts with the
                        // appearance exactly as the tab does.
                        .foregroundStyle(Color(uiColor: .systemBackground))
                        // Arrives once there is a tab to sit in, not while it is
                        // still a sliver.
                        .opacity(pow(Double(t), 2))
                        .scaleEffect(0.5 + 0.5 * t)
                        .position(x: Self.hitWidth - depth * 0.46, y: Self.height / 2)
                }
                .frame(width: Self.hitWidth, height: Self.height)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressScaleButtonStyle(scale: 0.92, anchor: .trailing))
        .allowsHitTesting(reveal > 0.6)
        .sensoryFeedback(.impact(weight: .light), trigger: taps)
        .accessibilityLabel("Na tekući mesec")
        .accessibilityHidden(reveal < 0.5)
    }
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

/// Press feedback for tappable things that are not glass buttons — the edge
/// tab keeps its own look, but still gives under the finger.
struct PressScaleButtonStyle: ButtonStyle {
    var scale: CGFloat = 0.96
    var anchor: UnitPoint = .center

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scale : 1, anchor: anchor)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

#Preview {
    VStack(spacing: 30) {
        ForEach([0.0, 0.3, 0.6, 1.0], id: \.self) { r in
            HStack {
                Text(String(format: "reveal %.1f", r))
                    .font(.system(size: 11, design: .monospaced))
                Spacer()
                ReturnToNowTab(reveal: r) {}
            }
        }
    }
    .background(Color(uiColor: .systemGroupedBackground))
}
