//
//  AreaChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic area chart — LineChart's sibling. Overlaid translucent washes under
//  2pt outlines by default; `.stacked()` sums the series into bands.
//

import SwiftUI
import Charts

/// Molecule. `AreaChart(series)` fills the region under each series.
///
///     AreaChart([ChartSeries("Visitors", points)]).height(.tall)
///     AreaChart(series).stacked()
public struct AreaChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var envLocale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let series: [ChartSeries]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var height: ChartHeight = .regular
    private var legendVisible: Bool?
    private var showsGrid = true
    private var curved = false
    private var stacked = false
    private var localeOverride: Locale?

    @ControllableState private var selectedX: String?

    public init(_ series: [ChartSeries]) {   // R1 — content only
        self.series = series
        self._selectedX = ControllableState(wrappedValue: nil)
    }

    public init(_ series: [ChartSeries], selection: Binding<String?>) {
        self.series = series
        self._selectedX = ControllableState(wrappedValue: nil, external: selection)
    }

    private var locale: Locale { localeOverride ?? envLocale }
    private var scale: ChartColorScale { ChartColorScale(series: series) }
    private var showsLegend: Bool { legendVisible ?? (series.count >= 2) }
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        Chart {
            ForEach(Array(series.enumerated()), id: \.element.id) { _, s in
                ForEach(s.points) { point in
                    AreaMark(x: .value("Category", point.x),
                             y: .value("Value", point.y),
                             stacking: stacked ? .standard : .unstacked)
                        .foregroundStyle(by: .value("Series", s.label))
                        .opacity(stacked ? 0.85 : 0.18)
                        .interpolationMethod(curved ? .monotone : .linear)
                        .accessibilityLabel("\(s.label), \(point.x)")
                        .accessibilityValue(chartValueFormatted(point.y, locale: locale))
                }
                // Overlaid washes need a crisp edge to stay legible; stacked
                // bands read fine on their own.
                if !stacked {
                    ForEach(s.points) { point in
                        LineMark(x: .value("Category", point.x), y: .value("Value", point.y))
                            .foregroundStyle(by: .value("Series", s.label))
                            .interpolationMethod(curved ? .monotone : .linear)
                            .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                    }
                }
            }
            if let selectedX {
                RuleMark(x: .value("Category", selectedX))
                    .foregroundStyle(theme.border(.borderPrimary))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .annotation(position: .top, spacing: 6, overflowResolution: .init(x: .fit(to: .chart), y: .disabled)) {
                        annotationCard(for: selectedX)
                    }
            }
        }
        .chartForegroundStyleScale(domain: scale.domain, range: scale.range)
        .chartLegend(showsLegend ? .visible : .hidden)
        .chartXSelection(value: $selectedX)
        .themedChartAxes(theme: theme, showsGrid: showsGrid)
        .frame(height: height.value)
        .animation(motion, value: selectedX)
        .accessibilityLabel(Text(String(themeKit: "Area chart with series \(series.map(\.label).joined(separator: ", ")).")))
    }

    private func annotationCard(for x: String) -> some View {
        let rows: [ChartScrubRow] = series.enumerated().compactMap { index, s in
            guard let point = s.points.first(where: { $0.x == x }) else { return nil }
            return ChartScrubRow(label: s.label,
                                 value: chartValueFormatted(point.y, locale: locale),
                                 color: ChartPalette.hue(explicit: s.color, at: index).solid)
        }
        return ChartScrubCard(theme: theme, title: x, rows: rows)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AreaChart {
    /// Chart height — `.compact` / `.regular` (default) / `.tall`.
    func height(_ h: ChartHeight) -> Self { copy { $0.height = h } }

    /// Force the legend on/off; default shows it for two or more series.
    func showsLegend(_ on: Bool) -> Self { copy { $0.legendVisible = on } }

    /// Hairline grid lines (default on).
    func showsGrid(_ on: Bool = true) -> Self { copy { $0.showsGrid = on } }

    /// Monotone curve interpolation instead of straight segments (default off).
    func curved(_ on: Bool = true) -> Self { copy { $0.curved = on } }

    /// Stack the series into cumulative bands instead of overlaid washes.
    func stacked(_ on: Bool = true) -> Self { copy { $0.stacked = on } }

    /// Locale for value/tick formatting; defaults to the environment locale.
    func locale(_ locale: Locale) -> Self { copy { $0.localeOverride = locale } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    // The chart is scrub-interactive; each cell is a single static frame.
    let series = [
        ChartSeries("Organic", [ChartPoint("Mon", 30), ChartPoint("Tue", 42), ChartPoint("Wed", 35), ChartPoint("Thu", 50), ChartPoint("Fri", 48)]),
        ChartSeries("Paid", [ChartPoint("Mon", 18), ChartPoint("Tue", 22), ChartPoint("Wed", 28), ChartPoint("Thu", 24), ChartPoint("Fri", 33)]),
    ]
    PreviewMatrix("AreaChart") {
        PreviewCase("Overlaid + curved") { AreaChart(series).curved() }
        PreviewCase("Stacked · compact") { AreaChart(series).stacked().height(.compact) }
        PreviewCase("Single series · no grid") { AreaChart([series[0]]).showsGrid(false) }
    }
}
