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
        GeometryReader { geometry in
            Path { path in
                // First dashed line
                path.move(to: CGPoint(x: 0, y: 0))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                
                // Second dashed line
                path.move(to: CGPoint(x: 0, y: 3))
                path.addLine(to: CGPoint(x: geometry.size.width, y: 3))
            }
            .stroke(style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
            .foregroundStyle(.tertiary)
        }
        .frame(height: 4)
    }
}

#Preview {
    SectionDivider(title: "Računi")
        .padding()
}
