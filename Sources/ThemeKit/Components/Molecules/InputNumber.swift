//
//  InputNumber.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A labelled numeric field with filled − / + steppers, hint / error
//  text and default / disabled / error states. (Form-field counterpart of the
//  pill-shaped QuantityStepper.)
//

import SwiftUI

public struct InputNumber: View {
    private let label: String?
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let hint: String?
    private let errorText: String?
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let height: CGFloat

    public init(
        label: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99,
        hint: String? = nil,
        errorText: String? = nil,
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        large: Bool = false
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.hint = hint
        self.errorText = errorText
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.height = large ? 48 : 40
    }

    private var hasError: Bool { errorText != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                HStack(spacing: 4) {
                    Text(label).textStyle(.labelSm600).foregroundStyle(labelColor)
                    Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(Theme.shared.text(.textTertiary))
                }
            }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                stepper("minus", enabled: value > range.lowerBound) { value = max(range.lowerBound, value - 1) }
                Spacer(minLength: 0)
                Text("\(value)")
                    .textStyle(.labelMd600)
                    .monospacedDigit()
                    .foregroundStyle(isEnabled ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textDisabled))
                Spacer(minLength: 0)
                stepper("plus", enabled: value < range.upperBound) { value = min(range.upperBound, value + 1) }
            }
            .padding(.horizontal, Theme.SpacingKey.xs.value)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: hasError ? 1.5 : 1)
            )
            .a11y(A11yElement.Control.stepper, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue("\(value)")

            if let message = errorText ?? hint {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(hasError ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textTertiary))
            }
        }
    }

    private func stepper(_ systemName: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        let active = enabled && isEnabled
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? Theme.shared.foreground(.fgSecondary) : Theme.shared.text(.textDisabled))
                .frame(width: height - 12, height: height - 12)
                .background(active ? Theme.shared.background(.bgHero) : Theme.shared.background(.bgSecondaryLight),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!active)
    }

    private var labelColor: Color {
        hasError ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary)
    }
    private var borderColor: Color {
        hasError ? Theme.shared.border(.systemcolorsBorderError) : Theme.shared.border(.borderPrimary)
    }
}

#Preview {
    struct Demo: View {
        @State var a = 1
        @State var b = 1
        var body: some View {
            VStack(spacing: 16) {
                InputNumber(label: "Adults", value: $a, range: 1...9, hint: "This is a hint text.", large: true)
                InputNumber(label: "Children", value: $b, errorText: "Too many")
            }
            .padding()
        }
    }
    return Demo()
}
