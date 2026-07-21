//
//  GaugeView.swift
//  ThemeKit
//
//  iOS 15.6-floor migration (ADR-0007 §D2 rule 1, plan §3e): the native
//  SwiftUI `Gauge` + `.gaugeStyle(.accessoryCircular/.accessoryLinear)` are
//  iOS 16-only, so the atom draws its own token-fed ring / bar — single-path,
//  identical on every supported OS (precedent: the Canvas-drawn charts).
//
//  MeterStyle exception: the ring/bar geometry here mirrors the native
//  accessory gauges (270° dial with the label in the bottom opening), which
//  has no `MeterStyle` track/fill decomposition — so, as before the rewrite,
//  it intentionally does not adopt it.
//

import SwiftUI

/// Atom. A token-tinted gauge — circular or linear, brand-tinted, with an
/// optional label + value readout. (daisyUI "Radial progress" / a metered
/// display.)
public struct GaugeView: View {
    public enum Style: Sendable { case circular, linear }

    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: Style = .circular
    private var showsValue: Bool = true

    private let value: Double
    private let range: ClosedRange<Double>
    private let label: String?

    // Fixed drawing constants — genuine dimensions with no semantic token,
    // sized to the native accessory-gauge footprint the atom replaces.
    private static let ringDiameter: CGFloat = 56
    private static let ringLineWidth: CGFloat = 6
    private static let barHeight: CGFloat = 6

    public init(value: Double, in range: ClosedRange<Double> = 0...1, label: String? = nil) {   // R1
        self.value = value
        self.range = range
        self.label = label
    }

    /// `value` clamped into `range` — an out-of-range value must not overshoot
    /// the dial or the readout.
    private var clampedValue: Double { min(max(value, range.lowerBound), range.upperBound) }

    /// Position of the clamped value inside `range`, 0…1 — the readout is a
    /// percentage of the range, not of the raw value.
    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (clampedValue - range.lowerBound) / span
    }

    private var percentText: String {
        fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale))
    }

    public var body: some View {
        gauge
            // The dial/bar fill is purely visual — speak the label + percentage.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(label ?? String(themeKit: "Progress")))
            .accessibilityValue(Text(percentText))
    }

    @ViewBuilder
    private var gauge: some View {
        switch style {
        case .circular: circularGauge
        case .linear: linearGauge
        }
    }

    // MARK: Circular — 270° dial, value centered, label in the bottom opening

    private var circularGauge: some View {
        ZStack {
            GaugeArcShape(fraction: 1, lineWidth: Self.ringLineWidth)
                .stroke(theme.border(.borderPrimary),
                        style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round))
            GaugeArcShape(fraction: fraction, lineWidth: Self.ringLineWidth)
                .stroke(theme.foreground(.fgHero),
                        style: StrokeStyle(lineWidth: Self.ringLineWidth, lineCap: .round))
            if showsValue {
                Text(percentText)
                    .textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .padding(.horizontal, Self.ringLineWidth * 2)
            }
        }
        .frame(width: Self.ringDiameter, height: Self.ringDiameter)
        // The dial fills clockwise from the bottom-left shoulder — mirror it
        // for RTL like every other ThemeKit-drawn `Path`.
        .flipsForRightToLeftLayoutDirection(true)
        .overlay(alignment: .bottom) {
            if let label {
                Text(label)
                    .textStyle(.overline400)
                    .foregroundStyle(theme.text(.textSecondary))
                    .lineLimit(1)
            }
        }
    }

    // MARK: Linear — ProgressBar-derived capsule track + fill

    private var linearGauge: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if label != nil || showsValue {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let label {
                        Text(label).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    }
                    Spacer(minLength: 0)
                    if showsValue {
                        Text(percentText).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                    }
                }
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(theme.border(.borderPrimary))
                    Capsule().fill(theme.foreground(.fgHero))
                        .frame(width: max(Self.barHeight, proxy.size.width * fraction))
                }
            }
            .frame(height: Self.barHeight)
        }
    }
}

/// The gauge dial arc: a 270° sweep opening at the bottom (native
/// accessory-circular geometry), `fraction` of which is drawn — `1` is the
/// full track. Stroke-inset by `lineWidth` so the rounded caps stay inside
/// the frame. Animatable, so value changes tween.
struct GaugeArcShape: Shape {
    var fraction: Double
    let lineWidth: CGFloat

    var animatableData: Double {
        get { fraction }
        set { fraction = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = min(max(fraction, 0), 1)
        guard clamped > 0 else { return Path() }
        let radius = min(rect.width, rect.height) / 2 - lineWidth / 2
        guard radius > 0 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        // Screen coords (y down): 135° = bottom-left shoulder; sweeping
        // +270° · fraction runs clockwise up over the top to the
        // bottom-right shoulder (`clockwise: false` = increasing angle —
        // same convention as `DonutWedgeShape`).
        path.addArc(center: center, radius: radius,
                    startAngle: .degrees(135),
                    endAngle: .degrees(135 + 270 * clamped),
                    clockwise: false)
        return path
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension GaugeView {
    /// Gauge rendering: circular (default) or linear.
    func gaugeStyle(_ s: Style) -> Self { copy { $0.style = s } }

    /// Toggle the inline percentage value readout.
    func showsValue(_ on: Bool = true) -> Self { copy { $0.showsValue = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("GaugeView") {
        PreviewCase("Circular") {
            GaugeView(value: 0.72, label: "CPU")
        }
        PreviewCase("Linear") {
            GaugeView(value: 0.4, label: "Storage").gaugeStyle(.linear).frame(width: 160)
        }
        PreviewCase("No value readout") {
            GaugeView(value: 0.55, label: "Signal").showsValue(false)
        }
        PreviewCase("Custom range, clamped") {
            GaugeView(value: 180, in: 0...120, label: "Speed")
        }
    }
}
