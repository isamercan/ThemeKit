//
//  TextInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

public enum TextInputSize {
    case xsmall, small, medium, large
    var height: CGFloat {
        switch self {
        case .xsmall: return 36
        case .small: return 44
        case .medium: return 56
        case .large: return 64
        }
    }
}

/// Platform-neutral keyboard hint. Maps to `UIKeyboardType` on iOS; ignored on macOS.
public enum TextInputKeyboard {
    case `default`, asciiCapable, numberPad, decimalPad, phonePad
    case emailAddress, url, numbersAndPunctuation, webSearch
}

/// Platform-neutral semantic content type for autofill / password managers.
/// Maps to `UITextContentType` on iOS; ignored on macOS.
public enum TextInputContentType {
    case name, givenName, familyName, username, password, newPassword, oneTimeCode
    case emailAddress, telephoneNumber, fullStreetAddress, postalCode, creditCardNumber, url
}

/// Platform-neutral autocapitalization behavior. Maps to `TextInputAutocapitalization`
/// on iOS; ignored on macOS.
public enum TextInputCapitalization {
    case never, characters, words, sentences
}

/// How the character counter reads: `12/50` (or `12`) vs. `38 left`.
public enum TextInputCountStyle {
    case count, remaining
}

/// Bundled configuration for a `TextInput` (reference "UI model" pattern).
public struct TextInputModel {
    public var label: String
    public var placeholder: String
    public var leadingSystemImage: String?
    public var suffixSystemImage: String?
    public var addonBefore: String?
    public var addonAfter: String?
    public var isSecure: Bool
    public var allowClear: Bool
    public var maxLength: Int?
    public var showCount: Bool
    public var size: TextInputSize
    public var formatter: TextInputFormatter?
    public var infoMessages: [InfoMessage]
    public var keyboardType: TextInputKeyboard
    public var textContentType: TextInputContentType?
    public var submitLabel: SubmitLabel
    public var autocapitalization: TextInputCapitalization?
    public var autocorrectionDisabled: Bool
    public var hardLimit: Bool
    public var countStyle: TextInputCountStyle
    public var onSubmit: (() -> Void)?

    public init(
        label: String,
        placeholder: String = "",
        leadingSystemImage: String? = nil,
        suffixSystemImage: String? = nil,
        addonBefore: String? = nil,
        addonAfter: String? = nil,
        isSecure: Bool = false,
        allowClear: Bool = false,
        maxLength: Int? = nil,
        showCount: Bool = false,
        size: TextInputSize = .medium,
        formatter: TextInputFormatter? = nil,
        infoMessages: [InfoMessage] = [],
        keyboardType: TextInputKeyboard = .default,
        textContentType: TextInputContentType? = nil,
        submitLabel: SubmitLabel = .return,
        autocapitalization: TextInputCapitalization? = nil,
        autocorrectionDisabled: Bool = false,
        hardLimit: Bool = true,
        countStyle: TextInputCountStyle = .count,
        onSubmit: (() -> Void)? = nil
    ) {
        self.label = label
        self.placeholder = placeholder
        self.leadingSystemImage = leadingSystemImage
        self.suffixSystemImage = suffixSystemImage
        self.addonBefore = addonBefore
        self.addonAfter = addonAfter
        self.isSecure = isSecure
        self.allowClear = allowClear
        self.maxLength = maxLength
        self.showCount = showCount
        self.size = size
        self.formatter = formatter
        self.infoMessages = infoMessages
        self.keyboardType = keyboardType
        self.textContentType = textContentType
        self.submitLabel = submitLabel
        self.autocapitalization = autocapitalization
        self.autocorrectionDisabled = autocorrectionDisabled
        self.hardLimit = hardLimit
        self.countStyle = countStyle
        self.onSubmit = onSubmit
    }
}

