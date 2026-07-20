//
//  ChartSupport.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Chrome shared by the generic chart family: the Canvas-drawn plot frame
//  (hairline axes, tick labels, legend, scrub selection), the scrub-readout
//  card, and value formatting — one source of truth so Line/Area/Bar stay
//  visually identical.
//
//  iOS 15.6-floor compat (ADR-0007 §D2 — reimplement): the family renders via
//  `Canvas`/`Path` on every OS instead of the iOS 16-only Swift Charts DSL
//  (in-repo precedent: `PriceTrendChart` / `PriceHistogram`). Only the features
//  the family actually used are reproduced — categorical x axis, zero-based
//  "nice" y ticks, hairline grid, trailing y labels, dot legend, the dashed
//  scrub rule + token card, and the `ChartColorScale` theme threading
//  (ADR-0006). This is deliberately not a Swift Charts clone.
//  When the deployment floor rises past 16 this layer is a deletion-checklist
//  candidate (ADR-0007 §D6): the four charts can return to `import Charts`.
//

import SwiftUI

/// The scrub-readout card: a category title plus one color-dotted row per
/// series, on the standard elevated token card. (This is the "chart tooltip"
/// answer — SwiftUI has no standalone tooltip component.)
struct ChartScrubCard: View {
    let theme: Theme
    let title: String
    let rows: [ChartScrubRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            ForEach(rows) { row in
                HStack(spacing: 5) {
                    Circle().fill(row.color).frame(width: 6, height: 6)
                    Text(row.label).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    Spacer(minLength: 10)
                    Text(row.value).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                }
            }
        }
        .padding(Theme.SpacingKey.sm.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.elevated)
    }
}

struct ChartScrubRow: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let color: Color
}

/// Standard chart value formatting: up to one fraction digit, localized.
func chartValueFormatted(_ value: Double, locale: Locale) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
}

// MARK: - Data plumbing (pure, unit-tested by ChartCanvasTests)

/// The ordered categorical x domain: every series' categories, first-appearance
/// order, deduplicated — the same merge Swift Charts applied to a `String` x.
func chartCategories(_ series: [ChartSeries]) -> [String] {
    var seen = Set<String>()
    var categories: [String] = []
    for s in series {
        for point in s.points where seen.insert(point.x).inserted {
            categories.append(point.x)
        }
    }
    return categories
}

/// Swift-Charts-like automatic y scale: zero-based, "nice" step (1/2/5 × 10ⁿ),
/// about four intervals, top tick ≥ the data max.
enum ChartTicks {
    static func values(dataMax: Double, intervals: Int = 4) -> [Double] {
        guard dataMax > 0, dataMax.isFinite else { return [0, 1] }
        let rawStep = dataMax / Double(max(1, intervals))
        let magnitude = pow(10.0, floor(log10(rawStep)))
        let normalized = rawStep / magnitude
        let nice: Double = normalized <= 1 ? 1 : normalized <= 2 ? 2 : normalized <= 5 ? 5 : 10
        let step = nice * magnitude
        let count = max(1, Int((dataMax / step).rounded(.up)))
        return (0...count).map { Double($0) * step }
    }
}

/// Cumulative stacking for `.stacked` area bands and bar segments. Missing
/// points count as zero (an absent mark has no height); negative values are
/// clamped — the family's y scale is zero-based by design.
enum ChartStacking {
    /// Per-series `(bottom, top)` cumulative values over the full category list.
    static func bands(series: [ChartSeries], categories: [String]) -> [[(bottom: Double, top: Double)]] {
        var totals = [Double](repeating: 0, count: categories.count)
        return series.map { s in
            categories.indices.map { index in
                let value = s.points.first(where: { $0.x == categories[index] })?.y ?? 0
                let bottom = totals[index]
                totals[index] = bottom + max(0, value)
                return (bottom, totals[index])
            }
        }
    }

