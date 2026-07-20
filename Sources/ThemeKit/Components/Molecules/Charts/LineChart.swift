//
//  LineChart.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Generic multi-series line chart, Canvas-drawn and token-styled (iOS
//  15.6-floor reimplementation of the former Swift Charts body — ADR-0007;
//  shared chrome in ChartSupport.swift). Categorical color law from
//  `ChartPalette`; hairline grid/axes; a built-in scrub readout (the "chart
//  tooltip") with a token card; controlled or uncontrolled selection via
//  `ControllableState`.
//

import SwiftUI

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

    // Fixed mark geometry (chart-internal, not exposed knobs).
    private static let lineWidth: CGFloat = 2
    private static let pointDiameter: CGFloat = 8

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
    private var showsLegend: Bool { legendVisible ?? (series.count >= 2) }
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        let scale = ChartColorScale(series: series, theme: theme)
        let resolved = Array(zip(series, scale.range))
        let curvedFlag = curved
        let pointsFlag = showsPoints
        ChartXYChrome(
            theme: theme,
            categories: chartCategories(series),
            yDataMax: series.flatMap(\.points).map(\.y).max() ?? 0,
            showsGrid: showsGrid,
            legend: showsLegend ? scale.legendEntries : nil,
            locale: locale,
            selection: $selectedX,
            scrubRows: Self.scrubRowsBuilder(resolved: resolved, locale: locale),
            drawMarks: { context, geom in
                for (s, color) in resolved {
                    let points: [CGPoint] = s.points.compactMap { point in
                        guard let index = geom.index(of: point.x) else { return nil }
                        return CGPoint(x: geom.xCenter(index), y: geom.y(point.y))
                    }
                    if points.count > 1 {
                        let path = curvedFlag ? ChartLinePath.monotone(points) : ChartLinePath.linear(points)
                        context.stroke(path, with: .color(color),
                                       style: StrokeStyle(lineWidth: Self.lineWidth, lineCap: .round, lineJoin: .round))
                    }
                    if pointsFlag {
                        let d = Self.pointDiameter
                        for point in points {
                            let dot = CGRect(x: point.x - d / 2, y: point.y - d / 2, width: d, height: d)
                            context.fill(Path(ellipseIn: dot), with: .color(color))
                        }
                    }
                }
            }
        )
        .frame(height: height.value)
        .animation(motion, value: selectedX)
        .accessibilityLabel(Text(a11ySummary))
    }

    /// The scrub readout rows: every series' value at the selected category,
    /// each dotted in its own palette color.
    static func scrubRowsBuilder(resolved: [(ChartSeries, Color)], locale: Locale) -> (String) -> [ChartScrubRow] {
        { x in
            resolved.compactMap { s, color in
                guard let point = s.points.first(where: { $0.x == x }) else { return nil }
                return ChartScrubRow(label: s.label,
                                     value: chartValueFormatted(point.y, locale: locale),
                                     color: color)
            }
        }
    }

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
        var body: some View {
            let series = [
                ChartSeries("2025", [ChartPoint("Jan", 12), ChartPoint("Feb", 18), ChartPoint("Mar", 15), ChartPoint("Apr", 22), ChartPoint("May", 19)]),
                ChartSeries("2026", [ChartPoint("Jan", 20), ChartPoint("Feb", 16), ChartPoint("Mar", 24), ChartPoint("Apr", 21), ChartPoint("May", 28)]),
            ]
            PreviewMatrix("LineChart") {
                PreviewCase("Two series, curved + points") { LineChart(series, selection: $selected).curved().showsPoints() }
                PreviewCase("Single, compact, no grid") { LineChart([series[0]]).height(.compact).showsGrid(false) }
            }
        }
    }
    return Demo()
}