/// Single floating-label text field. Carries the reference's production layers:
/// a `TextInputModel` config struct, a structured `[InfoMessage]` validation
/// model, and namespaced accessibility identifiers. Per the modifier-based
/// architecture (COMPONENT_REFACTOR_RULES R1–R7) the canonical init takes only
/// its label and the `text` binding; every other axis is a chainable,
/// order-free modifier. `disabled` is native (`@Environment(\.isEnabled)`, R3).
/// The field chrome (fill + border) is a swappable ``FieldStyle`` set with
/// `.fieldStyle(_:)`; the default reproduces the original look.
///
///     TextInput("Email", text: $email)
///         .icon(leading: "envelope").clearable()
///         .keyboard(.emailAddress, contentType: .emailAddress)
///         .validate([.required(), .email()], on: .editingEnd)   // daisyUI Validator
///         .disabled(!editable)            // native — R3
///         .fieldStyle(.underlined)        // swap the chrome, keep the behavior
public struct TextInput: View {
    @Environment(\.theme) private var theme
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    @Binding private var text: String
    // Config — mutated only through the modifiers below (R2).
    private var model: TextInputModel
    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`).
    private var externalFocus: Binding<Bool>?
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private var accessibilityID: String? = nil

    // Custom slot views placed in the field row, before / after the text.
    // Additive to `icon` / `addons` — those APIs are untouched.
    private var leadingContent: AnyView? = nil
    private var trailingContent: AnyView? = nil

    // Convenience helper/error/warning strings — merged into the rendered
    // message list at render time (see `messages`), keeping modifiers order-free.
    private var helperText: String?
    private var errorText: String?
    private var warningText: String?

    // Declarative validation (daisyUI Validator, see `ValidationRule.swift`):
    // rules run at `validationTrigger` and their first failure is merged into
    // `messages`, driving the existing error styling automatically.
    private var validationRules: [ValidationRule] = []
    private var validationCheck: ((String) -> String?)?
    private var validationTrigger: ValidationTrigger = .editingEnd
    private var onValidation: ((Bool) -> Void)?
    @State private var validationMessages: [InfoMessage] = []

    @FocusState private var isFocused: Bool
    @State private var reveal = false

    /// Config-model initializer.
    public init(_ model: TextInputModel, text: Binding<String>, externalFocus: Binding<Bool>? = nil) {
        self.model = model
        self._text = text
        self.externalFocus = externalFocus
    }

    public init(_ label: String, text: Binding<String>) {   // R1 — content + binding
        self.model = TextInputModel(label: label)
        self._text = text
        self.externalFocus = nil
    }

    private var floating: Bool { isFocused || !text.isEmpty }
    /// `infoMessages` plus the helper/error/warning conveniences (computed merge).
    private var messages: [InfoMessage] {
        var messages = model.infoMessages + validationMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        if let warningText { messages.append(InfoMessage(warningText, kind: .warning)) }
        if let helperText { messages.append(InfoMessage(helperText, kind: .info)) }
        return messages
    }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    private var showsClear: Bool { model.allowClear && !text.isEmpty && isEnabled && !model.isSecure }

    private var hasAddons: Bool { model.addonBefore != nil || model.addonAfter != nil }
    private var isOverLimit: Bool { Self.isOverLimit(count: text.count, maxLength: model.maxLength) }

    /// Counter string for the given state (extracted for testing).
    static func counterText(count: Int, maxLength: Int?, style: TextInputCountStyle) -> String {
        switch style {
        case .count:
            if let maxLength { return "\(count)/\(maxLength)" }
            return "\(count)"
        case .remaining:
            guard let maxLength else { return "\(count)" }
            return String(themeKit: "\(maxLength - count) left")
        }
    }

    /// Whether `count` exceeds `maxLength` — only reachable with a soft limit
    /// (`hardLimit == false`), since a hard limit truncates before this is checked.
    static func isOverLimit(count: Int, maxLength: Int?) -> Bool {
        guard let maxLength else { return false }
        return count > maxLength
    }

    // MARK: Declarative validation (daisyUI Validator)

    private var hasValidation: Bool { !validationRules.isEmpty || validationCheck != nil }

    /// Runs the declared rules (first failure only, via `Validator`), then the
    /// closure check; publishes the result and reports validity.
    private func runValidation(_ value: String) {
        guard hasValidation else { return }
        var failures = Validator.validate(value, validationRules)
        if failures.isEmpty, let validationCheck, let message = validationCheck(value) {
            failures = [InfoMessage(message, kind: .error)]
        }
        if failures != validationMessages { validationMessages = failures }
        onValidation?(!failures.contains { $0.kind == .error })
    }

    private var fieldContent: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let leadingSystemImage = model.leadingSystemImage {
                Icon(systemName: leadingSystemImage).size(.sm).color(iconColor)
            }

            if let leadingContent { leadingContent }

            ZStack(alignment: .leading) {
                Text(model.label)
                    .textStyle(floating ? .labelSm600 : .bodyBase400)
                    .foregroundStyle(labelColor)
                    .offset(y: floating ? -11 : 0)
                    .a11y(A11yElement.Field.label, in: accessibilityID)

                field
                    .opacity(floating ? 1 : 0)
                    .offset(y: 9)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .animation(Motion.fast.animation, value: floating)

            if let trailingContent { trailingContent }

            trailingAccessory
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
    }

    @ViewBuilder
    private func addonSegment(_ text: String) -> some View {
        Text(text)
            .textStyle(.bodyBase400)
            .foregroundStyle(theme.text(.textSecondary))
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(maxHeight: .infinity)
            .background(theme.background(.bgElevatorTertiary))
    }

    private var addonSeparator: some View {
        Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1)
    }

    /// The composed field row (addons + content), sized — everything a
    /// `FieldStyle` receives as `configuration.content`.
    private var fieldCore: some View {
        Group {
            if hasAddons {
                HStack(spacing: 0) {
                    if let addonBefore = model.addonBefore {
                        addonSegment(addonBefore); addonSeparator
                    }
                    fieldContent
                    if let addonAfter = model.addonAfter {
                        addonSeparator; addonSegment(addonAfter)
                    }
                }
            } else {
                fieldContent
            }
        }
        .frame(height: model.size.height)
    }

    /// The field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Interaction (tap-to-focus) stays here; only the surface is delegated.
    @ViewBuilder
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: model.size
        ))
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isFocused = true } }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            fieldBox

            if !messages.isEmpty || model.showCount {
                HStack(alignment: .firstTextBaseline) {
                    InfoMessageList(messages)
                        .a11y(A11yElement.Field.message, in: accessibilityID)
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if model.showCount {
                        Text(Self.counterText(count: text.count, maxLength: model.maxLength, style: model.countStyle))
                            .textStyle(.bodySm400)
                            .foregroundStyle(isOverLimit ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                            .monospacedDigit()
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            var v = newValue
            if let formatter = model.formatter { v = formatter(v) }
            if model.hardLimit, let maxLength = model.maxLength, v.count > maxLength { v = String(v.prefix(maxLength)) }
            if v != text { text = v }
            // `.live` validates every change; other triggers re-validate once a
            // failure is visible so the error clears as the user fixes it.
            if validationTrigger == .live || !validationMessages.isEmpty { runValidation(v) }
        }
        .onChange(of: externalFocus?.wrappedValue ?? false) { _, want in
            if want && !isFocused { isFocused = true }
        }
        .onChange(of: isFocused) { _, now in
            if !now, externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
            if !now, validationTrigger == .editingEnd { runValidation(text) }   // validate on blur
        }
    }

    @ViewBuilder
    private var field: some View {
        Group {
            if model.isSecure && !reveal {
                SecureField(model.placeholder, text: $text)
                    .a11y(A11yElement.Field.secureField, in: accessibilityID)
            } else {
                TextField(model.placeholder, text: $text)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
            }
        }
        .focused($isFocused)
        .textStyle(.bodyBase400)
        .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
        .tint(theme.foreground(.fgHero))
        .disabled(!isEnabled)
        .submitLabel(model.submitLabel)
        .autocorrectionDisabled(model.autocorrectionDisabled)
        .textInputTraits(keyboard: model.keyboardType,
                         contentType: model.textContentType,
                         capitalization: model.autocapitalization)
        .onSubmit {
            runValidation(text)   // submit is the strongest trigger — always validate
            model.onSubmit?()
        }
        .accessibilityLabel(model.label)
        .accessibilityValue(model.isSecure ? "" : text)
    }

    @ViewBuilder
    private var trailingAccessory: some View {
        if model.isSecure {
            Button { reveal.toggle() } label: {
                Icon(systemName: reveal ? "eye.slash" : "eye").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.reveal, in: accessibilityID)
            .accessibilityLabel(reveal ? String(themeKit: "Hide password") : String(themeKit: "Show password"))
        } else if showsClear || (!text.isEmpty && isFocused && model.suffixSystemImage == nil) {
            Button { text = "" } label: {
                Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel("Temizle")
        } else if let suffixSystemImage = model.suffixSystemImage {
            Icon(systemName: suffixSystemImage).size(.sm).color(iconColor)
        }
    }

    private var labelColor: Color {
        if hasError { return theme.foreground(.systemcolorsFgError) }
        if hasWarning { return theme.foreground(.systemcolorsFgWarning) }
        if isFocused { return theme.text(.textHero) }
        return theme.text(.textTertiary)
    }

    private var iconColor: Color {
        isEnabled ? theme.text(.textTertiary) : theme.text(.textDisabled)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TextInput {
    /// Placeholder shown inside the field once the label floats.
    func placeholder(_ text: String) -> Self { copy { $0.model.placeholder = text } }

    /// Leading / trailing SF Symbols shown inside the field.
    func icon(leading: String? = nil, trailing: String? = nil) -> Self {
        copy { $0.model.leadingSystemImage = leading; $0.model.suffixSystemImage = trailing }
    }

    /// Static addon segments rendered before / after the field (e.g. "https://", ".com").
    func addons(before: String? = nil, after: String? = nil) -> Self {
        copy { $0.model.addonBefore = before; $0.model.addonAfter = after }
    }

    /// Custom view placed in the field row, before the label / text — e.g. a
    /// currency symbol, avatar, or flag. Additive to `icon(leading:)`, which
    /// keeps rendering ahead of it.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingContent = AnyView(content()) }
    }

    /// Custom view placed in the field row, after the label / text — e.g. a unit
    /// tag or an inline button. Additive to the trailing accessory (clear /
    /// reveal / `icon(trailing:)`), which keeps rendering after it.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingContent = AnyView(content()) }
    }

    /// Masks input as a password field with a reveal toggle.
    func secure(_ on: Bool = true) -> Self { copy { $0.model.isSecure = on } }

    /// Show a trailing clear button while the field has text.
    func clearable(_ on: Bool = true) -> Self { copy { $0.model.allowClear = on } }

    /// Caps input at `max` characters; a soft limit (`hardLimit: false`) allows overflow and flags the counter instead.
    func maxLength(_ max: Int?, hardLimit: Bool = true) -> Self {
        copy { $0.model.maxLength = max; $0.model.hardLimit = hardLimit }
    }

    /// Shows the character counter, reading `12/50` (`.count`) or `38 left` (`.remaining`).
    func showsCount(_ on: Bool = true, style: TextInputCountStyle = .count) -> Self {
        copy { $0.model.showCount = on; $0.model.countStyle = style }
    }

    /// Control height preset (defaults to `.medium`, R4).
    func size(_ size: TextInputSize) -> Self { copy { $0.model.size = size } }

    /// Live input formatter applied on every change (e.g. phone masks).
    func formatter(_ formatter: TextInputFormatter?) -> Self { copy { $0.model.formatter = formatter } }

    /// Convenience hint appended to the message list as an `.info` `InfoMessage`.
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Convenience error appended to the message list as an `.error` `InfoMessage`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Convenience warning appended to the message list as a `.warning` `InfoMessage`.
    func warningText(_ text: String?) -> Self { copy { $0.warningText = text } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.model.infoMessages = messages } }

    /// Declarative validation (daisyUI Validator): evaluates `rules` at
    /// `trigger` and feeds the first failure into the message list / error
    /// styling automatically — no hand-managed `infoMessages`.
    ///
    ///     TextInput("Email", text: $email)
    ///         .validate([.required(), .email()], on: .editingEnd)
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger = .editingEnd) -> Self {
        copy { $0.validationRules = rules; $0.validationTrigger = trigger }
    }

    /// Closure form of `validate(_:on:)` for dynamic failure messages:
    /// return the error text, or `nil` when the value passes. Runs after the
    /// rule array (if both are declared).
    func validate(on trigger: ValidationTrigger = .editingEnd, _ check: @escaping (String) -> String?) -> Self {
        copy { $0.validationCheck = check; $0.validationTrigger = trigger }
    }

    /// Reports validity after each `validate(_:on:)` pass — `true` when no
    /// error-severity rule failed (e.g. to gate a submit button).
    func onValidation(_ handler: ((Bool) -> Void)?) -> Self { copy { $0.onValidation = handler } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`).
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Keyboard / autofill / return-key / capitalization traits (iOS; ignored on macOS).
    func keyboard(_ type: TextInputKeyboard = .default,
                  contentType: TextInputContentType? = nil,
                  submit: SubmitLabel = .return,
                  capitalization: TextInputCapitalization? = nil) -> Self {
        copy {
            $0.model.keyboardType = type
            $0.model.textContentType = contentType
            $0.model.submitLabel = submit
            $0.model.autocapitalization = capitalization
        }
    }

    /// Disables system autocorrection for the field.
    func autocorrectionDisabled(_ on: Bool = true) -> Self { copy { $0.model.autocorrectionDisabled = on } }

    /// Action fired when the user submits (named `onCommit` to avoid shadowing SwiftUI's `.onSubmit`).
    func onCommit(_ action: (() -> Void)?) -> Self { copy { $0.model.onSubmit = action } }

    /// Sets the accessibility-identifier namespace for this field (its sub-elements
    /// — label, field, clear, reveal, messages — get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Platform keyboard traits