    /// The tallest stacked total — the stacked charts' y-domain max.
    static func maxTotal(series: [ChartSeries], categories: [String]) -> Double {
        bands(series: series, categories: categories).last?.map(\.top).max() ?? 0
    }
}

// MARK: - Path building

/// Line/area path construction. Points are always in LTR plot coordinates —
/// `ChartXYChrome` mirrors the whole marks layer under RTL.
enum ChartLinePath {
    /// Straight polyline through `points`.
    static func linear(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for point in points.dropFirst() { path.addLine(to: point) }
        return path
    }

    /// Monotone cubic interpolation (Fritsch–Carlson) — the family's `.curved()`
    /// look: smooth, and never overshooting past a data point.
    static func monotone(_ points: [CGPoint]) -> Path {
        var path = Path()
        guard let first = points.first else { return path }
        path.move(to: first)
        for segment in monotoneSegments(points) {
            path.addCurve(to: segment.to, control1: segment.c1, control2: segment.c2)
        }
        return path
    }

    /// The region under a series, closed down to `baseline` (overlaid washes).
    static func area(_ points: [CGPoint], baseline: CGFloat, curved: Bool) -> Path {
        guard points.count > 1, let first = points.first, let last = points.last else { return Path() }
        var path = curved ? monotone(points) : linear(points)
        path.addLine(to: CGPoint(x: last.x, y: baseline))
        path.addLine(to: CGPoint(x: first.x, y: baseline))
        path.closeSubpath()
        return path
    }

