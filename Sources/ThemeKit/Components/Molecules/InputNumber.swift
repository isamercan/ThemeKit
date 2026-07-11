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
/// Binds to `Int` (the classic form counter) or, per Ant's decimal support, to
/// `Double` with a `.precision(_:)` fraction-digit axis (E11). Sits on the field
/// family's `TextInputSize` ramp via `.size(_:)` (C2). The field chrome (fill +
/// border) is a swappable ``FieldStyle`` set with `.fieldStyle(_:)`.
public struct InputNumber: View {
    @Environment(\.theme) private var theme
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    /// Canonical internal value — the `Int` init bridges its binding onto this
    /// (E11: one body serves both integer and decimal callers).
    @Binding private var value: Double
    private let range: ClosedRange<Double>

    // Appearance/state/config — mutated only through the modifiers below (R2).
    private var label: String?
    private var step: Double = 1
    private var unit: String?
    private var hint: String?
    private var errorText: String?
    private var accessibilityID: String?
    /// Set only by the `.size(_:)` modifier — an explicit size wins over the
    /// subtree `FieldDefaults.size` default (C2: `explicitSize ?? fieldDefaults.size`;
    /// with neither set, the field keeps its original 40pt height).
    private var explicitSize: TextInputSize?
    private var editable: Bool = true
    private var hasInfo: Bool = false
    /// Fraction digits shown / kept when committing (E11). 0 = integer behavior.
    private var fractionDigits: Int = 0
    private var onChange: ((Double) -> Void)?

    /// Marks the field as required: asterisk after the label + ", required"
    /// appended to the accessibility label (E2, HeroUI `isRequired`).
    private var isRequired = false

    // Declarative validation (E3, TextInput parity): rules run against the
    // field's text at `effectiveValidationTrigger`; the first failure renders
    // as an `InfoMessageList` row and drives the error border.
    private var validationRules: [ValidationRule] = []
    /// Set only by an explicit `on:` argument to `validate(_:on:)`; `nil` falls
    /// back to `FieldDefaults.validationTrigger`, then `.editingEnd` (F5).
    private var explicitValidationTrigger: ValidationTrigger?
    @State private var validationMessages: [InfoMessage] = []

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — set by `.readOnly(_:)`
    @Environment(\.fieldDefaults) private var fieldDefaults

    @FocusState private var isFocused: Bool
    @State private var textValue: String

    public init(
        _ label: String? = nil,
        value: Binding<Int>,
        range: ClosedRange<Int> = 0...99
    ) {   // R1
        self.label = label
        self._value = Binding(
            get: { Double(value.wrappedValue) },
            set: { value.wrappedValue = Int($0.rounded()) }
        )
        self.range = Double(range.lowerBound)...Double(range.upperBound)
        self._textValue = State(initialValue: String(value.wrappedValue))
    }

    /// Decimal-value overload (E11, Ant InputNumber decimal support). Shows two
    /// fraction digits by default; tune with `.precision(_:)`.
    public init(
        _ label: String? = nil,
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...99
    ) {   // R1
        self.label = label
        self._value = value
        self.range = range
        self.fractionDigits = 2
        self._textValue = State(initialValue: Self.format(value.wrappedValue, fractionDigits: 2))
    }

