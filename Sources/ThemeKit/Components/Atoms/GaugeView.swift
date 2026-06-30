//
//  GaugeView.swift
//  ThemeKit
//

import SwiftUI

/// Atom. A token-tinted gauge wrapping SwiftUI `Gauge` — circular or linear,
/// brand-tinted, with an optional label + value readout. (daisyUI "Radial progress"
/// / a metered display.)
public struct GaugeView: View {
    public enum Style: Sendable { case circular, linear }

    @Environment(\.theme) private var theme

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

    public var body: some View {
        gauge
            .tint(theme.foreground(.fgHero))
    }

    @ViewBuilder
    private var gauge: some View {
        let base = Gauge(value: value, in: range) {
            if let label { Text(label).textStyle(.labelSm600) }
        } currentValueLabel: {
            if showsValue {
                Text(value.formatted(.percent.precision(.fractionLength(0))))
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
