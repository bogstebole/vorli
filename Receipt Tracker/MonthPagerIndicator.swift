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
        let widths = months.indices.map { width(at: $0) }
        let centres = centres(of: widths)
        let total = widths.reduce(0, +) + Self.gap * CGFloat(max(0, months.count - 1))

        HStack(spacing: Self.gap) {
            ForEach(Array(months.enumerated()), id: \.element) { index, month in
                chip(month, at: index)
            }
        }
        .frame(width: total, height: Self.chipHeight)
        // Slide the whole row so the month being swiped to lands dead centre.
        .offset(x: total / 2 - focusCentre(centres))
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

    private func chip(_ month: Date, at index: Int) -> some View {
        let c = closeness(at: index)
        return ZStack {
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(fillOpacity(at: index)))

            Text(label(for: month))
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
                .scaleEffect(textScale(at: index))
                .opacity(pow(c, 1.4))
        }
        // Size first, clip second. The other way round clips the label at its
        // natural width and then lets that full-width capsule overflow the
        // dot-sized slot, which smears every collapsed month into its
        // neighbours.
        .frame(width: width(at: index), height: height(at: index))
        .clipShape(Capsule(style: .continuous))
    }

    // MARK: - Geometry

    /// 1 when the month is centred, 0 once it is a full page away.
    private func closeness(at index: Int) -> Double {
        max(0, 1 - abs(progress - Double(index)))
    }

    /// Eased so a month stays a dot until it is genuinely on its way in —
    /// a linear ramp made every neighbour look half-open all the time.
    private func expansion(at index: Int) -> CGFloat {
        CGFloat(pow(closeness(at: index), 1.7))
    }

    /// How much of a dot is left this far out: full size right next to the
    /// current month, gone by four months away. This is what makes the row read
    /// as a run of months receding into the distance rather than a fixed strip
    /// of ticks — the near ones are bigger and darker, the far ones shrink and
    /// fade off the ends.
    private func neighbourWeight(at index: Int) -> CGFloat {
        let distance = abs(progress - Double(index))
        guard distance > 1 else { return 1 }
        return CGFloat(max(0, 1 - (distance - 1) / Self.falloff))
    }

    private func dotSize(at index: Int) -> CGFloat {
        Self.minDotSize + (Self.maxDotSize - Self.minDotSize) * neighbourWeight(at: index)
    }

    /// What the chip measures when fully open — SF Mono is monospaced, so the
    /// label's width is just its character count.
    private func fullWidth(at index: Int) -> CGFloat {
        CGFloat(label(for: months[index]).count) * Self.advance + Self.horizontalPadding
    }

    private func width(at index: Int) -> CGFloat {
        let dot = dotSize(at: index)
        return dot + (fullWidth(at: index) - dot) * expansion(at: index)
    }

    /// 1 when the chip is open, shrinking to nothing as it closes into a dot.
    private func textScale(at index: Int) -> CGFloat {
        let full = fullWidth(at: index)
        guard full > 0 else { return 0 }
        return min(1, width(at: index) / full)
    }

    private func height(at index: Int) -> CGFloat {
        let dot = dotSize(at: index)
        return dot + (Self.chipHeight - dot) * expansion(at: index)
    }

    /// Dots darken as they near the current month, then hand over to the
    /// chip's own fill as one opens up.
    private func fillOpacity(at index: Int) -> Double {
        let dot = 0.06 + 0.12 * Double(neighbourWeight(at: index))
        return dot + (Self.chipFillOpacity - dot) * Double(expansion(at: index))
    }

    private func centres(of widths: [CGFloat]) -> [CGFloat] {
        var result: [CGFloat] = []
        result.reserveCapacity(widths.count)
        var x: CGFloat = 0
        for w in widths {
            result.append(x + w / 2)
            x += w + Self.gap
        }
        return result
    }

    /// Where the row should be pinned: the centre of whichever month the
    /// pager is on, interpolated across the two it sits between mid-drag.
    private func focusCentre(_ centres: [CGFloat]) -> CGFloat {
        guard !centres.isEmpty else { return 0 }
        let clamped = min(max(progress, 0), Double(centres.count - 1))
        let low = Int(clamped.rounded(.down))
        let high = min(low + 1, centres.count - 1)
        let t = CGFloat(clamped - Double(low))
        return centres[low] + (centres[high] - centres[low]) * t
    }

    // MARK: - Text

    private func label(for month: Date) -> String {
        Self.formatter.string(from: month).sentenceCased
    }

    private var accessibilityLabel: String {
        let index = min(max(Int(progress.rounded()), 0), max(0, months.count - 1))
        guard months.indices.contains(index) else { return "Mesec" }
        return "Mesec: \(label(for: months[index]))"
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
