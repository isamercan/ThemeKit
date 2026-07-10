//
//  MeterStyle.swift
//  ThemeKit
//
//  The `ButtonStyle`-shaped styling hook for meters (`ProgressBar`,
//  `RadialProgress`).
//  The split is: DATA lives in the component, GEOMETRY lives in the style.
//  `ProgressBar` clamps the fraction, resolves the fill (color override >
//  status gradient > status solid), the track token and the label block, then
//  hands them to a `MeterStyle`, which decides how the meter is drawn — a
//  capsule bar, segments, stripes, thickness. The default style reproduces the
//  original look pixel-for-pixel, so this is additive and non-breaking.
//
//      ProgressBar(value: 0.7)
//          .meterStyle(.striped)        // or a custom MeterStyle
//

import SwiftUI

/// The inputs a `MeterStyle` renders. Everything here is already *resolved*
/// by the component (clamping, color priority, token lookup); the style only
/// decides geometry.
public struct MeterStyleConfiguration {
    /// Progress in 0...1, already clamped by the component.
    public let fraction: Double
    /// The meter's semantic state, if it has one (the component has already
    /// folded it into `fill`; exposed so styles can vary geometry by state).
    public let status: ProgressStatus?
    /// When non-nil, the meter asked to be drawn as this many segments
    /// (`ProgressBar.steps(_:)`). Built-ins honor it; a style may reinterpret.
    public let steps: Int?
    /// Requested bar thickness in points (`ProgressBar.barHeight(_:)`,
    /// default 8). Styles should apply it to the bar geometry.
    public let height: CGFloat
    /// The resolved fill: explicit color override > status gradient > status
    /// solid. The style just paints with it.
    public let fill: AnyShapeStyle
    /// The resolved track (rail) color, from the component's token.
    public let track: Color
    /// A 0...1 portion — already capped at `fraction` — drawn in the success
    /// color over the fill (Ant `success.percent`); nil when unused.
    public let successFraction: Double?
    /// The percentage / checkmark label block, type-erased; nil when the meter
    /// shows no label. Styles decide its placement.
    public let label: AnyView?
}

/// Defines a meter's geometry. Implement `makeBody` to lay out the
/// configuration's track, fill and label. Set one with `.meterStyle(_:)`;
/// the default is ``LinearMeterStyle``.
public protocol MeterStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: MeterStyleConfiguration) -> Body
}

/// The stock meter geometry: a capsule track with a width-proportional capsule
/// fill (or the segmented variant when `steps` is set), the label trailing the
/// bar. Reproduces `ProgressBar`'s original drawing exactly.
public struct LinearMeterStyle: MeterStyle {
    public init() {}
    public func makeBody(configuration: MeterStyleConfiguration) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            LinearMeterBar(configuration: configuration)
            if let label = configuration.label { label }
        }
    }
}

private struct LinearMeterBar: View {
    let configuration: MeterStyleConfiguration

    var body: some View {
        if let steps = configuration.steps {
            HStack(spacing: 4) {
                ForEach(0..<max(steps, 1), id: \.self) { index in
                    Capsule()
                        .fill(Double(index) < configuration.fraction * Double(steps)
                              ? configuration.fill
                              : AnyShapeStyle(configuration.track))
                        .frame(height: configuration.height)
                }
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(configuration.track)
                    Capsule().fill(configuration.fill)
                        .frame(width: geo.size.width * configuration.fraction)
                    if let successFraction = configuration.successFraction {
                        Capsule().fill(SemanticColor.success.solid)
                            .frame(width: geo.size.width * successFraction)
                    }
                }
            }
            .frame(height: configuration.height)
        }
    }
}

/// An alternative meter: the linear geometry with a static 45° hatch over the
/// fill. The pattern never animates on its own (only the width follows the
/// component's value animation), so it is reduce-motion friendly by
/// construction.
public struct StripedMeterStyle: MeterStyle {
    public init() {}
    public func makeBody(configuration: MeterStyleConfiguration) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            StripedMeterBar(configuration: configuration)
            if let label = configuration.label { label }
        }
    }
}

private struct StripedMeterBar: View {
    let configuration: MeterStyleConfiguration

    var body: some View {
        if let steps = configuration.steps {
            HStack(spacing: 4) {
                ForEach(0..<max(steps, 1), id: \.self) { index in
                    let isFilled = Double(index) < configuration.fraction * Double(steps)
                    Capsule()
                        .fill(isFilled ? configuration.fill : AnyShapeStyle(configuration.track))
                        .overlay {
                            if isFilled {
                                DiagonalStripes(lineWidth: 3, gap: 5)
                                    .clipShape(Capsule())
                            }
                        }
                        .frame(height: configuration.height)
                }
            }
        } else {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(configuration.track)
                    Capsule().fill(configuration.fill)
                        .overlay(DiagonalStripes(lineWidth: 3, gap: 5))
                        .clipShape(Capsule())
                        .frame(width: geo.size.width * configuration.fraction)
                    if let successFraction = configuration.successFraction {
                        Capsule().fill(SemanticColor.success.solid)
                            .frame(width: geo.size.width * successFraction)
                    }
                }
            }
            .frame(height: configuration.height)
        }
    }
}

