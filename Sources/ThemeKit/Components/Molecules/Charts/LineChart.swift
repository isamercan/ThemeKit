//
//  LineChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic multi-series line chart over Swift Charts, token-styled. Categorical
//  color law from `ChartPalette`; hairline grid/axes; a built-in scrub readout
//  (the "chart tooltip") with a token card; controlled or uncontrolled
//  selection via `ControllableState`.
//

import SwiftUI
import Charts

/// Molecule. `LineChart(series)` draws one line per `ChartSeries`.
///
///     LineChart([
///         ChartSeries("2025", [ChartPoint("Jan", 12), ChartPoint("Feb", 18), ChartPoint("Mar", 15)]),
///         ChartSeries("2026", [ChartPoint("Jan", 20), ChartPoint("Feb", 16), ChartPoint("Mar", 24)]),
///     ]).curved().height(.tall)
public struct LineChart: View {
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
    private var showsPoints = false
    private var localeOverride: Locale?

    @ControllableState private var selectedX: String?

    public init(_ series: [ChartSeries]) {   // R1 — content only (uncontrolled scrub)
        self.series = series
        self._selectedX = ControllableState(wrappedValue: nil)
    }

    /// Controlled scrub selection — the caller owns the highlighted x category.
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
                    LineMark(x: .value("Category", point.x), y: .value("Value", point.y))
                        .foregroundStyle(by: .value("Series", s.label))
                        .interpolationMethod(curved ? .monotone : .linear)
                        .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                        .accessibilityLabel("\(s.label), \(point.x)")
                        .accessibilityValue(formatted(point.y))
                }
                if showsPoints {
                    ForEach(s.points) { point in
                        PointMark(x: .value("Category", point.x), y: .value("Value", point.y))
                            .foregroundStyle(by: .value("Series", s.label))
                            .symbolSize(60)
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
        .accessibilityLabel(Text(a11ySummary))
    }

    /// The scrub readout: every series' value at the selected category, each
    /// dotted in its own palette color, on the standard token card.
    private func annotationCard(for x: String) -> some View {
        let rows: [ChartScrubRow] = series.enumerated().compactMap { index, s in
            guard let point = s.points.first(where: { $0.x == x }) else { return nil }
            return ChartScrubRow(label: s.label,
                                 value: chartValueFormatted(point.y, locale: locale),
                                 color: ChartPalette.hue(explicit: s.color, at: index).solid)
        }
        return ChartScrubCard(theme: theme, title: x, rows: rows)
    }

    private func formatted(_ value: Double) -> String { chartValueFormatted(value, locale: locale) }

    private var a11ySummary: String {
        String(themeKit: "Line chart with series \(series.map(\.label).joined(separator: ", ")).")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LineChart {
    /// Chart height — `.compact` / `.regular` (default) / `.tall`.
    func height(_ h: ChartHeight) -> Self { copy { $0.height = h } }

    /// Force the legend on/off; default shows it for two or more series.
    func showsLegend(_ on: Bool) -> Self { copy { $0.legendVisible = on } }

    /// Hairline grid lines (default on).
    func showsGrid(_ on: Bool = true) -> Self { copy { $0.showsGrid = on } }

    /// Monotone curve interpolation instead of straight segments (default off).
    func curved(_ on: Bool = true) -> Self { copy { $0.curved = on } }

    /// Draw a marker at every data vertex (default off).
    func showsPoints(_ on: Bool = true) -> Self { copy { $0.showsPoints = on } }

    /// Locale for value/tick formatting; defaults to the environment locale.
    func locale(_ locale: Locale) -> Self { copy { $0.localeOverride = locale } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var selected: String?
        let series = [
            ChartSeries("2025", [ChartPoint("Jan", 12), ChartPoint("Feb", 18), ChartPoint("Mar", 15), ChartPoint("Apr", 22), ChartPoint("May", 19)]),
            ChartSeries("2026", [ChartPoint("Jan", 20), ChartPoint("Feb", 16), ChartPoint("Mar", 24), ChartPoint("Apr", 21), ChartPoint("May", 28)]),
        ]
        var body: some View {
            VStack(spacing: 24) {
                LineChart(series, selection: $selected).curved().showsPoints()
                LineChart([series[0]]).height(.compact).showsGrid(false)
            }
            .padding()
        }
    }
    return Demo()
}
