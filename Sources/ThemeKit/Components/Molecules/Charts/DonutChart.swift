//
//  DonutChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic pie/donut over Swift Charts `SectorMark` (iOS 17). Angular gaps for
//  separation, an always-on legend (a donut's identity is otherwise color
//  alone), a center slot for a hero figure, and a ≤6-slice fold to "Other".
//

import SwiftUI
import Charts

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

    private var scale: ChartColorScale { ChartColorScale(slices: effectiveSlices) }

    public var body: some View {
        Chart(effectiveSlices) { slice in
            SectorMark(angle: .value("Value", slice.value),
                       innerRadius: .ratio(ratio.value),
                       angularInset: 2)
                .foregroundStyle(by: .value("Slice", slice.label))
                .cornerRadius(2)
                .accessibilityLabel(slice.label)
                .accessibilityValue(chartValueFormatted(slice.value, locale: locale))
        }
        .chartForegroundStyleScale(domain: scale.domain, range: scale.range)
        .chartLegend(.visible)
        .chartBackground { _ in
            if let centerLabel, ratio != .pie {
                centerLabel.frame(maxWidth: .infinity, maxHeight: .infinity)   // center in the plot area
            }
        }
        .frame(height: height.value)
        .animation(motion, value: effectiveSlices)
        .accessibilityLabel(Text(String(themeKit: "Donut chart with slices \(effectiveSlices.map(\.label).joined(separator: ", ")).")))
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
