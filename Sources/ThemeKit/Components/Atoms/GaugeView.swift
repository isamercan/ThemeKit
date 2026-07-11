//
//  GaugeView.swift
//  ThemeKit
//
//  MeterStyle exception: this atom wraps SwiftUI's native `Gauge`, whose
//  geometry is drawn by the system `GaugeStyle` — there is no ThemeKit-drawn
//  track/fill to hand to a `MeterStyle`, so it intentionally does not adopt it.
//

import SwiftUI

/// Atom. A token-tinted gauge wrapping SwiftUI `Gauge` — circular or linear,
/// brand-tinted, with an optional label + value readout. (daisyUI "Radial progress"
/// / a metered display.)
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

    public init(value: Double, in range: ClosedRange<Double> = 0...1, label: String? = nil) {   // R1
        self.value = value
        self.range = range
        self.label = label
    }

    /// `value` clamped into `range` — an out-of-range value must not crash `Gauge`
    /// or overshoot the readout.
    private var clampedValue: Double { min(max(value, range.lowerBound), range.upperBound) }

    /// Position of the clamped value inside `range`, 0…1 — the readout is a
    /// percentage of the range, not of the raw value.
    private var fraction: Double {
        let span = range.upperBound - range.lowerBound
        guard span > 0 else { return 0 }
        return (clampedValue - range.lowerBound) / span
    }

    public var body: some View {
        gauge
            .tint(theme.foreground(.fgHero))
    }

    @ViewBuilder
    private var gauge: some View {
        let base = Gauge(value: clampedValue, in: range) {
            if let label { Text(label).textStyle(.labelSm600) }
        } currentValueLabel: {
            if showsValue {
                Text(fraction.formatted(.percent.precision(.fractionLength(0)).locale(locale)))
                    .foregroundStyle(theme.text(.textPrimary))
            }
        }
        switch style {
        case .circular: base.gaugeStyle(.accessoryCircular)
        case .linear:   base.gaugeStyle(.accessoryLinear)
        }
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
    HStack(spacing: 24) {
        GaugeView(value: 0.72, label: "CPU")
        GaugeView(value: 0.4, label: "Storage").gaugeStyle(.linear).frame(width: 160)
    }
    .padding()
}
