//
//  TablerIcon.swift
//  Receipt Tracker
//
//  Monochrome Tabler icons (tabler.io/icons, MIT — see THIRD_PARTY_LICENSES.md).
//  The whole app uses Tabler, never SF Symbols. Assets are template images in
//  Assets.xcassets named "ti-<name>". Unlike SF Symbols, custom images don't
//  scale with `.font()`, so the size is explicit here; tint comes from the
//  caller's `.foregroundStyle` (assets are template-rendered).
//

import SwiftUI

struct TablerIcon: View {
    let name: String
    var size: CGFloat

    init(_ name: String, size: CGFloat = 20) {
        self.name = name
        self.size = size
    }

    var body: some View {
        Image("ti-\(name)")
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
    }
}

/// An icon and its title, for list rows and small pills.
///
/// Not `Label`: in iOS 26 a `Label` whose icon is a Tabler image draws the icon
/// and silently drops the title — in lists and in plain buttons alike — which
/// left „Obriši sve podatke", „Dodaj iznos" and the receipt's „Kategorija"
/// pill as a lone glyph. Menus and swipe actions draw their own labels and are
/// fine with `Label`; everything else uses this.
struct TablerLabel: View {
    let title: String
    let icon: String
    var iconSize: CGFloat = 16
    var spacing: CGFloat = 12

    init(_ title: String, icon: String, iconSize: CGFloat = 16, spacing: CGFloat = 12) {
        self.title = title
        self.icon = icon
        self.iconSize = iconSize
        self.spacing = spacing
    }

    var body: some View {
        HStack(spacing: spacing) {
            TablerIcon(icon, size: iconSize)
            Text(title)
        }
    }
}
