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
