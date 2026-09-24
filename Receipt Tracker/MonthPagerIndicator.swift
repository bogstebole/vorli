//
//  MonthPagerIndicator.swift
//  Receipt Tracker
//
//  The month label on Home, doubling as the pager's position indicator.
//
//  Neighbouring months sit either side of the current one as dots. They are
//  not decoration: they are the same chips, collapsed. As the pager is dragged
//  the chip you are leaving contracts back into a dot while the one you are
//  heading for swells into a full label, in step with the finger — so the
//  screen says "there is more this way" before anything has been let go of.
//
//  Everything is driven by `progress`, the pager's continuous position (2.4 =
//  40% of the way from the third month to the fourth). Nothing here animates
//  on its own; the finger is the clock.
//

import SwiftUI
import UIKit

/// The pager's live position, kept out of Home's own state.
///
/// Home used to hold the scroll offset as `@State`, so every frame of a swipe
/// re-ran the whole screen — every month page, every figure. Held here, the
/// only view that reads `value` is the indicator, so it is the only thing the
/// finger invalidates.
@Observable
final class PagerProgress {
    var value: Double = 0
}

/// Reads the live position and hands it to the indicator. Its own view so the
/// observation lands here and nowhere else.
struct LiveMonthIndicator: View {
    let months: [Date]
    let progress: PagerProgress

    var body: some View {
        MonthPagerIndicator(months: months, progress: progress.value)
    }
}

struct MonthPagerIndicator: View {
    let months: [Date]
    /// Continuous page position from the scroll view, not the settled index.
    let progress: Double

    // MARK: - Metrics

    /// A dot right beside the current month is at full size; four months out
    /// it has shrunk to a speck and all but gone.
    private static let maxDotSize: CGFloat = 8
    private static let minDotSize: CGFloat = 2.5
    private static let falloff: Double = 3
    private static let chipFillOpacity: Double = 0.13
    private static let chipHeight: CGFloat = 34
    private static let gap: CGFloat = 8
    private static let horizontalPadding: CGFloat = 22
    /// SF Mono is monospaced, so one measurement covers every label.
    private static let advance: CGFloat = {
        let font = UIFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        return ("0" as NSString).size(withAttributes: [.font: font]).width - 0.43
    }()

