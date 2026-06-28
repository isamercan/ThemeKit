//
//  QuantityStepper.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A token-bound quantity stepper (− value +), bounded by a range.
public struct QuantityStepper: View {
    @Environment(\.theme) private var theme

    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private var accessibilityID: String? = nil
    private let isEnabled: Bool

    public init(
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99,
        step: Int = 1,
        isEnabled: Bool = true
    ) {
        self._value = value
        self.range = range
        self.step = max(1, step)
        self.isEnabled = isEnabled
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - step)
            }

            Text("\(value)")
                .textStyle(.labelMd600)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 24)
                .monospacedDigit()

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + step)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .overlay(
            Capsule().strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
        )
        .a11y(A11yElement.Control.stepper, in: accessibilityID)
        .accessibilityValue("\(value)")
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName, size: .sm,
                 color: enabled && isEnabled ? theme.text(.textHero) : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled || !isEnabled)
    }
}

#Preview {
    struct Demo: View {
        @State var qty = 1
        var body: some View {
            QuantityStepper(value: $qty, range: 0...10).padding()
        }
    }
    return Demo()
}

public extension QuantityStepper {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
