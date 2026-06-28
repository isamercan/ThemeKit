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
/// model, and namespaced accessibility identifiers — alongside the flat init.
public struct TextInput: View {
    @Environment(\.theme) private var theme

    @Binding private var text: String
    private let model: TextInputModel
    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`).
    private let externalFocus: Binding<Bool>?
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private var accessibilityID: String? = nil

    @FocusState private var isFocused: Bool
    @State private var reveal = false

    /// Config-model initializer.
    public init(_ model: TextInputModel, text: Binding<String>, externalFocus: Binding<Bool>? = nil) {
        self.model = model
        self._text = text
        self.externalFocus = externalFocus
    }

    /// Flat initializer (legacy helper/error/warning strings map to `InfoMessage`s).
    public init(
        _ label: String,
        text: Binding<String>,
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
        helperText: String? = nil,
        errorText: String? = nil,
        warningText: String? = nil,
        infoMessages: [InfoMessage] = [],
        externalFocus: Binding<Bool>? = nil,
        keyboardType: TextInputKeyboard = .default,
        textContentType: TextInputContentType? = nil,
        submitLabel: SubmitLabel = .return,
        autocapitalization: TextInputCapitalization? = nil,
        autocorrectionDisabled: Bool = false,
        hardLimit: Bool = true,
        countStyle: TextInputCountStyle = .count,
        onSubmit: (() -> Void)? = nil
    ) {
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        if let warningText { messages.append(InfoMessage(warningText, kind: .warning)) }
        if let helperText { messages.append(InfoMessage(helperText, kind: .info)) }
        self._text = text
        self.externalFocus = externalFocus
        self.model = TextInputModel(
            label: label, placeholder: placeholder, leadingSystemImage: leadingSystemImage,
            suffixSystemImage: suffixSystemImage, addonBefore: addonBefore, addonAfter: addonAfter,
            isSecure: isSecure, allowClear: allowClear,
            maxLength: maxLength, showCount: showCount, size: size, formatter: formatter,
            infoMessages: messages,
            keyboardType: keyboardType, textContentType: textContentType, submitLabel: submitLabel,
            autocapitalization: autocapitalization, autocorrectionDisabled: autocorrectionDisabled,
            hardLimit: hardLimit, countStyle: countStyle, onSubmit: onSubmit
        )
    }

    private var floating: Bool { isFocused || !text.isEmpty }
    private var dominant: InfoMessage.Kind? { model.infoMessages.dominantKind }
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

    private var fieldContent: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let leadingSystemImage = model.leadingSystemImage {
                Icon(systemName: leadingSystemImage, size: .sm, color: iconColor)
            }

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

            trailing
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

    @ViewBuilder
    private var fieldBox: some View {
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
        .background(backgroundColor, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(borderColor, lineWidth: isFocused || hasError || hasWarning ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { if isEnabled { isFocused = true } }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            fieldBox

            if !model.infoMessages.isEmpty || model.showCount {
                HStack(alignment: .firstTextBaseline) {
                    InfoMessageList(model.infoMessages)
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
        }
        .onChange(of: externalFocus?.wrappedValue ?? false) { _, want in
            if want && !isFocused { isFocused = true }
        }
        .onChange(of: isFocused) { _, now in
            if !now, externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
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
        .onSubmit { model.onSubmit?() }
        .accessibilityLabel(model.label)
        .accessibilityValue(model.isSecure ? "" : text)
    }

    @ViewBuilder
    private var trailing: some View {
        if model.isSecure {
            Button { reveal.toggle() } label: {
                Icon(systemName: reveal ? "eye.slash" : "eye", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.reveal, in: accessibilityID)
            .accessibilityLabel(reveal ? String(themeKit: "Hide password") : String(themeKit: "Show password"))
        } else if showsClear || (!text.isEmpty && isFocused && model.suffixSystemImage == nil) {
            Button { text = "" } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: accessibilityID)
            .accessibilityLabel("Temizle")
        } else if let suffixSystemImage = model.suffixSystemImage {
            Icon(systemName: suffixSystemImage, size: .sm, color: iconColor)
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

    private var backgroundColor: Color {
        theme.background(isEnabled ? .bgWhite : .bgSecondaryLight)
    }

    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if isFocused { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
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
        private var emailMessages: [InfoMessage] {
            Validator.validate(email, [.required(), .email()])
        }
        var body: some View {
            VStack(spacing: 16) {
                // Email keyboard + autofill, no autocaps/autocorrect, "next" return key.
                TextInput("Email", text: $email, leadingSystemImage: "envelope",
                          allowClear: true, infoMessages: emailMessages,
                          keyboardType: .emailAddress, textContentType: .emailAddress,
                          submitLabel: .next, autocapitalization: .never, autocorrectionDisabled: true)
                    .a11yID("loginEmail")
                // Password manager autofill on a secure field.
                TextInput(TextInputModel(label: "Şifre", isSecure: true, maxLength: 24, showCount: true,
                                         textContentType: .password,
                                         submitLabel: .go), text: $pass)
                    .a11yID("loginPass")
                // Soft limit: can exceed 80, counter turns red instead of truncating.
                TextInput("Bio", text: $bio, maxLength: 80, showCount: true,
                          hardLimit: false, countStyle: .remaining)
            }
            .padding()
        }
    }
    return Demo()
}

public extension TextInput {
    /// Sets the accessibility-identifier namespace for this field (its sub-elements
    /// — label, field, clear, reveal, messages — get `"<id>.<element>"`). Replaces
    /// the `accessibilityID:` init/model param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
