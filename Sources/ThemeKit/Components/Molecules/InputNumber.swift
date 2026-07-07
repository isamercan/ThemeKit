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
/// by `step`, and an optional `unit` suffix labels the value (e.g. "guest", "$").
/// The field chrome (fill + border) is a swappable ``FieldStyle`` set with
/// `.fieldStyle(_:)`.
public struct InputNumber: View {
    @Environment(\.theme) private var theme
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    @Binding private var value: Int
    private let range: ClosedRange<Int>

    // Appearance/state/config — mutated only through the modifiers below (R2).
    private var label: String?
    private var step: Int = 1
    private var unit: String?
    private var hint: String?
    private var errorText: String?
    private var accessibilityID: String?
    private var large: Bool = false
    private var editable: Bool = true
    private var hasInfo: Bool = false
    private var onChange: ((Int) -> Void)?

    @Environment(\.isEnabled) private var isEnabled

    @FocusState private var isFocused: Bool
    @State private var textValue: String

    public init(
        _ label: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99
    ) {   // R1
        self.label = label
        self._value = value
        self.range = range
        self._textValue = State(initialValue: String(value.wrappedValue))
    }

    private var hasError: Bool { errorText != nil }
    private var height: CGFloat { large ? 48 : 40 }

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

            fieldBox
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

    /// The composed stepper row (− / value / +), sized — everything the active
    /// ``FieldStyle`` receives as `configuration.content`.
    private var fieldCore: some View {
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
    }

    /// The stepper row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: the editable text field's focus drives `isFocused`;
    /// `errorText` drives `hasError` (InputNumber has no warning axis, so
    /// `hasWarning` is always false). `size` is nominal `.medium` — InputNumber
    /// has no `TextInputSize` axis; its 40/48pt (`large`) height stays carried by
    /// the content.
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: false,
            size: .medium
        ))
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
                InputNumber("Adults", value: $a, range: 1...9).unit("guest").hint("Type or step.").large()
                InputNumber("Children", value: $b).errorText("Too many")
                InputNumber("Max price", value: $price, range: 0...10000).step(50).unit("$")
                // Underlined chrome via the shared FieldStyle hook.
                InputNumber("Nights", value: $a, range: 1...30)
                    .fieldStyle(.underlined)
            }
            .padding()
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InputNumber {
    /// Increment/decrement applied by the − / + steppers.
    func step(_ s: Int) -> Self { copy { $0.step = s } }

    /// Trailing unit suffix labelling the value (e.g. "guest", "$").
    func unit(_ u: String?) -> Self { copy { $0.unit = u } }

    /// Helper text shown under the field (hidden while an error is present).
    func hint(_ text: String?) -> Self { copy { $0.hint = text } }

    /// Error text + error styling; takes precedence over `hint`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Use the larger (48pt) field height.
    func large(_ on: Bool = true) -> Self { copy { $0.large = on } }

    /// Whether the value can be typed (default true); `false` shows it read-only
    /// with steppers still active.
    func editable(_ on: Bool = true) -> Self { copy { $0.editable = on } }

    /// Shows an info-circle glyph next to the label.
    func hasInfo(_ on: Bool = true) -> Self { copy { $0.hasInfo = on } }

    /// Fires with the clamped value whenever it changes (stepper / type / commit).
    func onValueChange(_ action: ((Int) -> Void)?) -> Self { copy { $0.onChange = action } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
