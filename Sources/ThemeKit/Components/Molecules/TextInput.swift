//
//  TextInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Single floating-label text field. Carries the reference's production layers:
//  a `TextInputModel` config struct, a structured `[InfoMessage]` validation
//  model, and namespaced accessibility identifiers — alongside the flat init.
//

import SwiftUI

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
    public var accessibilityID: String?
    public var isEnabled: Bool

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
        accessibilityID: String? = nil,
        isEnabled: Bool = true
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
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
    }
}

public struct TextInput: View {
    @Binding private var text: String
    private let model: TextInputModel
    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`).
    private let externalFocus: Binding<Bool>?

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
        accessibilityID: String? = nil,
        externalFocus: Binding<Bool>? = nil,
        isEnabled: Bool = true
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
            infoMessages: messages, accessibilityID: accessibilityID, isEnabled: isEnabled
        )
    }

    private var floating: Bool { isFocused || !text.isEmpty }
    private var dominant: InfoMessage.Kind? { model.infoMessages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    private var showsClear: Bool { model.allowClear && !text.isEmpty && model.isEnabled && !model.isSecure }

    private var hasAddons: Bool { model.addonBefore != nil || model.addonAfter != nil }

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
                    .a11y(A11yElement.Field.label, in: model.accessibilityID)

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
            .foregroundStyle(Theme.shared.text(.textSecondary))
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(maxHeight: .infinity)
            .background(Theme.shared.background(.bgElevatorTertiary))
    }

    private var addonSeparator: some View {
        Rectangle().fill(Theme.shared.border(.borderPrimary)).frame(width: 1)
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
        .onTapGesture { if model.isEnabled { isFocused = true } }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            fieldBox

            if !model.infoMessages.isEmpty || (model.showCount && model.maxLength != nil) {
                HStack(alignment: .firstTextBaseline) {
                    InfoMessageList(model.infoMessages)
                        .a11y(A11yElement.Field.message, in: model.accessibilityID)
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if model.showCount, let maxLength = model.maxLength {
                        Text("\(text.count)/\(maxLength)")
                            .textStyle(.bodySm400)
                            .foregroundStyle(Theme.shared.text(.textTertiary))
                            .monospacedDigit()
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            var v = newValue
            if let formatter = model.formatter { v = formatter(v) }
            if let maxLength = model.maxLength, v.count > maxLength { v = String(v.prefix(maxLength)) }
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
                    .a11y(A11yElement.Field.secureField, in: model.accessibilityID)
            } else {
                TextField(model.placeholder, text: $text)
                    .a11y(A11yElement.Field.field, in: model.accessibilityID)
            }
        }
        .focused($isFocused)
        .textStyle(.bodyBase400)
        .foregroundStyle(model.isEnabled ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textDisabled))
        .tint(Theme.shared.foreground(.fgHero))
        .disabled(!model.isEnabled)
        .accessibilityLabel(model.label)
        .accessibilityValue(model.isSecure ? "" : text)
    }

    @ViewBuilder
    private var trailing: some View {
        if model.isSecure {
            Button { reveal.toggle() } label: {
                Icon(systemName: reveal ? "eye.slash" : "eye", size: .sm, color: Theme.shared.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.reveal, in: model.accessibilityID)
            .accessibilityLabel(reveal ? String(globalUIComponents: "Hide password") : String(globalUIComponents: "Show password"))
        } else if showsClear || (!text.isEmpty && isFocused && model.suffixSystemImage == nil) {
            Button { text = "" } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .a11y(A11yElement.Field.clear, in: model.accessibilityID)
            .accessibilityLabel("Temizle")
        } else if let suffixSystemImage = model.suffixSystemImage {
            Icon(systemName: suffixSystemImage, size: .sm, color: iconColor)
        }
    }

    private var labelColor: Color {
        if hasError { return Theme.shared.foreground(.systemcolorsFgError) }
        if hasWarning { return Theme.shared.foreground(.systemcolorsFgWarning) }
        if isFocused { return Theme.shared.text(.textHero) }
        return Theme.shared.text(.textTertiary)
    }

    private var iconColor: Color {
        model.isEnabled ? Theme.shared.text(.textTertiary) : Theme.shared.text(.textDisabled)
    }

    private var backgroundColor: Color {
        Theme.shared.background(model.isEnabled ? .bgWhite : .bgSecondaryLight)
    }

    private var borderColor: Color {
        if hasError { return Theme.shared.border(.systemcolorsBorderError) }
        if hasWarning { return Theme.shared.border(.systemcolorsBorderWarning) }
        if isFocused { return Theme.shared.border(.borderHero) }
        return Theme.shared.border(.borderPrimary)
    }
}

#Preview {
    struct Demo: View {
        @State var email = ""
        @State var pass = ""
        private var emailMessages: [InfoMessage] {
            Validator.validate(email, [.required(), .email()])
        }
        var body: some View {
            VStack(spacing: 16) {
                TextInput("Email", text: $email, leadingSystemImage: "envelope",
                          allowClear: true, infoMessages: emailMessages, accessibilityID: "loginEmail")
                TextInput(TextInputModel(label: "Şifre", isSecure: true, maxLength: 24, showCount: true,
                                         accessibilityID: "loginPass"), text: $pass)
            }
            .padding()
        }
    }
    return Demo()
}
