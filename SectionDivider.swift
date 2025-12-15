//
//  SectionDivider.swift
//  Receipt Tracker
//
//  Created by Bogdan Stefanovic on 15. 12. 2025..
//

import SwiftUI

struct SectionDivider: View {
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            // Left line with equals pattern
            EqualsPattern()
            
            // Title
            Text(title)
                .font(.system(.subheadline, design: .monospaced, weight: .semibold))
                .foregroundStyle(.secondary)
            
            // Right line with equals pattern
            EqualsPattern()
        }
        .padding(.vertical, 8)
    }
}

struct EqualsPattern: View {
    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                Text("=")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    SectionDivider(title: "Računi")
        .padding()
}
