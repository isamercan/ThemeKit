//
//  MultiLineTextInput.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Improved, token-bound rewrite of the reference MultiLineInput — a bordered
/// TextEditor with header label, placeholder, character counter and error state.
/// Per the modifier-based architecture (COMPONENT_REFACTOR_RULES R1–R7) the init
/// takes only its label and the `text` binding; every other axis is a chainable,
/// order-free modifier. `disabled` is native (`@Environment(\.isEnabled)`, R3).
///
///     MultiLineTextInput("Notes", text: $text)
///         .placeholder("Write something…").characterLimit(200)
///         .errorText(invalid ? "Required" : nil)
///         .disabled(!editable)            // native — R3
public struct MultiLineTextInput: View {
    @Environment(\.theme) private var theme

    @Binding private var text: String
    private let label: String
    @Environment(\.isEnabled) private var isEnabled

    // Appearance / validation — mutated only through the modifiers below (R2).
    private var placeholder: String = ""
    private var characterLimit: Int?
    private var errorText: String?
    private var infoMessages: [InfoMessage] = []
    private var minHeight: CGFloat = 120
    private var accessibilityID: String?

    @FocusState private var isFocused: Bool

    public init(
        _ label: String,
        text: Binding<String>
    ) {   // R1 — content + binding
        self.label = label
        self._text = text
    }

    private var messages: [InfoMessage] {
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        return messages
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
                    .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                    .tint(theme.foreground(.fgHero))
                    .scrollContentBackground(.hidden)
                    .padding(8)
                    .disabled(!isEnabled)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(label)
                    .accessibilityValue(text)

                if text.isEmpty {
                    Text(placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textTertiary))
                        .padding(.horizontal, 13)
                        .padding(.vertical, 16)
                        .allowsHitTesting(false)
                }
            }
            .frame(minHeight: minHeight)
            .background(theme.background(isEnabled ? .bgWhite : .bgSecondaryLight),
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
                        .foregroundStyle(theme.text(.textTertiary))
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
        if hasError { return theme.foreground(.systemcolorsFgError) }
        if hasWarning { return theme.foreground(.systemcolorsFgWarning) }
        if isFocused { return theme.text(.textHero) }
        return theme.text(.textTertiary)
    }

    private var borderColor: Color {
        if hasError { return theme.border(.systemcolorsBorderError) }
        if hasWarning { return theme.border(.systemcolorsBorderWarning) }
        if isFocused { return theme.border(.borderHero) }
        return theme.border(.borderPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension MultiLineTextInput {
    /// Placeholder shown while the editor is empty.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Caps the input length and shows a `count/limit` counter.
    func characterLimit(_ limit: Int?) -> Self { copy { $0.characterLimit = limit } }

    /// Convenience error message appended as an `.error` `InfoMessage`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Validation / hint messages rendered beneath the editor.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Minimum editor height (defaults to 120, R4).
    func minHeight(_ height: CGFloat) -> Self { copy { $0.minHeight = height } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var text = ""
        var body: some View {
            MultiLineTextInput("Notes", text: $text)
                .placeholder("Write something…").characterLimit(200)
                .padding()
        }
    }
    return Demo()
}
