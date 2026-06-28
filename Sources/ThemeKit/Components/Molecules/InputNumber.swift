//
//  InputNumber.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A labelled numeric field with filled − / + steppers, hint / error
/// text and default / disabled / error states. (Form-field counterpart of the
/// pill-shaped QuantityStepper.)
/// Reference: Ant Design `InputNumber` / Chakra `NumberInput` — the value is
/// directly editable (type a number, clamped to `range` on commit), steppers move
/// by `step`, and an optional `unit` suffix labels the value (e.g. "kişi", "₺").
public struct InputNumber: View {
    @Environment(\.theme) private var theme

    private let label: String?
    @Binding private var value: Int
    private let range: ClosedRange<Int>
    private let step: Int
    private let unit: String?
    private let editable: Bool
    private let hint: String?
    private let errorText: String?
    private let hasInfo: Bool
    private let onChange: ((Int) -> Void)?
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let height: CGFloat

    @FocusState private var isFocused: Bool
    @State private var textValue: String

    public init(
        label: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99,
        step: Int = 1,
        unit: String? = nil,
        editable: Bool = true,
        hint: String? = nil,
        errorText: String? = nil,
        hasInfo: Bool = false,
        onChange: ((Int) -> Void)? = nil,
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        large: Bool = false
    ) {
        self.label = label
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.editable = editable
        self.hint = hint
        self.errorText = errorText
        self.hasInfo = hasInfo
        self.onChange = onChange
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.height = large ? 48 : 40
        self._textValue = State(initialValue: String(value.wrappedValue))
    }

    private var hasError: Bool { errorText != nil }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                HStack(spacing: 4) {
                    Text(label).textStyle(.labelSm600).foregroundStyle(labelColor)
                    if hasInfo {
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(theme.text(.textTertiary))
                    }
                }
            }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                stepper("minus", label: String(themeKit: "Decrease"), enabled: value > range.lowerBound) {
                    setValue(value - step)
                }
                middle
                    .frame(maxWidth: .infinity)
                stepper("plus", label: String(themeKit: "Increase"), enabled: value < range.upperBound) {
                    setValue(value + step)
                }
            }
            .padding(.horizontal, Theme.SpacingKey.xs.value)
            .frame(height: height)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: hasError || isFocused ? 1.5 : 1)
            )
            .a11y(A11yElement.Control.stepper, in: accessibilityID)
            .accessibilityValue("\(value)")

            if let message = errorText ?? hint {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
            }
        }
        .onChange(of: value) { _, newValue in
            // Reflect stepper / external changes back into the editable text.
            let normalized = String(newValue)
            if textValue != normalized && !isFocused { textValue = normalized }
        }
        .onChange(of: textValue) { _, newText in
            // Live-apply a valid in-range entry; full clamp happens on commit.
            guard editable, let parsed = Self.parse(newText, range: range) else { return }
            let clamped = Self.clamp(parsed, to: range)
            if clamped == parsed, clamped != value { value = clamped; onChange?(clamped) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused { commit() }
        }
    }

    @ViewBuilder
    private var middle: some View {
        HStack(spacing: 2) {
            if editable {
                TextField("", text: $textValue)
                    .multilineTextAlignment(.center)
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .submitLabel(.done)
                    .onSubmit { commit() }
                    .numericKeyboard(allowsNegative: range.lowerBound < 0)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(label ?? String(themeKit: "Value"))
            } else {
                Text("\(value)")
            }
            if let unit {
                Text(unit)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
            }
        }
        .textStyle(.labelMd600)
        .monospacedDigit()
        .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
    }

    private func stepper(_ systemName: String, label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        let active = enabled && isEnabled
        return Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(active ? theme.foreground(.fgSecondary) : theme.text(.textDisabled))
                .frame(width: height - 12, height: height - 12)
                .background(active ? theme.background(.bgHero) : theme.background(.bgSecondaryLight),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
        }
        .buttonStyle(.plain)
        .disabled(!active)
        .accessibilityLabel(label)
    }

    private func setValue(_ new: Int) {
        let clamped = Self.clamp(new, to: range)
        if clamped != value { value = clamped; onChange?(clamped) }
        textValue = String(clamped)
    }

    private func commit() {
        let clamped = Self.clamp(Self.parse(textValue, range: range) ?? value, to: range)
        if clamped != value { value = clamped; onChange?(clamped) }
        textValue = String(clamped)
    }

    private var labelColor: Color {
        hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textPrimary)
    }
    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if isFocused { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
    }

    // MARK: - Pure helpers (extracted for testing)

    /// Constrains `value` to `range`.
    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Parses user text into an Int, keeping only digits (and a leading minus when
    /// the range admits negatives). Returns nil for empty / non-numeric input.
    static func parse(_ text: String, range: ClosedRange<Int>) -> Int? {
        let negative = range.lowerBound < 0 && text.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty, let magnitude = Int(digits) else { return nil }
        return negative ? -magnitude : magnitude
    }
}

private extension View {
    /// Numeric keyboard (iOS only). Uses a punctuation keyboard when negatives are
    /// allowed so the user can type a leading minus.
    @ViewBuilder
    func numericKeyboard(allowsNegative: Bool) -> some View {
        #if os(iOS)
        self.keyboardType(allowsNegative ? .numbersAndPunctuation : .numberPad)
        #else
        self
        #endif
    }
}

#Preview {
    struct Demo: View {
        @State var a = 1
        @State var b = 1
        @State var price = 500
        var body: some View {
            VStack(spacing: 16) {
                InputNumber(label: "Adults", value: $a, range: 1...9, unit: "kişi", hint: "Type or step.", large: true)
                InputNumber(label: "Children", value: $b, errorText: "Too many")
                InputNumber(label: "Max price", value: $price, range: 0...10000, step: 50, unit: "₺")
            }
            .padding()
        }
    }
    return Demo()
}
