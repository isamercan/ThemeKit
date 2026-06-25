//
//  MultiLineTextInput.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference MultiLineInput — a bordered
//  TextEditor with header label, placeholder, character counter and error state.
//

import SwiftUI

public struct MultiLineTextInput: View {
    @Binding private var text: String
    private let label: String
    private let placeholder: String
    private let characterLimit: Int?
    private let messages: [InfoMessage]
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let minHeight: CGFloat

    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        text: Binding<String>,
        placeholder: String = "",
        characterLimit: Int? = nil,
        errorText: String? = nil,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        minHeight: CGFloat = 120
    ) {
        self.label = label
        self._text = text
        self.placeholder = placeholder
        self.characterLimit = characterLimit
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        self.messages = messages
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.minHeight = minHeight
    }

    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Text(label)
                .textStyle(.labelSm600)
                .foregroundStyle(labelColor)
                .a11y(A11yElement.Field.label, in: accessibilityID)

            ZStack(alignment: .topLeading) {
                TextEditor(text: editorBinding)
                    .focused($isFocused)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(isEnabled ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textDisabled))
                    .tint(Theme.shared.foreground(.fgHero))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .disabled(!isEnabled)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(label)
                    .accessibilityValue(text)

                if text.isEmpty {
                    Text(placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(Theme.shared.text(.textTertiary))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: minHeight)
            .background(Theme.shared.background(isEnabled ? .bgWhite : .bgSecondaryLight),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: isFocused || hasError || hasWarning ? 1.5 : 1)
            )

            HStack(alignment: .firstTextBaseline) {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let characterLimit {
                    Text("\(text.count)/\(characterLimit)")
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textTertiary))
                }
            }
        }
    }

    private var editorBinding: Binding<String> {
        Binding(
            get: { text },
            set: { newValue in
                if let limit = characterLimit, newValue.count > limit {
                    text = String(newValue.prefix(limit))
                } else {
                    text = newValue
                }
            }
        )
    }

    private var labelColor: Color {
        if hasError { return Theme.shared.foreground(.systemcolorsFgError) }
        if hasWarning { return Theme.shared.foreground(.systemcolorsFgWarning) }
        if isFocused { return Theme.shared.text(.textHero) }
        return Theme.shared.text(.textTertiary)
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
        @State var text = ""
        var body: some View {
            MultiLineTextInput("Notes", text: $text, placeholder: "Write something…", characterLimit: 200)
                .padding()
        }
    }
    return Demo()
}
