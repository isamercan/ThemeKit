//
//  AreaChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic area chart — LineChart's sibling, Canvas-drawn (iOS 15.6-floor
//  reimplementation — ADR-0007; shared chrome in ChartSupport.swift). Overlaid
//  translucent washes under 2pt outlines by default; `.stacked()` sums the
//  series into bands.
//

import SwiftUI

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

    // Fixed mark geometry/opacity (chart-internal, not exposed knobs).
    private static let lineWidth: CGFloat = 2
    private static let overlaidOpacity = 0.18
    private static let stackedOpacity = 0.85

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
        let curvedFlag = curved
        // Stacked bands are cumulative sums over the full category domain.
        let bands = stacked ? ChartStacking.bands(series: series, categories: categories) : []
        let dataMax = stacked
            ? ChartStacking.maxTotal(series: series, categories: categories)
            : series.flatMap(\.points).map(\.y).max() ?? 0
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
                if bands.isEmpty {
                    // Overlaid washes need a crisp edge to stay legible;
                    // stacked bands read fine on their own.
                    for (s, color) in resolved {
                        let points: [CGPoint] = s.points.compactMap { point in
                            guard let index = geom.index(of: point.x) else { return nil }
                            return CGPoint(x: geom.xCenter(index), y: geom.y(point.y))
                        }
                        guard points.count > 1 else { continue }
                        let wash = ChartLinePath.area(points, baseline: geom.y(0), curved: curvedFlag)
                        context.fill(wash, with: .color(color.opacity(Self.overlaidOpacity)))
                        let edge = curvedFlag ? ChartLinePath.monotone(points) : ChartLinePath.linear(points)
                        context.stroke(edge, with: .color(color),
                                       style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round))
                    }
                } else {
                    for (index, (_, color)) in resolved.enumerated() {
                        let top = geom.categories.indices.map {
                            CGPoint(x: geom.xCenter($0), y: geom.y(bands[index][$0].top))
                        }
                        let bottom = geom.categories.indices.map {
                            CGPoint(x: geom.xCenter($0), y: geom.y(bands[index][$0].bottom))
                        }
                        let band = ChartLinePath.band(top: top, bottom: bottom, curved: curvedFlag)
                        context.fill(band, with: .color(color.opacity(Self.stackedOpacity)))
                    }
                }
            }
        )
        .frame(height: height.value)
        .animation(motion, value: selectedX)
        .accessibilityLabel(Text(String(themeKit: "Area chart with series \(series.map(\.label).joined(separator: ", ")).")))
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