private extension View {
    /// Applies keyboard / autofill / capitalization traits (iOS only; no-op on macOS).
    @ViewBuilder
    func textInputTraits(
        keyboard: TextInputKeyboard,
        contentType: TextInputContentType?,
        capitalization: TextInputCapitalization?
    ) -> some View {
        #if os(iOS)
        self.keyboardType(keyboard.uiKeyboardType)
            .textContentType(contentType?.uiTextContentType)
            .textInputAutocapitalization(capitalization?.swiftUIValue)
        #else
        self
        #endif
    }
}

#if os(iOS)
private extension TextInputKeyboard {
    var uiKeyboardType: UIKeyboardType {
        switch self {
        case .default: return .default
        case .asciiCapable: return .asciiCapable
        case .numberPad: return .numberPad
        case .decimalPad: return .decimalPad
        case .phonePad: return .phonePad
        case .emailAddress: return .emailAddress
        case .url: return .URL
        case .numbersAndPunctuation: return .numbersAndPunctuation
        case .webSearch: return .webSearch
        }
    }
}

private extension TextInputContentType {
    var uiTextContentType: UITextContentType {
        switch self {
        case .name: return .name
        case .givenName: return .givenName
        case .familyName: return .familyName
        case .username: return .username
        case .password: return .password
        case .newPassword: return .newPassword
        case .oneTimeCode: return .oneTimeCode
        case .emailAddress: return .emailAddress
        case .telephoneNumber: return .telephoneNumber
        case .fullStreetAddress: return .fullStreetAddress
        case .postalCode: return .postalCode
        case .creditCardNumber: return .creditCardNumber
        case .url: return .URL
        }
    }
}

