//
//  SearchItemCardView.swift
//  Receipt Tracker
//

import SwiftUI

struct SearchItemCardView: View {
    let itemName: String
    let merchantName: String
    let date: Date
    let lineTotal: Decimal

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 16) {
                Text(itemName)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Spacer()

                Text(lineTotal.asRSD)
                    .font(.system(.subheadline, design: .monospaced, weight: .regular))
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            HStack {
                Text(merchantName)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
                Text(date.formatted(.dateTime.day().month(.abbreviated)))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.04), radius: 1.5, x: 0, y: 1)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.03), radius: 3, x: 0, y: 6)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.02), radius: 4, x: 0, y: 13)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0.01), radius: 4.5, x: 0, y: 24)
        .shadow(color: Color(red: 0.2, green: 0.2, blue: 0.2).opacity(0), radius: 5, x: 0, y: 37)
    }
}
