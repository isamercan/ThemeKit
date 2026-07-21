//
//  QuantityStepper.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A token-bound quantity stepper (− value +), bounded by a range.
public struct QuantityStepper: View {
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private var accessibilityID: String? = nil
    // Opt-in presentation — set via chainable modifiers.
    private var step: Int = 1
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    public init(   // R1
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99
    ) {
        self._value = value
        self.range = range
    }

    /// The bound value rendered in the captured locale (visible text + a11y values).
    private var formattedValue: String { value.formatted(.number.locale(locale)) }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }
            .accessibilityLabel(String(themeKit: "Decrease"))
            .accessibilityValue(formattedValue)

            Text(formattedValue)
                .textStyle(.labelMd600)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 24)
                .monospacedDigit()

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
            .accessibilityLabel(String(themeKit: "Increase"))
            .accessibilityValue(formattedValue)
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .overlay(
            Capsule().strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
        )
        .a11y(A11yElement.Control.stepper, in: accessibilityID)
        .accessibilityValue(formattedValue)
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName)
                .size(.sm)
                .color(enabled && isEnabled ? theme.text(.textHero) : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
                // Glyph stays 32pt; expand the hit area to the 44pt WCAG 2.5.5 / HIG minimum.
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled || !isEnabled)
    }
}

#Preview {
    struct Demo: View {
        @State var qty = 1
        var body: some View {
            PreviewMatrix("QuantityStepper") {
                PreviewCase("Default") { QuantityStepper(value: $qty, range: 0...10) }
                PreviewCase("At minimum") { QuantityStepper(value: .constant(0), range: 0...10) }
                PreviewCase("At maximum") { QuantityStepper(value: .constant(10), range: 0...10) }
                PreviewCase("Step 5") { QuantityStepper(value: $qty, range: 0...10).step(5) }
                PreviewCase("Disabled") { QuantityStepper(value: .constant(3), range: 0...10).disabled(true) }
            }
        }
    }
    return Demo()
}

public extension QuantityStepper {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Increment applied by the − / + buttons (default 1; clamped to at least 1).
    func step(_ step: Int) -> Self { copy { $0.step = max(1, step) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
