//
//  PaymentCardField.swift
//  ThemeKit
//
//  Molecule. A credit-card entry group — a formatted card-number field with live
//  brand detection, an expiry (MM/YY) and a CVV field, plus an optional cardholder
//  field. Token-bound. Bindings are owned by the caller.
//
//  ```swift
//  PaymentCardField(number: $number, expiry: $expiry, cvv: $cvv).holder($name)
//  ```
//

import SwiftUI

/// Card network detected from the number prefix.
public enum CardBrand: String, Sendable, CaseIterable, Codable {
    case visa, mastercard, amex, troy, unknown

    public var label: String {
        switch self { case .visa: "Visa"; case .mastercard: "Mastercard"; case .amex: "Amex"; case .troy: "Troy"; case .unknown: "" }
    }
    public var icon: String { "creditcard.fill" }

    public static func detect(_ number: String) -> CardBrand {
        let d = number.filter(\.isNumber)
        guard let first = d.first else { return .unknown }
        if d.hasPrefix("9792") { return .troy }
        switch first {
        case "4": return .visa
        case "5": return .mastercard
        case "3": return .amex
        default: return .unknown
        }
    }
}

public struct PaymentCardField: View {
    @Environment(\.theme) private var theme
    /// The per-row field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    /// There is no outer card shell here — each row (number / expiry / CVV /
    /// holder) is its own field box, so the whole box chroma belongs to
    /// `FieldStyle`, not `CardStyle`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.fieldDefaults) private var fieldDefaults
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no editing.
    @Environment(\.isReadOnly) private var isReadOnly

    /// Which of the four field rows currently holds keyboard focus.
    private enum FieldRole: Hashable { case number, expiry, cvv, holder }
    @FocusState private var focused: FieldRole?

    @Binding private var number: String
    @Binding private var expiry: String
    @Binding private var cvv: String
    // Config — mutated only through the modifiers below (R2).
    private var holder: Binding<String>?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var numberPlaceholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var numberPlaceholder: String { numberPlaceholderOverride ?? String(themeKit: "Card number") }
    private var holderPlaceholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var holderPlaceholder: String { holderPlaceholderOverride ?? String(themeKit: "Cardholder name") }
    /// Explicit `.size(_:)` preset — wins over the subtree `FieldDefaults.size`.
    private var explicitSize: TextInputSize?
    private var infoMessages: [InfoMessage] = []

    // Declarative validation (daisyUI Validator) — rules run against the
    // *card number* text at `effectiveValidationTrigger`; failures merge into
    // the rendered messages, driving the rows' error border automatically.
    private var validationRules: [ValidationRule] = []
    /// Set only by an explicit `on:` argument to `validate(_:on:)`; `nil` falls
    /// back to `FieldDefaults.validationTrigger`, then `.editingEnd` (F5).
    private var explicitValidationTrigger: ValidationTrigger?
    private var onValidation: ((Bool) -> Void)?
    @State private var validationMessages: [InfoMessage] = []

    public init(number: Binding<String>, expiry: Binding<String>, cvv: Binding<String>) {   // R1
        self._number = number
        self._expiry = expiry
        self._cvv = cvv
    }

