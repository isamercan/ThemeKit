//
//  QuantityStepper.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  A token-bound quantity stepper (− value +), bounded by a range.
//

import SwiftUI

public struct QuantityStepper: View {
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let accessibilityID: String?
    private let isEnabled: Bool

    public init(value: Binding<Int>, range: ClosedRange<Int> = 0...99, accessibilityID: String? = nil, isEnabled: Bool = true) {
        self._value = value
        self.range = range
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            stepButton(systemName: "minus", enabled: value > range.lowerBound) {
                value = max(range.lowerBound, value - 1)
            }

            Text("\(value)")
                .textStyle(.labelMd600)
                .foregroundStyle(Theme.shared.text(.textPrimary))
                .frame(minWidth: 24)
                .monospacedDigit()

            stepButton(systemName: "plus", enabled: value < range.upperBound) {
                value = min(range.upperBound, value + 1)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .overlay(
            Capsule().strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
        )
        .a11y(A11yElement.Control.stepper, in: accessibilityID)
        .accessibilityValue("\(value)")
    }

    private func stepButton(systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: systemName, size: .sm,
                 color: enabled && isEnabled ? Theme.shared.text(.textHero) : Theme.shared.text(.textDisabled))
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