    /// `errorText` plus any validation failures (computed merge, TextInput idiom).
    private var messages: [InfoMessage] {
        var messages = validationMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        return messages
    }
    private var hasError: Bool { messages.dominantKind == .error }
    private var hasWarning: Bool { messages.dominantKind == .warning }
    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → `nil` (the field's
    /// own 40pt default height, kept for source-visual compatibility). C2.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    private var height: CGFloat { effectiveSize?.height ?? 40 }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    /// Explicit `on:` argument → subtree `FieldDefaults.validationTrigger` → `.editingEnd` (F5).
    private var effectiveValidationTrigger: ValidationTrigger {
        explicitValidationTrigger ?? fieldDefaults.validationTrigger ?? .editingEnd
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label {
                HStack(spacing: 4) {
                    Text(label).textStyle(.labelSm600).foregroundStyle(labelColor)
                    if isRequired && showsRequiredIndicator {
                        // Same treatment as `InputLabel.required()` — error-token asterisk.
                        Text(verbatim: "*")
                            .textStyle(.labelSm600)
                            .foregroundStyle(theme.foreground(.systemcolorsFgError))
                            .accessibilityHidden(true)   // spoken via the field's label suffix
                    }
                    if hasInfo {
                        Image(systemName: "info.circle").font(.system(size: 11)).foregroundStyle(theme.text(.textTertiary))
                    }
                }
            }

            fieldBox
                .a11y(A11yElement.Control.stepper, in: accessibilityID)
                .accessibilityValue(displayText)

            if !validationMessages.isEmpty {
                // Structured messages (`.validate(_:on:)`) — family-standard list.
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            } else if let message = errorText ?? hint {
                Text(message)
                    .textStyle(.bodySm400)
                    .foregroundStyle(hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
            }
        }
        .onAppear {
            // Normalize the initial text to the resolved precision (the `@State`
            // seed predates the `.precision(_:)` modifier).
            if !isFocused { textValue = format(value) }
        }
        .onChange(of: value) { _, newValue in
            // Reflect stepper / external changes back into the editable text.
            let normalized = format(newValue)
            if textValue != normalized && !isFocused { textValue = normalized }
        }
        .onChange(of: textValue) { _, newText in
            // Live-apply a valid in-range entry; full clamp happens on commit.
            defer {
                // `.live` validates every change; other triggers re-validate once
                // a failure is visible so the error clears as the user fixes it.
                if effectiveValidationTrigger == .live || !validationMessages.isEmpty { runValidation(newText) }
            }
            guard editable, let parsed = parseValue(newText) else { return }
            let clamped = Self.clamp(parsed, to: range)
            if clamped == parsed, clamped != value { value = clamped; onChange?(clamped) }
        }
        .onChange(of: isFocused) { _, focused in
            if !focused {
                commit()
                if effectiveValidationTrigger == .editingEnd { runValidation(textValue) }   // validate on blur
            }
        }
    }

    /// The composed stepper row (− / value / +), sized — everything the active
    /// ``FieldStyle`` receives as `configuration.content`. E1: read-only keeps
    /// the value with the normal chrome but drops the stepper affordances.
    private var fieldCore: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if !isReadOnly {
                stepper("minus", label: String(themeKit: "Decrease"), enabled: value > range.lowerBound) {
                    setValue(value - step)
                }
            }
            middle
                .frame(maxWidth: .infinity)
            if !isReadOnly {
                stepper("plus", label: String(themeKit: "Increase"), enabled: value < range.upperBound) {
                    setValue(value + step)
                }
            }
        }
        .padding(.horizontal, Theme.SpacingKey.xs.value)
        .scaledControlHeight(height)   // C2/G2 — scales with Dynamic Type
    }

    /// The stepper row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: the editable text field's focus drives `isFocused`;
    /// `errorText` / validation failures drive `hasError` / `hasWarning`. `size`
    /// reports the resolved `TextInputSize` axis (C2: `.size(_:)` →
    /// `FieldDefaults.size` → nominal `.medium` while unset, in which case the
    /// row keeps its own 40pt height).
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize ?? .medium
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
                    // E1 — read-only: normal (non-dimmed) value + VoiceOver value,
                    // but the field can't be tapped into. NOT `.disabled` (dims).
                    .allowsHitTesting(!isReadOnly)
                    .submitLabel(.done)
                    .onSubmit {
                        commit()
                        runValidation(textValue)   // submit is the strongest trigger — always validate
                    }
                    .numericKeyboard(allowsNegative: range.lowerBound < 0, allowsDecimals: fractionDigits > 0)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(accessibleLabel)
            } else {
                Text(displayText)
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

    private var accessibleLabel: String {
        let base = label ?? String(themeKit: "Value")
        return isRequired ? base + ", " + String(themeKit: "required") : base
    }

    private var displayText: String { format(value) }
    private func format(_ v: Double) -> String { Self.format(v, fractionDigits: fractionDigits) }

    /// Rounds to the declared precision (whole numbers when `fractionDigits == 0`).
    private func quantize(_ v: Double) -> Double {
        guard fractionDigits > 0 else { return v.rounded() }
        let scale = pow(10.0, Double(fractionDigits))
        return (v * scale).rounded() / scale
    }

    /// Integer parsing while `fractionDigits == 0` (legacy digits-only semantics),
    /// decimal parsing otherwise.
    private func parseValue(_ text: String) -> Double? {
        guard fractionDigits > 0 else {
            return Self.parseInteger(text, allowsNegative: range.lowerBound < 0).map(Double.init)
        }
        return Self.parseDecimal(text, allowsNegative: range.lowerBound < 0)
    }

    private func setValue(_ new: Double) {
        let clamped = Self.clamp(quantize(new), to: range)
        if clamped != value { value = clamped; onChange?(clamped) }
        textValue = format(clamped)
    }

    private func commit() {
        let clamped = Self.clamp(quantize(parseValue(textValue) ?? value), to: range)
        if clamped != value { value = clamped; onChange?(clamped) }
        textValue = format(clamped)
    }

    // MARK: Declarative validation (E3, TextInput parity)

    /// Runs the declared rules against the field's text (first failure only,
    /// via `Validator`) and publishes the result.
    private func runValidation(_ text: String) {
        guard !validationRules.isEmpty else { return }
        let failures = Validator.validate(text, validationRules)
        if failures != validationMessages { validationMessages = failures }
    }

    private var labelColor: Color {
        hasError ? theme.foreground(.systemcolorsFgError) : theme.text(.textPrimary)
    }

    // MARK: - Pure helpers (extracted for testing)

    /// Constrains `value` to `range`.
    static func clamp(_ value: Int, to range: ClosedRange<Int>) -> Int {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Constrains a decimal `value` to `range` (E11 counterpart of the Int overload).
    static func clamp(_ value: Double, to range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// Parses user text into an Int, keeping only digits (and a leading minus when
    /// the range admits negatives). Returns nil for empty / non-numeric input.
    static func parse(_ text: String, range: ClosedRange<Int>) -> Int? {
        parseInteger(text, allowsNegative: range.lowerBound < 0)
    }

    /// Digits-only integer parsing core (optional leading minus).
    static func parseInteger(_ text: String, allowsNegative: Bool) -> Int? {
        let negative = allowsNegative && text.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        let digits = text.filter(\.isNumber)
        guard !digits.isEmpty, let magnitude = Int(digits) else { return nil }
        return negative ? -magnitude : magnitude
    }

    /// Parses user text into a decimal value (E11), accepting both `.` and `,`
    /// as the fraction separator and keeping a leading minus when allowed.
    /// Returns nil for empty / non-numeric input.
    static func parseDecimal(_ text: String, allowsNegative: Bool) -> Double? {
        let negative = allowsNegative && text.trimmingCharacters(in: .whitespaces).hasPrefix("-")
        let filtered = text
            .replacingOccurrences(of: ",", with: ".")
            .filter { $0.isNumber || $0 == "." }
        guard !filtered.isEmpty, filtered != ".", let magnitude = Double(filtered) else { return nil }
        return negative ? -magnitude : magnitude
    }

    /// Renders `value` with the given fraction digits (whole-number string when 0).
    static func format(_ value: Double, fractionDigits: Int) -> String {
        guard fractionDigits > 0 else { return String(Int(value.rounded())) }
        return value.formatted(.number.precision(.fractionLength(fractionDigits)).grouping(.never))
    }
}

private extension View {
    /// Numeric keyboard (iOS only). Decimal entry gets a decimal pad; ranges that
    /// admit negatives use a punctuation keyboard so the user can type a minus.
    @ViewBuilder
    func numericKeyboard(allowsNegative: Bool, allowsDecimals: Bool) -> some View {
        #if os(iOS)
        self.keyboardType(allowsNegative ? .numbersAndPunctuation : (allowsDecimals ? .decimalPad : .numberPad))
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
        @State var weight = 22.5
        @State var rate = 0.125
        var body: some View {
            VStack(spacing: 16) {
                InputNumber("Adults", value: $a, range: 1...9).unit("guest").hint("Type or step.").size(.large)
                InputNumber("Children", value: $b).errorText("Too many")
                InputNumber("Max price", value: $price, range: 0...10000).step(50).unit("$")
                // Family size ramp (C2) — aligns with a `.small` TextInput beside it.
                InputNumber("Rooms", value: $b, range: 1...5).size(.small)
                // Decimal binding + precision (E11).
                InputNumber("Weight", value: $weight, range: 0...32).step(0.5).unit("kg")
                InputNumber("Rate", value: $rate, range: 0...1).step(0.005).precision(3)
                // Required indicator (E2) + declarative validation (E3).
                InputNumber("Guests", value: $a, range: 1...9)
                    .required()
                    .validate([.required(), .custom(String(themeKit: "Even numbers only")) { (Int($0) ?? 0).isMultiple(of: 2) }])
                // Read-only (E1): normal chrome + value, steppers hidden, typing blocked.
                InputNumber("Nights (submitted)", value: .constant(3), range: 1...30)
                    .unit("nights")
                    .readOnly()
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
    func step(_ s: Int) -> Self { copy { $0.step = Double(s) } }

    /// Decimal increment/decrement applied by the − / + steppers (E11).
    func step(_ s: Double) -> Self { copy { $0.step = s } }

    /// Fraction digits shown and kept on commit (E11, Ant `precision`). The
    /// decimal init defaults to 2; the `Int` init stays at 0 (whole numbers).
    func precision(_ digits: Int) -> Self { copy { $0.fractionDigits = max(0, digits) } }

    /// Trailing unit suffix labelling the value (e.g. "guest", "$").
    func unit(_ u: String?) -> Self { copy { $0.unit = u } }

    /// Helper text shown under the field (hidden while an error is present).
    func hint(_ text: String?) -> Self { copy { $0.hint = text } }

    /// Error text + error styling; takes precedence over `hint`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Control height on the field family's `TextInputSize` ramp (C2). An
    /// explicit size wins over the subtree `FieldDefaults.size` default; with
    /// neither set the field keeps its original 40pt height.
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Marks the field as required: renders an error-token asterisk after the
    /// label (the `InputLabel` treatment, honoring the subtree
    /// `FieldDefaults.requiredIndicator`) and appends ", required" to the
    /// field's accessibility label (E2, HeroUI `isRequired`).
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Declarative validation (E3, TextInput parity): evaluates `rules` against
    /// the field's text at `trigger` and feeds the first failure into the
    /// message list / error styling automatically. Omitting `on:` follows the
    /// subtree `FieldDefaults.validationTrigger` default, then `.editingEnd`
    /// (F5); an explicit trigger always wins.
    ///
    ///     InputNumber("Guests", value: $count)
    ///         .validate([.required()], on: .editingEnd)
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger? = nil) -> Self {
        copy { $0.validationRules = rules; if let trigger { $0.explicitValidationTrigger = trigger } }
    }

    /// Legacy binary height (regular 40pt / large 48pt), superseded by the
    /// field family's size ramp.
    @available(*, deprecated, message: "Use .size(.large) — InputNumber now sits on the TextInputSize ramp (C2)")
    func large(_ on: Bool = true) -> Self { on ? size(.large) : self }

    /// Whether the value can be typed (default true); `false` shows it read-only
    /// with steppers still active.
    func editable(_ on: Bool = true) -> Self { copy { $0.editable = on } }

    /// Shows an info-circle glyph next to the label.
    func hasInfo(_ on: Bool = true) -> Self { copy { $0.hasInfo = on } }

    /// Fires with the clamped value whenever it changes (stepper / type / commit).
    /// Decimal-bound fields receive the value rounded to whole numbers here —
    /// observe the `Double` binding itself for full precision.
    func onValueChange(_ action: ((Int) -> Void)?) -> Self {
        copy { $0.onChange = action.map { handler in { handler(Int($0.rounded())) } } }
    }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