    private var brand: CardBrand { CardBrand.detect(number) }
    private var accentBase: Color { theme.resolve(accent ?? .primary).base }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous) }
    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → the classic 52pt rows.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    /// Explicit `on:` argument → subtree `FieldDefaults.validationTrigger` → `.editingEnd` (F5).
    private var effectiveValidationTrigger: ValidationTrigger {
        explicitValidationTrigger ?? fieldDefaults.validationTrigger ?? .editingEnd
    }
    /// Explicit `infoMessages(_:)` plus any current `validate(_:on:)` failures.
    private var messages: [InfoMessage] { infoMessages + validationMessages }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }

    /// Runs the declared rules over the card-number text (first failure only,
    /// via `Validator`); publishes the result and reports validity.
    private func runValidation(_ value: String) {
        guard !validationRules.isEmpty else { return }
        let failures = Validator.validate(value, validationRules)
        if failures != validationMessages { validationMessages = failures }
        onValidation?(!failures.contains { $0.kind == .error })
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            numberField
            HStack(spacing: Theme.SpacingKey.sm.value) {
                fieldBox(.expiry) {
                    field($expiry, "MM/YY", role: .expiry, keyboard: .numberPad) { formatExpiry($0) }
                }
                fieldBox(.cvv) {
                    field($cvv, "CVV", role: .cvv, keyboard: .numberPad, secure: true) { String($0.filter(\.isNumber).prefix(4)) }
                }
            }
            if let holder {
                fieldBox(.holder) { field(holder, holderPlaceholder, role: .holder) { $0 } }
            }
            if !messages.isEmpty { InfoMessageList(messages) }
        }
        // `.live` validates every number change; other triggers re-validate once
        // a failure is visible so the error clears as the user fixes it.
        .onChangeCompat(of: number) { _, value in
            if effectiveValidationTrigger == .live || !validationMessages.isEmpty { runValidation(value) }
        }
        // `.editingEnd` / `.submit` fire when the number row loses focus.
        .onChangeCompat(of: focused) { old, now in
            if old == .number, now != .number, effectiveValidationTrigger != .live { runValidation(number) }
        }
    }

    private var numberField: some View {
        fieldBox(.number) {
            HStack(spacing: 8) {
                field($number, numberPlaceholder, role: .number, keyboard: .numberPad) { formatNumber($0) }
                if brand != .unknown {
                    HStack(spacing: 4) {
                        Image(systemName: brand.icon).font(.system(size: 15)).foregroundStyle(accentBase)
                        Text(brand.label).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    }
                    .transition(.opacity)
                }
            }
        }
    }

    /// One field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Mapping: `isFocused` is true for the row whose editor holds focus;
    /// `hasError`/`hasWarning` follow the dominant message kind (explicit
    /// `infoMessages` + validation failures — group-level, so every row recolors).
    /// With no explicit `.size(_:)` and no subtree `FieldDefaults.size` the rows
    /// keep their classic scaled 52pt min-height (nominal `.medium`). A custom
    /// `surface(_:)` key (anything other than the default `.bgBase`) is painted
    /// inside the content so the modifier keeps working; with the default key the
    /// fill is left entirely to the style.
    private func fieldBox<Content: View>(_ role: FieldRole, @ViewBuilder _ content: () -> Content) -> some View {
        let row = content()
            .padding(.horizontal, Theme.SpacingKey.md.value)
            // Scales with Dynamic Type (G2); a size preset remaps the height (C1).
            .scaledControlHeight(effectiveSize?.height ?? 52)
            .frame(maxWidth: .infinity, alignment: .leading)
        return fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: surfaceKey == .bgWhite
                ? AnyView(row)
                : AnyView(row.background(theme.background(surfaceKey), in: shape)),
            isFocused: focused == role,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize ?? .medium
        ))
    }

    @ViewBuilder private func field(_ binding: Binding<String>, _ placeholder: String, role: FieldRole,
                                    keyboard: KeyboardKind = .default, secure: Bool = false,
                                    format: @escaping (String) -> String) -> some View {
        Group {
            if secure {
                SecureField(placeholder, text: binding)
            } else {
                TextField(placeholder, text: binding)
            }
        }
        .focused($focused, equals: role)
        .textStyle(.bodyBase400)
        .foregroundStyle(theme.text(.textPrimary))
        // Read-only keeps the normal chrome + values but blocks focus/editing
        // on every row (E1 — distinct from `.disabled`).
        .allowsHitTesting(!isReadOnly)
        .applyKeyboard(keyboard)
        .onChangeCompat(of: binding.wrappedValue) { _, new in
            let f = format(new)
            if f != new { binding.wrappedValue = f }
        }
    }

    private func formatNumber(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(19))
        var out = ""
        for (i, ch) in digits.enumerated() {
            if i > 0 && i % 4 == 0 { out.append(" ") }
            out.append(ch)
        }
        return out
    }
    private func formatExpiry(_ raw: String) -> String {
        let digits = String(raw.filter(\.isNumber).prefix(4))
        guard digits.count > 2 else { return digits }
        let idx = digits.index(digits.startIndex, offsetBy: 2)
        return digits[..<idx] + "/" + digits[idx...]
    }
}

