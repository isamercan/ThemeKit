//
//  BarChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic grouped or stacked bar chart over Swift Charts, token-styled. One
//  baseline, never a dual axis; rounded bar caps; per-category scrub readout.
//

import SwiftUI
import Charts

public enum BarChartMode: Sendable { case grouped, stacked }

/// Molecule. `BarChart(series)` draws bars per category, grouped by default.
///
///     BarChart([
///         ChartSeries("Revenue", [ChartPoint("Q1", 120), ChartPoint("Q2", 150)]),
///         ChartSeries("Cost", [ChartPoint("Q1", 80), ChartPoint("Q2", 95)]),
///     ]).mode(.stacked)
public struct BarChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var envLocale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let series: [ChartSeries]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var height: ChartHeight = .regular
    private var legendVisible: Bool?
    private var showsGrid = true
    private var mode: BarChartMode = .grouped
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
                    if mode == .grouped {
                        BarMark(x: .value("Category", point.x), y: .value("Value", point.y))
                            .foregroundStyle(by: .value("Series", s.label))
                            .position(by: .value("Series", s.label))
                            .cornerRadius(4)
                            .accessibilityLabel("\(s.label), \(point.x)")
                            .accessibilityValue(chartValueFormatted(point.y, locale: locale))
                    } else {
                        BarMark(x: .value("Category", point.x), y: .value("Value", point.y))
                            .foregroundStyle(by: .value("Series", s.label))
                            .cornerRadius(4)
                            .accessibilityLabel("\(s.label), \(point.x)")
                            .accessibilityValue(chartValueFormatted(point.y, locale: locale))
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
        .accessibilityLabel(Text(String(themeKit: "Bar chart with series \(series.map(\.label).joined(separator: ", ")).")))
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

public extension BarChart {
    /// Chart height — `.compact` / `.regular` (default) / `.tall`.
    func height(_ h: ChartHeight) -> Self { copy { $0.height = h } }

    /// Force the legend on/off; default shows it for two or more series.
    func showsLegend(_ on: Bool) -> Self { copy { $0.legendVisible = on } }

    /// Hairline grid lines (default on).
    func showsGrid(_ on: Bool = true) -> Self { copy { $0.showsGrid = on } }

    /// `.grouped` (default) places series side by side; `.stacked` sums them.
    func mode(_ m: BarChartMode) -> Self { copy { $0.mode = m } }

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
        ChartSeries("Revenue", [ChartPoint("Q1", 120), ChartPoint("Q2", 150), ChartPoint("Q3", 138), ChartPoint("Q4", 172)]),
        ChartSeries("Cost", [ChartPoint("Q1", 80), ChartPoint("Q2", 95), ChartPoint("Q3", 90), ChartPoint("Q4", 110)]),
    ]
    PreviewMatrix("BarChart") {
        PreviewCase("Grouped (default)") { BarChart(series) }
        PreviewCase("Stacked · compact") { BarChart(series).mode(.stacked).height(.compact) }
        PreviewCase("Single series · no grid") { BarChart([series[0]]).showsGrid(false) }
    }
}