/// A static 45° line pattern (a white highlight, purely decorative — hidden
/// from hit testing and never animated).
private struct DiagonalStripes: View {
    let lineWidth: CGFloat
    let gap: CGFloat

    var body: some View {
        GeometryReader { geo in
            let height = geo.size.height
            let step = max(lineWidth + gap, 1)
            Path { path in
                var x = -height
                while x < geo.size.width + height {
                    path.move(to: CGPoint(x: x, y: height))
                    path.addLine(to: CGPoint(x: x + height, y: 0))
                    x += step
                }
            }
            .stroke(Color.white.opacity(0.35), lineWidth: lineWidth)
            .flipsForRightToLeftLayoutDirection(true)
        }
        .allowsHitTesting(false)
    }
}

public extension MeterStyle where Self == LinearMeterStyle {
    /// The stock capsule bar (segmented when `steps` is set).
    static var linear: LinearMeterStyle { LinearMeterStyle() }
}

public extension MeterStyle where Self == StripedMeterStyle {
    /// The linear geometry with a static 45° hatch over the fill.
    static var striped: StripedMeterStyle { StripedMeterStyle() }
}

/// The ring meter geometry (`RadialProgress`'s stock look): a circular track,
/// a trim-proportional fill ring on top, and the label centered inside.
/// Diameter, stroke width and the dashboard gap are geometry, so they live
/// here as style parameters rather than in `MeterStyleConfiguration` (which
/// stays untouched for source/AB compatibility with the linear styles) —
/// `RadialProgress` forwards its `size(_:)` / `lineWidth(_:)` / `dashboard(_:)`
/// modifiers into this init when it builds its default style.
public struct RadialMeterStyle: MeterStyle {
    /// Diameter of the ring, in points.
    public var size: CGFloat
    /// Stroke width of both rings.
    public var lineWidth: CGFloat
    /// Dashboard (gapped) variant — leaves a quarter of the circle open at the
    /// bottom (Ant Progress type="dashboard").
    public var dashboard: Bool

    public init(size: CGFloat = 64, lineWidth: CGFloat = 6, dashboard: Bool = false) {
        self.size = size
        self.lineWidth = lineWidth
        self.dashboard = dashboard
    }

    public func makeBody(configuration: MeterStyleConfiguration) -> some View {
        RadialMeterRing(configuration: configuration, size: size, lineWidth: lineWidth, dashboard: dashboard)
    }
}

private struct RadialMeterRing: View {
    let configuration: MeterStyleConfiguration
    let size: CGFloat
    let lineWidth: CGFloat
    let dashboard: Bool

    private var gap: CGFloat { dashboard ? 0.25 : 0 }            // fraction left open
    private var rotation: Double { dashboard ? 90 + Double(gap) * 180 : -90 }

    var body: some View {
        ZStack {
            Circle()
                .trim(from: 0, to: 1 - gap)
                .stroke(configuration.track, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            Circle()
                .trim(from: 0, to: configuration.fraction * (1 - gap))
                .stroke(configuration.fill, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(rotation))
            if let label = configuration.label { label }
        }
        .frame(width: size, height: size)
    }
}

public extension MeterStyle where Self == RadialMeterStyle {
    /// The circular ring geometry (`RadialProgress`'s default), at the stock
    /// 64pt / 6pt metrics. Use `RadialMeterStyle(size:lineWidth:dashboard:)`
    /// for other metrics or the dashboard gap.
    static var radial: RadialMeterStyle { RadialMeterStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyMeterStyle: MeterStyle {
    /// True only on the environment key's built-in default — i.e. no
    /// `.meterStyle(_:)` applied anywhere above. Components whose stock
    /// geometry is *not* linear (`RadialProgress`) read this to keep their own
    /// default drawing while still honoring an explicitly set custom style.
    /// `ProgressBar` never reads it: its stock geometry *is* the default
    /// `LinearMeterStyle`, so the flag changes nothing there.
    let isDefault: Bool
    private let _makeBody: @MainActor (MeterStyleConfiguration) -> AnyView
    init<S: MeterStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: MeterStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct MeterStyleKey: EnvironmentKey {
    static let defaultValue = AnyMeterStyle(LinearMeterStyle(), isDefault: true)
}

extension EnvironmentValues {
    var meterStyle: AnyMeterStyle {
        get { self[MeterStyleKey.self] }
        set { self[MeterStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``MeterStyle`` for `ProgressBar`s in this view and its descendants.
    func meterStyle<S: MeterStyle>(_ style: sending S) -> some View {
        environment(\.meterStyle, AnyMeterStyle(style))
    }
}
