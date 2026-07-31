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
                        .font(.system(.subheadline, design: .monospaced, weight: .semibold))
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
