//
//  DonutChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic pie/donut, drawn with animatable wedge `Shape`s (iOS 15.6-floor
//  reimplementation of the former Swift Charts `SectorMark` body — ADR-0007).
//  Angular gaps for separation, an always-on legend (a donut's identity is
//  otherwise color alone), a center slot for a hero figure, and a ≤6-slice
//  fold to "Other".
//

import SwiftUI

/// The hole size — `.pie` (full), `.ring` (default), `.thin`.
public enum DonutRatio: Sendable {
    case pie, ring, thin
    var value: CGFloat { switch self { case .pie: 0; case .ring: 0.6; case .thin: 0.75 } }
}

/// Molecule. `DonutChart(slices)` renders a proportional ring.
///
///     DonutChart([ChartSlice("Direct", 42), ChartSlice("Search", 30), ChartSlice("Social", 28)])
///         .innerRadius(.thin)
///         .label { Text("128k").textStyle(.headingSm) }
public struct DonutChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var envLocale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let slices: [ChartSlice]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var height: ChartHeight = .regular
    private var ratio: DonutRatio = .ring
    private var localeOverride: Locale?
    private var centerLabel: AnyView?

    public init(_ slices: [ChartSlice]) {   // R1 — content only
        self.slices = slices
    }

    private var locale: Locale { localeOverride ?? envLocale }
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    /// > 6 slices collapse the tail into a single neutral "Other" wedge — a
    /// donut with a dozen near-identical colors reads as noise.
    private var effectiveSlices: [ChartSlice] {
        guard slices.count > 6 else { return slices }
        let head = Array(slices.prefix(5))
        let tail = slices.dropFirst(5).reduce(0.0) { $0 + $1.value }
        return head + [ChartSlice(String(themeKit: "Other"), tail, color: .neutral)]
    }

    public var body: some View {
        let rendered = effectiveSlices
        let scale = ChartColorScale(slices: rendered, theme: theme)
        let fractions = Self.wedgeFractions(rendered)
        VStack(spacing: Theme.SpacingKey.xs.value) {
            ZStack {
                ZStack {
                    ForEach(Array(rendered.enumerated()), id: \.element.id) { index, slice in
                        DonutWedgeShape(start: fractions[index].start,
                                        end: fractions[index].end,
                                        innerRatio: ratio.value)
                            .fill(scale.range[index])
                            .accessibilityLabel(slice.label)
                            .accessibilityValue(chartValueFormatted(slice.value, locale: locale))
                    }
                }
                // Sectors progress clockwise from 12 o'clock; mirror the ring
                // (a text-free drawing) under RTL like the family's other paths.
                .flipsForRightToLeftLayoutDirection(true)
                if let centerLabel, ratio != .pie {
                    centerLabel   // centered in the ring's hole
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            ChartLegendRow(theme: theme, entries: scale.legendEntries)
        }
        .frame(height: height.value)
        .animation(motion, value: effectiveSlices)
        .accessibilityLabel(Text(String(themeKit: "Donut chart with slices \(rendered.map(\.label).joined(separator: ", ")).")))
    }

    /// Cumulative start/end fractions (0...1) per slice.
    static func wedgeFractions(_ slices: [ChartSlice]) -> [(start: Double, end: Double)] {
        let total = slices.reduce(0.0) { $0 + max(0, $1.value) }
        guard total > 0 else { return slices.map { _ in (0, 0) } }
        var cumulative = 0.0
        return slices.map { slice in
            let start = cumulative / total
            cumulative += max(0, slice.value)
            return (start, cumulative / total)
        }
    }
}

/// One donut sector: outer arc from `start` to `end` (fractions of a turn,
/// clockwise from 12 o'clock), an inner hole at `innerRatio`, and a 2pt
/// angular gap to its neighbors. Animatable, so slice-value changes tween.
struct DonutWedgeShape: Shape {
    var start: Double
    var end: Double
    var innerRatio: CGFloat

    /// The angular gap between neighboring wedges, in points at the rim.
    private static let angularInset: CGFloat = 2

    var animatableData: AnimatablePair<Double, Double> {
        get { AnimatablePair(start, end) }
        set {
            start = newValue.first
            end = newValue.second
        }
    }

    func path(in rect: CGRect) -> Path {
        let outerRadius = min(rect.width, rect.height) / 2
        guard outerRadius > 0, end > start else { return Path() }
        let innerRadius = outerRadius * min(max(innerRatio, 0), 0.95)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        // Half the 2pt gap per edge, as an angle at the outer radius.
        let inset = Double(Self.angularInset / 2 / outerRadius)
        var from = -Double.pi / 2 + start * 2 * .pi + inset
        var to = -Double.pi / 2 + end * 2 * .pi - inset
        if to < from {   // sliver thinner than the gap — collapse to its midline
            let mid = (from + to) / 2
            from = mid
            to = mid
        }
        var path = Path()
        path.addArc(center: center, radius: outerRadius,
                    startAngle: .radians(from), endAngle: .radians(to), clockwise: false)
        if innerRadius > 0 {
            path.addArc(center: center, radius: innerRadius,
                        startAngle: .radians(to), endAngle: .radians(from), clockwise: true)
        } else {
            path.addLine(to: center)
        }
        path.closeSubpath()
        return path
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DonutChart {
    /// Chart height — `.compact` / `.regular` (default) / `.tall`.
    func height(_ h: ChartHeight) -> Self { copy { $0.height = h } }

    /// Hole size — `.pie` (no hole) / `.ring` (default) / `.thin`.
    func innerRadius(_ r: DonutRatio) -> Self { copy { $0.ratio = r } }

    /// Center content for a ring (ignored for `.pie`) — a total, a percentage.
    func label<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.centerLabel = AnyView(content()) }
    }

    /// Locale for value formatting; defaults to the environment locale.
    func locale(_ locale: Locale) -> Self { copy { $0.localeOverride = locale } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("DonutChart") {
        PreviewCase("Thin ring + center label") {
            DonutChart([
                ChartSlice("Direct", 42), ChartSlice("Search", 30),
                ChartSlice("Social", 18), ChartSlice("Referral", 10),
            ])
            .innerRadius(.thin)
            .label { VStack(spacing: 0) { Text("100").textStyle(.headingSm); Text("visits").textStyle(.overline400) } }
        }
        PreviewCase("Pie · compact · semantic colors") {
            DonutChart([ChartSlice("Yes", 68, color: .success), ChartSlice("No", 32, color: .error)])
                .innerRadius(.pie).height(.compact)
        }
        // > 6 slices fold the tail into a neutral "Other" wedge.
        PreviewCase("Folds to Other (8 slices)") {
            DonutChart((1...8).map { ChartSlice("Slice \($0)", Double(20 - $0)) })
                .height(.compact)
        }
    }
}
