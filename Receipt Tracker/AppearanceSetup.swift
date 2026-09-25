//
//  AppearanceSetup.swift
//  Receipt Tracker
//
//  The app is monospaced throughout, but `navigationTitle` renders with the
//  system font and SwiftUI (iOS 26) ignores UINavigationBar's appearance proxy
//  for it. The only thing that works is supplying the title as a `.principal`
//  toolbar item — this modifier does that in one place instead of on every
//  screen, and keeps `navigationTitle` set so back buttons and VoiceOver still
//  have the real title.
//
//  Screens that already provide their own `.principal` item (Pretraga,
//  Skeniraj) must not use this — two principal items collide.
//

import SwiftUI

private struct MonospacedNavigationTitle: ViewModifier {
    let title: String

    func body(content: Content) -> some View {
        content
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(title)
                        .font(.system(.subheadline, design: .monospaced, weight: .medium))
                        .foregroundStyle(.primary)
                }
            }
    }
}

extension View {
    /// Inline navigation title in the app's monospaced face.
    func monoNavigationTitle(_ title: String) -> some View {
        modifier(MonospacedNavigationTitle(title: title))
    }
}

/// Segmented pickers are drawn by UIKit, which ignores SwiftUI's `.font` and
/// colours on them. The appearance proxy is the one handle on their type and
/// their greys, so both are set here, once, before the first one is built.
///
/// The system greys are cool — a blue cast next to the app's neutral cards,
/// and the selected segment in dark mode a pale slate. Instead the track takes
/// the cards' own surface and the selected segment the step up from it, both
/// from the asset catalogue, so they follow light, dark and Increase Contrast
/// along with the cards rather than being numbers copied off a screenshot.
enum SegmentedControlAppearance {
    private static var applied = false

    static func applyOnce() {
        guard !applied else { return }
        applied = true
        let proxy = UISegmentedControl.appearance()
        proxy.setTitleTextAttributes(
            [.font: UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)], for: .normal
        )
        proxy.setTitleTextAttributes(
            [.font: UIFont.monospacedSystemFont(ofSize: 13, weight: .medium)], for: .selected
        )
        // Read on the main actor here; UIKit resolves the provider elsewhere.
        let surface = UIColor.surface
        proxy.backgroundColor = UIColor { trackColor(for: $0, surface: surface) }
        proxy.selectedSegmentTintColor = .surfaceSelected
    }

    /// The colour to hand UIKit so the track comes out as a card would on the
    /// same background.
    ///
    /// Not the surface itself: UIKit lays the tertiary system fill over the
    /// track, a cool grey film, so this works backwards — the card colour is
    /// the surface over the screen behind it, and the track is the colour that
    /// turns into that once the film is on. The film only ever darkens in
    /// light mode, so there the track stops at white, a shade under the cards.
    nonisolated private static func trackColor(for traits: UITraitCollection, surface surfaceColor: UIColor) -> UIColor {
        let backdrop = components(of: .systemBackground, in: traits)
        let surface = components(of: surfaceColor, in: traits)
        let film = components(of: .tertiarySystemFill, in: traits)

        let card = (0..<3).map { surface[$0] * surface[3] + backdrop[$0] * (1 - surface[3]) }
        let base = (0..<3).map { channel in
            min(1, max(0, (card[channel] - film[channel] * film[3]) / (1 - film[3])))
        }
        return UIColor(red: base[0], green: base[1], blue: base[2], alpha: 1)
    }

    nonisolated private static func components(of color: UIColor, in traits: UITraitCollection) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }
}
