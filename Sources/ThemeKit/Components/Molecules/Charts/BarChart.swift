//
//  BarChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic grouped or stacked bar chart, Canvas-drawn and token-styled (iOS
//  15.6-floor reimplementation — ADR-0007; shared chrome in ChartSupport.swift).
//  One baseline, never a dual axis; rounded bar caps; per-category scrub
//  readout.
//

import SwiftUI

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

    // Fixed mark geometry (chart-internal, not exposed knobs).
    private static let capRadius: CGFloat = 4        // rounded bar caps
    private static let groupFillRatio: CGFloat = 0.7 // bars' share of a category band
    private static let groupGap: CGFloat = 2         // gap between grouped bars

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
    private var showsLegend: Bool { legendVisible ?? (series.count >= 2) }
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        let categories = chartCategories(series)
        let scale = ChartColorScale(series: series, theme: theme)
        let resolved = Array(zip(series, scale.range))
        // Per-series value per category (nil = no mark), grouped mode.
        let grouped = mode == .grouped
        let values: [[Double?]] = grouped
            ? series.map { s in categories.map { c in s.points.first(where: { $0.x == c })?.y } }
            : []
        let bands = grouped ? [] : ChartStacking.bands(series: series, categories: categories)
        let dataMax = grouped
            ? series.flatMap(\.points).map(\.y).max() ?? 0
            : ChartStacking.maxTotal(series: series, categories: categories)
        ChartXYChrome(
            theme: theme,
            categories: categories,
            yDataMax: dataMax,
            showsGrid: showsGrid,
            legend: showsLegend ? scale.legendEntries : nil,
            locale: locale,
            selection: $selectedX,
            scrubRows: LineChart.scrubRowsBuilder(resolved: resolved, locale: locale),
            drawMarks: { context, geom in
                if grouped {
                    Self.drawGroupedBars(context, geom: geom, values: values, colors: resolved.map(\.1))
                } else {
                    Self.drawStackedBars(context, geom: geom, bands: bands, colors: resolved.map(\.1))
                }
            }
        )
        .frame(height: height.value)
        .animation(motion, value: selectedX)
        .accessibilityLabel(Text(String(themeKit: "Bar chart with series \(series.map(\.label).joined(separator: ", ")).")))
    }

    // MARK: Mark drawing (LTR plot coordinates; the chrome mirrors for RTL)

    private static func drawGroupedBars(_ context: GraphicsContext,
                                        geom: ChartPlotGeometry,
                                        values: [[Double?]],
                                        colors: [Color]) {
        let seriesCount = values.count
        guard seriesCount > 0 else { return }
        let groupWidth = geom.bandWidth * groupFillRatio
        let gapTotal = groupGap * CGFloat(seriesCount - 1)
        let barWidth = max(1, (groupWidth - gapTotal) / CGFloat(seriesCount))
        let baseline = geom.y(0)
        for categoryIndex in geom.categories.indices {
            let startX = geom.xCenter(categoryIndex) - groupWidth / 2
            for seriesIndex in 0..<seriesCount {
                guard let value = values[seriesIndex][categoryIndex], value > 0 else { continue }
                let topY = geom.y(value)
                let rect = CGRect(x: startX + CGFloat(seriesIndex) * (barWidth + groupGap),
                                  y: topY,
                                  width: barWidth,
                                  height: max(0, baseline - topY))
                context.fill(cappedBar(rect), with: .color(colors[seriesIndex]))
            }
        }
    }

    private static func drawStackedBars(_ context: GraphicsContext,
                                        geom: ChartPlotGeometry,
                                        bands: [[(bottom: Double, top: Double)]],
                                        colors: [Color]) {
        guard !bands.isEmpty else { return }
        let barWidth = max(1, geom.bandWidth * groupFillRatio)
        for categoryIndex in geom.categories.indices {
            let x = geom.xCenter(categoryIndex) - barWidth / 2
            // The topmost non-empty segment carries the rounded cap.
            let capIndex = bands.lastIndex { $0[categoryIndex].top > $0[categoryIndex].bottom }
            for seriesIndex in bands.indices {
                let band = bands[seriesIndex][categoryIndex]
                guard band.top > band.bottom else { continue }
                let rect = CGRect(x: x,
                                  y: geom.y(band.top),
                                  width: barWidth,
                                  height: max(0, geom.y(band.bottom) - geom.y(band.top)))
                let path = seriesIndex == capIndex ? cappedBar(rect) : Path(rect)
                context.fill(path, with: .color(colors[seriesIndex]))
            }
        }
    }

    /// A bar with rounded top caps (the family's signature bar shape).
    private static func cappedBar(_ rect: CGRect) -> Path {
        let radius = min(capRadius, rect.width / 2, rect.height)
        return ThemeUnevenRoundedRect(topLeadingRadius: radius,
                                      topTrailingRadius: radius,
                                      style: .continuous)
            .path(in: rect)
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
