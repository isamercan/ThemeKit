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

    private let value: Double
    private let range: ClosedRange<Double>
    private let label: String?
    private let style: Style
    private let showsValue: Bool

    public init(
        value: Double,
        in range: ClosedRange<Double> = 0...1,
        label: String? = nil,
        style: Style = .circular,
        showsValue: Bool = true
    ) {
        self.value = value
        self.range = range
        self.label = label
        self.style = style
        self.showsValue = showsValue
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

#Preview {
    HStack(spacing: 24) {
        GaugeView(value: 0.72, label: "CPU")
        GaugeView(value: 0.4, label: "Storage", style: .linear).frame(width: 160)
    }
    .padding()
}