// MARK: Cross-platform keyboard helper

/// Keyboard hint that no-ops on macOS (where `.keyboardType` is unavailable).
public enum KeyboardKind: Sendable { case `default`, numberPad }

private extension View {
    @ViewBuilder func applyKeyboard(_ kind: KeyboardKind) -> some View {
        #if os(iOS)
        switch kind {
        case .default: self
        case .numberPad: self.keyboardType(.numberPad)
        }
        #else
        self
        #endif
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PaymentCardField {
    /// Adds a cardholder-name field bound to `binding`.
    func holder(_ binding: Binding<String>) -> Self { copy { $0.holder = binding } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Custom fill for the field rows, painted *inside* the ``FieldStyle`` chrome.
    /// With the default `.bgBase` the fill is left entirely to the style.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func placeholders(number: String? = nil, holder: String? = nil) -> Self {
        copy { if let number { $0.numberPlaceholderOverride = number }; if let holder { $0.holderPlaceholderOverride = holder } }
    }

    /// Control-height preset for every row. An explicit size wins over the
    /// subtree `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? 52pt`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Validation / info messages rendered under the group (drives the rows' border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Declarative validation (daisyUI Validator): `rules` run against the
    /// **card number** text (as displayed, space-grouped) at `trigger` —
    /// `.editingEnd`/`.submit` when the number row loses focus, `.live` per
    /// keystroke. Failures merge into the rendered messages and border state.
    /// Omitting `on:` follows the subtree `FieldDefaults.validationTrigger`
    /// default, then `.editingEnd` (F5); an explicit trigger always wins.
    ///
    ///     PaymentCardField(number: $num, expiry: $exp, cvv: $cvv)
    ///         .validate([.required(), .minLength(19, "Enter the full card number")])
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger? = nil) -> Self {
        copy { $0.validationRules = rules; if let trigger { $0.explicitValidationTrigger = trigger } }
    }

    /// Reports validity after each `validate(_:on:)` pass — `true` when no
    /// error-severity failure is present.
    func onValidation(_ handler: @escaping (Bool) -> Void) -> Self { copy { $0.onValidation = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var num = ""
        @State var exp = ""
        @State var cvv = ""
        @State var name = ""
        var body: some View {
            // Interactive group — the matrix wraps representative static states (one frame per cell).
            PreviewMatrix("PaymentCardField") {
                PreviewCase("With holder") { PaymentCardField(number: $num, expiry: $exp, cvv: $cvv).holder($name) }
                // Swapped chrome: every field row picks up the underlined style.
                PreviewCase("Underlined") {
                    PaymentCardField(number: $num, expiry: $exp, cvv: $cvv)
                        .fieldStyle(.underlined)
                }
                // Declarative validation over the card number (E3).
                PreviewCase("Validation") {
                    PaymentCardField(number: $num, expiry: $exp, cvv: $cvv)
                        .validate([.required(), .minLength(19, "Enter the full card number")])
                }
                // Size ramp — explicit `.size(_:)` wins over `FieldDefaults.size`.
                PreviewCase("Small") { PaymentCardField(number: $num, expiry: $exp, cvv: $cvv).size(.small) }
                // Read-only: values + normal chrome (brand detected), editing suppressed (E1).
                PreviewCase("Read-only") {
                    PaymentCardField(number: .constant("4111 1111 1111 1111"),
                                     expiry: .constant("12/29"), cvv: .constant("123"))
                        .readOnly()
                }
            }
        }
    }
    return Demo()
}