    /// A stacked band between a `top` and `bottom` edge (same category count).
    static func band(top: [CGPoint], bottom: [CGPoint], curved: Bool) -> Path {
        guard top.count > 1, bottom.count > 1,
              let firstTop = top.first, let lastBottom = bottom.last else { return Path() }
        var path = Path()
        path.move(to: firstTop)
        if curved {
            for segment in monotoneSegments(top) {
                path.addCurve(to: segment.to, control1: segment.c1, control2: segment.c2)
            }
            path.addLine(to: lastBottom)
            // The bottom edge, traversed right-to-left: reverse each cubic
            // segment (swap endpoints and control points).
            for segment in monotoneSegments(bottom).reversed() {
                path.addCurve(to: segment.from, control1: segment.c2, control2: segment.c1)
            }
        } else {
            for point in top.dropFirst() { path.addLine(to: point) }
            for point in bottom.reversed() { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    struct CurveSegment {
        let from: CGPoint
        let to: CGPoint
        let c1: CGPoint
        let c2: CGPoint
    }

    /// Fritsch–Carlson monotone tangents → cubic Bézier segments, exposed for
    /// the reversed traversal `band(top:bottom:curved:)` needs.
    static func monotoneSegments(_ points: [CGPoint]) -> [CurveSegment] {
        let n = points.count
        guard n > 1 else { return [] }
        var slopes = [CGFloat]()
        var widths = [CGFloat]()
        for i in 0..<(n - 1) {
            let h = points[i + 1].x - points[i].x
            widths.append(h)
            slopes.append(h == 0 ? 0 : (points[i + 1].y - points[i].y) / h)
        }
        var tangents = [CGFloat](repeating: 0, count: n)
        tangents[0] = slopes[0]
        tangents[n - 1] = slopes[n - 2]
        for i in 1..<(n - 1) {
            if slopes[i - 1] * slopes[i] <= 0 {
                tangents[i] = 0   // local extremum — flat tangent keeps monotonicity
            } else {
                let w1 = 2 * widths[i] + widths[i - 1]
                let w2 = widths[i] + 2 * widths[i - 1]
                tangents[i] = (w1 + w2) / (w1 / slopes[i - 1] + w2 / slopes[i])
            }
        }
        return (0..<(n - 1)).map { i in
            let h = widths[i]
            return CurveSegment(
                from: points[i],
                to: points[i + 1],
                c1: CGPoint(x: points[i].x + h / 3, y: points[i].y + tangents[i] * h / 3),
                c2: CGPoint(x: points[i + 1].x - h / 3, y: points[i + 1].y - tangents[i + 1] * h / 3)
            )
        }
    }
}

// MARK: - Plot geometry

/// Resolved plot-area geometry handed to a chart's mark renderer. Coordinates
/// are LTR — `ChartXYChrome` mirrors the finished marks layer under RTL so
/// renderers never branch on direction.
struct ChartPlotGeometry {
    let rect: CGRect
    let categories: [String]
    /// The top y tick (≥ data max); the y scale is `0...yTop`.
    let yTop: Double
    private let indexByCategory: [String: Int]

    init(rect: CGRect, categories: [String], yTop: Double) {
        self.rect = rect
        self.categories = categories
        self.yTop = yTop > 0 ? yTop : 1
        var map: [String: Int] = [:]
        for (index, category) in categories.enumerated() where map[category] == nil {
            map[category] = index
        }
        indexByCategory = map
    }

    var bandWidth: CGFloat { rect.width / CGFloat(max(1, categories.count)) }

    func index(of category: String) -> Int? { indexByCategory[category] }

    /// The category band center for `index`.
    func xCenter(_ index: Int) -> CGFloat { rect.minX + bandWidth * (CGFloat(index) + 0.5) }

    /// The vertical position of `value` on the zero-based y scale.
    func y(_ value: Double) -> CGFloat { rect.maxY - CGFloat(value / yTop) * rect.height }
}

// MARK: - Legend

struct ChartLegendEntry: Identifiable, Equatable {
    var id: String { label }
    let label: String
    let color: Color
}

extension ChartColorScale {
    /// Legend entries in domain order — colors stay in lockstep with the marks.
    var legendEntries: [ChartLegendEntry] {
        zip(domain, range).map { ChartLegendEntry(label: $0, color: $1) }
    }
}

/// The dot legend under a chart. Decorative for VoiceOver — every chart's
/// summary label already names its series/slices.
struct ChartLegendRow: View {
    let theme: Theme
    let entries: [ChartLegendEntry]

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(entries) { entry in
                HStack(spacing: 4) {
                    Circle().fill(entry.color).frame(width: 8, height: 8)
                    Text(entry.label).font(.caption2).foregroundStyle(theme.text(.textSecondary))
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityHidden(true)
    }
}

// MARK: - The shared XY chrome

/// The Canvas-drawn frame every XY chart (Line/Area/Bar) shares: hairline
/// grid + tick labels on both axes (`borderPrimary` / `textTertiary`, matching
/// the family's former Swift Charts styling), the optional dot legend, the
/// scrub interaction (drag to select an x category; tap the selected category
/// again to dismiss) with the dashed rule + token readout card, and one
/// VoiceOver element per category (label = category, value = every series'
/// reading). Mark drawing is delegated to `drawMarks` in LTR coordinates; the
/// chrome mirrors the marks layer wholesale under RTL.
struct ChartXYChrome: View {
    let theme: Theme
    let categories: [String]
    let yDataMax: Double
    let showsGrid: Bool
    let legend: [ChartLegendEntry]?
    let locale: Locale
    let selection: Binding<String?>
    let scrubRows: (String) -> [ChartScrubRow]
    let drawMarks: (GraphicsContext, ChartPlotGeometry) -> Void

    @Environment(\.layoutDirection) private var layoutDirection

    @State private var yLabelSize: CGSize = .zero
    @State private var cardSize: CGSize = .zero
    /// The selection at gesture start (`.some(nil)` = "began with none") —
    /// distinguishes a scrub from the tap-again-to-dismiss toggle.
    @State private var scrubBase: String??

    // Fixed internal geometry (not exposed knobs).
    private static let axisSpacing: CGFloat = 6      // plot ↔ y-label gutter
    private static let xLabelSpacing: CGFloat = 4    // plot ↔ x-label row
    private static let cardSpacing: CGFloat = 6      // rule top ↔ readout card
    private static let hairline: CGFloat = 0.5
    /// Pre-measurement estimate for the first frame; the hidden probe settles
    /// it within the initial layout pass (same idiom as `AdaptiveFit`).
    private static let labelEstimate = CGSize(width: 24, height: 13)

    private var isRTL: Bool { layoutDirection == .rightToLeft }
    private var ticks: [Double] { ChartTicks.values(dataMax: yDataMax) }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            GeometryReader { proxy in
                let geom = plotGeometry(size: proxy.size)
                ZStack(alignment: .topLeading) {
                    plotCanvas(geom)
                    accessibilityBands(geom)
                    selectionOverlay(geom)
                }
                .contentShape(Rectangle())
                .gesture(scrubGesture(geom))
            }
            if let legend, !legend.isEmpty {
                ChartLegendRow(theme: theme, entries: legend)
            }
        }
        .background(labelProbe)
        .onPreferenceChange(ChartLabelSizeKey.self) { yLabelSize = $0 }
    }

    // MARK: Geometry

    private func plotGeometry(size: CGSize) -> ChartPlotGeometry {
        let label = yLabelSize == .zero ? Self.labelEstimate : yLabelSize
        let gutter = label.width + Self.axisSpacing
        let topInset = label.height / 2   // headroom so the top tick label centers on its gridline
        let width = max(0, size.width - gutter)
        let height = max(0, size.height - topInset - label.height - Self.xLabelSpacing)
        let rect = CGRect(x: isRTL ? gutter : 0, y: topInset, width: width, height: height)
        return ChartPlotGeometry(rect: rect, categories: categories, yTop: ticks.last ?? 1)
    }

    /// The mirrored (display) band center — where labels, gridlines, the rule
    /// and the gesture agree a category sits on screen.
    private func displayX(_ index: Int, _ geom: ChartPlotGeometry) -> CGFloat {
        let ltr = geom.xCenter(index)
        return isRTL ? geom.rect.minX + geom.rect.maxX - ltr : ltr
    }

    private func yLabel(for value: Double) -> String { chartValueFormatted(value, locale: locale) }

    /// Hidden probe measuring one y tick label (the widest — the top value) so
    /// the gutter and label row heights are real text metrics.
    private var labelProbe: some View {
        Text(yLabel(for: ticks.last ?? 0))
            .font(.caption2)
            .fixedSize()
            .background(GeometryReader { proxy in
                Color.clear.preference(key: ChartLabelSizeKey.self, value: proxy.size)
            })
            .hidden()
            .accessibilityHidden(true)
    }

    // MARK: Canvas

    private func plotCanvas(_ geom: ChartPlotGeometry) -> some View {
        let gridColor = theme.border(.borderPrimary)
        let labelColor = theme.text(.textTertiary)
        return Canvas { context, size in
            // y axis: horizontal gridlines + trailing tick labels.
            for tick in ticks {
                let tickY = geom.y(tick)
                if showsGrid {
                    var line = Path()
                    line.move(to: CGPoint(x: geom.rect.minX, y: tickY))
                    line.addLine(to: CGPoint(x: geom.rect.maxX, y: tickY))
                    context.stroke(line, with: .color(gridColor), lineWidth: Self.hairline)
                }
                var label = context.resolve(Text(yLabel(for: tick)).font(.caption2))
                label.shading = .color(labelColor)
                if isRTL {
                    context.draw(label, at: CGPoint(x: 0, y: tickY), anchor: .leading)
                } else {
                    context.draw(label, at: CGPoint(x: size.width, y: tickY), anchor: .trailing)
                }
            }
            // x axis: vertical gridlines + category labels at band centers.
            for (index, category) in categories.enumerated() {
                let centerX = displayX(index, geom)
                if showsGrid {
                    var line = Path()
                    line.move(to: CGPoint(x: centerX, y: geom.rect.minY))
                    line.addLine(to: CGPoint(x: centerX, y: geom.rect.maxY))
                    context.stroke(line, with: .color(gridColor), lineWidth: Self.hairline)
                }
                var label = context.resolve(Text(category).font(.caption2))
                label.shading = .color(labelColor)
                context.draw(label, at: CGPoint(x: centerX, y: geom.rect.maxY + Self.xLabelSpacing), anchor: .top)
            }
            // Marks — mirrored wholesale under RTL so renderers stay LTR-pure.
            var marks = context
            if isRTL {
                marks.translateBy(x: geom.rect.minX + geom.rect.maxX, y: 0)
                marks.scaleBy(x: -1, y: 1)
            }
            drawMarks(marks, geom)
        }
    }

    // MARK: Accessibility

    /// One VoiceOver element per category so the readings stay navigable now
    /// that the marks are canvas pixels (the former per-mark labels).
    private func accessibilityBands(_ geom: ChartPlotGeometry) -> some View {
        ForEach(Array(categories.enumerated()), id: \.element) { index, category in
            Color.clear
                .frame(width: max(1, geom.bandWidth), height: max(1, geom.rect.height))
                .offset(x: displayX(index, geom) - geom.bandWidth / 2, y: geom.rect.minY)
                .allowsHitTesting(false)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(category)
                .accessibilityValue(scrubRows(category).map { "\($0.label) \($0.value)" }.joined(separator: ", "))
        }
    }

    // MARK: Selection

    @ViewBuilder private func selectionOverlay(_ geom: ChartPlotGeometry) -> some View {
        if let selected = selection.wrappedValue, let index = geom.index(of: selected) {
            let centerX = displayX(index, geom)
            ChartRuleShape()
                .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                .frame(width: 1, height: max(1, geom.rect.height))
                .offset(x: centerX - 0.5, y: geom.rect.minY)
                .allowsHitTesting(false)
            let rows = scrubRows(selected)
            if !rows.isEmpty {
                ChartScrubCard(theme: theme, title: selected, rows: rows)
                    .fixedSize()
                    .background(GeometryReader { proxy in
                        Color.clear.preference(key: ChartCardSizeKey.self, value: proxy.size)
                    })
                    .onPreferenceChange(ChartCardSizeKey.self) { cardSize = $0 }
                    // Above the plot, centered on the rule, clamped to the
                    // plot's bounds (the former `.top` + fit-to-chart overflow).
                    .offset(x: cardX(center: centerX, geom: geom),
                            y: geom.rect.minY - cardSize.height - Self.cardSpacing)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
    }

    private func cardX(center: CGFloat, geom: ChartPlotGeometry) -> CGFloat {
        let unclamped = center - cardSize.width / 2
        return max(geom.rect.minX, min(unclamped, geom.rect.maxX - cardSize.width))
    }

    private func scrubGesture(_ geom: ChartPlotGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                guard let category = category(at: value.location.x, geom) else { return }
                if scrubBase == nil { scrubBase = .some(selection.wrappedValue) }
                if selection.wrappedValue != category { selection.wrappedValue = category }
            }
            .onEnded { value in
                defer { scrubBase = nil }
                let isTap = hypot(value.translation.width, value.translation.height) < 4
                guard isTap,
                      case .some(let previous) = scrubBase,
                      let category = category(at: value.location.x, geom),
                      previous == category
                else { return }
                selection.wrappedValue = nil   // tap the selected category again to dismiss
            }
    }

    private func category(at x: CGFloat, _ geom: ChartPlotGeometry) -> String? {
        guard !categories.isEmpty, geom.rect.width > 0 else { return nil }
        let fraction = (x - geom.rect.minX) / geom.rect.width
        var index = Int((fraction * CGFloat(categories.count)).rounded(.down))
        index = min(max(index, 0), categories.count - 1)
        if isRTL { index = categories.count - 1 - index }
        return categories[index]
    }
}

/// The dashed selection rule (a 1pt-wide vertical line, stroked dashed).
private struct ChartRuleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.midX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        return path
    }
}

private struct ChartLabelSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

private struct ChartCardSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}