    var body: some View {
        // Worked out once per frame, then read — this body runs on every frame
        // of a swipe, so nothing below recomputes what a chip already knows.
        let chips = months.indices.map { layout(at: $0) }
        let total = chips.reduce(0) { $0 + $1.width } + Self.gap * CGFloat(max(0, chips.count - 1))

        HStack(spacing: Self.gap) {
            ForEach(chips) { chip in
                chipView(chip)
            }
        }
        .frame(width: total, height: Self.chipHeight)
        // Slide the whole row so the month being swiped to lands dead centre.
        .offset(x: total / 2 - focusCentre(chips))
        .frame(width: 300, height: Self.chipHeight)
        .clipped()
        // Neighbours fall away at the edges instead of stopping dead.
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black, location: 0.12),
                    .init(color: .black, location: 0.88),
                    .init(color: .clear, location: 1)
                ],
                startPoint: .leading, endPoint: .trailing
            )
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("Prevuci levo ili desno za drugi mesec")
    }

    // MARK: - Chip

    private struct ChipLayout: Identifiable {
        let id: Date
        let label: String
        let width: CGFloat
        let height: CGFloat
        let textScale: CGFloat
        let textOpacity: Double
        let fillOpacity: Double
    }

    private func chipView(_ chip: ChipLayout) -> some View {
        ZStack {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(chip.fillOpacity))

            Text(chip.label)
                .font(.system(size: 13, design: .monospaced))
                .tracking(-0.43)
                .foregroundStyle(.primary)
                .lineLimit(1)
                .fixedSize()
                // Scales with the chip rather than being cropped by it. The
                // factor is the chip's own width over the width it wants, so
                // the label and its padding shrink at exactly the rate the
                // capsule does — the month contracts into the dot instead of
                // sliding out through a letterbox.
                .scaleEffect(chip.textScale)
                .opacity(chip.textOpacity)
        }
        // Size first, clip second. The other way round clips the label at its
        // natural width and then lets that full-width capsule overflow the
        // dot-sized slot, which smears every collapsed month into its
        // neighbours.
        .frame(width: chip.width, height: chip.height)
        .clipShape(Capsule(style: .continuous))
    }

    // MARK: - Geometry

    private func layout(at index: Int) -> ChipLayout {
        let month = months[index]
        let label = Self.label(for: month)
        let distance = abs(progress - Double(index))

        // 1 when the month is centred, 0 once it is a full page away. Eased so
        // a month stays a dot until it is genuinely on its way in — a linear
        // ramp made every neighbour look half-open all the time.
        let closeness = max(0, 1 - distance)
        let expansion = CGFloat(pow(closeness, 1.7))

        // How much of a dot is left this far out: full size right next to the
        // current month, gone by four months away. The near ones are bigger and
        // darker, the far ones shrink and fade off the ends, so the row reads
        // as a run of months receding rather than a strip of ticks.
        let weight: CGFloat = distance > 1
            ? CGFloat(max(0, 1 - (distance - 1) / Self.falloff))
            : 1
        let dot = Self.minDotSize + (Self.maxDotSize - Self.minDotSize) * weight

        // SF Mono is monospaced, so the label's width is just its length.
        let full = CGFloat(label.count) * Self.advance + Self.horizontalPadding
        let width = dot + (full - dot) * expansion

        // Dots darken as they near the current month, then hand over to the
        // chip's own fill as one opens up.
        let dotFill = 0.06 + 0.12 * Double(weight)

        return ChipLayout(
            id: month,
            label: label,
            width: width,
            height: dot + (Self.chipHeight - dot) * expansion,
            textScale: full > 0 ? min(1, width / full) : 0,
            textOpacity: pow(closeness, 1.4),
            fillOpacity: dotFill + (Self.chipFillOpacity - dotFill) * Double(expansion)
        )
    }

    /// Where the row should be pinned: the centre of whichever month the
    /// pager is on, interpolated across the two it sits between mid-drag.
    private func focusCentre(_ chips: [ChipLayout]) -> CGFloat {
        guard !chips.isEmpty else { return 0 }
        var centres: [CGFloat] = []
        centres.reserveCapacity(chips.count)
        var x: CGFloat = 0
        for chip in chips {
            centres.append(x + chip.width / 2)
            x += chip.width + Self.gap
        }
        let clamped = min(max(progress, 0), Double(centres.count - 1))
        let low = Int(clamped.rounded(.down))
        let high = min(low + 1, centres.count - 1)
        let t = CGFloat(clamped - Double(low))
        return centres[low] + (centres[high] - centres[low]) * t
    }

    // MARK: - Text

    /// Month names never change, and this runs for every month on every frame
    /// of a swipe — so each is formatted once and remembered.
    private static var labelCache: [Date: String] = [:]

    private static func label(for month: Date) -> String {
        if let cached = labelCache[month] { return cached }
        let label = formatter.string(from: month).sentenceCased
        labelCache[month] = label
        return label
    }

    private var accessibilityLabel: String {
        let index = min(max(Int(progress.rounded()), 0), max(0, months.count - 1))
        guard months.indices.contains(index) else { return "Mesec" }
        return "Mesec: \(Self.label(for: months[index]))"
    }

    private static let formatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "sr_Latn_RS")
        f.dateFormat = "MMMM yyyy"
        return f
    }()
}

#Preview {
    let calendar = Calendar.current
    let now = Date()
    let months = (-4...0).compactMap { calendar.date(byAdding: .month, value: $0, to: now) }

    return VStack(spacing: 40) {
        MonthPagerIndicator(months: months, progress: 4)
        MonthPagerIndicator(months: months, progress: 3.5)
        MonthPagerIndicator(months: months, progress: 3)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(Color(uiColor: .systemGroupedBackground))
}
