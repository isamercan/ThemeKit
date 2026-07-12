//
//  ChartModels.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Shared value model + the categorical color law for the generic Swift Charts
//  family (LineChart / AreaChart / BarChart / DonutChart). Distinct from the
//  domain-specific PriceTrendChart (hand-drawn fare bars); these are neutral,
//  token-styled wrappers over `import Charts` (iOS 17 / macOS 14 baseline).
//
//  x-axis is categorical `String` by design: dates/numbers are formatted to
//  labels at the call site. This keeps one robust, RTL-safe axis type across
//  the whole family instead of juggling `Plottable` conformances per point.
//

import SwiftUI

/// One (x, y) sample. `x` is the category/tick label; `y` the value.
public struct ChartPoint: Identifiable, Sendable, Equatable {
    public var id: String { x }
    public let x: String
    public let y: Double
    public init(_ x: String, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// A named line/area/bar series. `color` overrides the automatic palette slot;
/// pass a status hue (`.success`/`.warning`/`.error`) explicitly to opt into it.
public struct ChartSeries: Identifiable {
    public var id: String { label }
    public let label: String
    public let points: [ChartPoint]
    public let color: SemanticColor?
    public init(_ label: String, _ points: [ChartPoint], color: SemanticColor? = nil) {
        self.label = label
        self.points = points
        self.color = color
    }
}

/// One wedge of a `DonutChart`.
public struct ChartSlice: Identifiable, Equatable {
    public var id: String { label }
    public let label: String
    public let value: Double
    public let color: SemanticColor?
    public init(_ label: String, _ value: Double, color: SemanticColor? = nil) {
        self.label = label
        self.value = value
        self.color = color
    }
}

/// Semantic chart heights — geometry, not a token, so a plain enum (rule 5b).
public enum ChartHeight: Sendable {
    case compact, regular, tall
    var value: CGFloat { switch self { case .compact: 160; case .regular: 220; case .tall: 300 } }
}

/// The categorical color law (the dataviz method, encoded once). A *fixed,
/// ordered* list of non-status hues assigned to series/slices by position and
/// **never cycled** — color follows the entity. Beyond the six slots, auto
/// colors fold to neutral (put ≤ 6 categories on one chart, or set colors
/// explicitly). `success`/`warning`/`error` are reserved status hues and only
/// appear when a caller sets them explicitly.
enum ChartPalette {
    // Computed (not a stored global) so it needs no Sendable on SemanticColor.
    static var slots: [SemanticColor] { [.primary, .orange, .turquoise, .purple, .pink, .info] }

    /// The hue for the entity at `index`, honoring an explicit override.
    static func hue(explicit: SemanticColor?, at index: Int) -> SemanticColor {
        if let explicit { return explicit }
        return index < slots.count ? slots[index] : .neutral
    }
}

/// The resolved `domain`/`range` pair for `.chartForegroundStyleScale` — maps
/// each series/slice label to its palette color so Swift Charts colors, legend
/// and our annotation dots all stay in lockstep.
///
/// ADR-0006 (Class N — non-View builder): takes the building View's `theme:`
/// explicitly rather than baking `.solid` (which would read `Theme.shared` and
/// ignore a `.theme(_:)` subtree). Every call site is a chart View that already
/// holds `@Environment(\.theme)`, so this converts N → P.
struct ChartColorScale {
    let domain: [String]
    let range: [Color]

    init(series: [ChartSeries], theme: Theme) {
        domain = series.map(\.label)
        range = series.enumerated().map { theme.resolve(ChartPalette.hue(explicit: $1.color, at: $0)).solid }
    }
    init(slices: [ChartSlice], theme: Theme) {
        domain = slices.map(\.label)
        range = slices.enumerated().map { theme.resolve(ChartPalette.hue(explicit: $1.color, at: $0)).solid }
    }
}