private extension TextInputCapitalization {
    var swiftUIValue: TextInputAutocapitalization {
        switch self {
        case .never: return .never
        case .characters: return .characters
        case .words: return .words
        case .sentences: return .sentences
        }
    }
}
#endif

#Preview {
    struct Demo: View {
        @State var email = ""
        @State var pass = ""
        @State var bio = ""
        @State var amount = ""
        private var emailMessages: [InfoMessage] {
            Validator.validate(email, [.required(), .email()])
        }
        var body: some View {
            VStack(spacing: 16) {
                // Email keyboard + autofill, no autocaps/autocorrect, "next" return key.
                TextInput("Email", text: $email)
                    .icon(leading: "envelope").clearable()
                    .infoMessages(emailMessages)
                    .keyboard(.emailAddress, contentType: .emailAddress, submit: .next, capitalization: .never)
                    .autocorrectionDisabled()
                    .a11yID("loginEmail")
                // Password manager autofill on a secure field (config-model entry point).
                TextInput(TextInputModel(label: "Password", isSecure: true, maxLength: 24, showCount: true,
                                         textContentType: .password,
                                         submitLabel: .go), text: $pass)
                    .a11yID("loginPass")
                // Soft limit: can exceed 80, counter turns red instead of truncating.
                TextInput("Bio", text: $bio)
                    .maxLength(80, hardLimit: false).showsCount(style: .remaining)
                // Underlined chrome + custom leading/trailing slots.
                TextInput("Amount", text: $amount)
                    .leading { Text("$").textStyle(.bodyBase400) }
                    .trailing { Text("USD").textStyle(.labelSm600) }
                    .keyboard(.decimalPad)
                    .fieldStyle(.underlined)
            }
            .padding()
        }
    }
    return Demo()
}
