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
/// The editor chrome (fill + border) is a swappable ``FieldStyle`` set with
/// `.fieldStyle(_:)`; the default reproduces the original look.
///
///     MultiLineTextInput("Notes", text: $text)
///         .placeholder("Write something…").characterLimit(200)
///         .errorText(invalid ? "Required" : nil)
///         .disabled(!editable)            // native — R3
public struct MultiLineTextInput: View {
    @Environment(\.theme) private var theme
    /// The editor chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle

    @Binding private var text: String
    private let label: String
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — set by `.readOnly(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fieldDefaults) private var fieldDefaults

    // Appearance / validation — mutated only through the modifiers below (R2).
    private var placeholder: String = ""
    private var characterLimit: Int?
    private var errorText: String?
    private var helperText: String?
    private var warningText: String?
    private var infoMessages: [InfoMessage] = []
    /// Set only by the `.size(_:)` modifier — an explicit size wins over the
    /// subtree `FieldDefaults.size` default (`explicitSize ?? fieldDefaults.size ?? .medium`).
    private var explicitSize: TextInputSize?
    private var minHeightOverride: CGFloat?
    private var countStyle: TextInputCountStyle = .count
    private var accessibilityID: String?

    /// Marks the editor as required: asterisk after the header label + ", required"
    /// appended to the accessibility label (HeroUI `isRequired`, TextInput parity).
    private var isRequired = false

    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`) —
    /// bridged to the editor's `@FocusState`, TextInput parity.
    private var externalFocus: Binding<Bool>?
    /// Internal editing-end hook (form wiring): fires with the current text when
    /// the editor loses focus.
    private var onEditingEnd: ((String) -> Void)?

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
        if let warningText { messages.append(InfoMessage(warningText, kind: .warning)) }
        if let helperText { messages.append(InfoMessage(helperText, kind: .info)) }
        return messages
    }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }

    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → `.medium`.
    private var size: TextInputSize { explicitSize ?? fieldDefaults.size ?? .medium }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    /// Message rows animate when micro-animations are on and the subtree default
    /// doesn't turn message motion off (Reduce Motion still wins inside MicroMotion).
    private var messagesAnimated: Bool { micro && (fieldDefaults.messagesAnimated ?? true) }

    /// An explicit `minHeight(_:)` wins over the `size(_:)` preset (order-free).
    private var minHeight: CGFloat {
        if let minHeightOverride { return minHeightOverride }
        switch size {
        case .xsmall: return 80
        case .small: return 100
        case .medium: return 120   // default — original metric
        case .large: return 160
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(spacing: 4) {   // matches the `InputLabel` atom's asterisk gap
                Text(label)
                    .foregroundStyle(labelColor)
                if isRequired && showsRequiredIndicator {
                    // Same treatment as `InputLabel.required()` — error-token asterisk.
                    Text(verbatim: "*")
                        .foregroundStyle(theme.foreground(.systemcolorsFgError))
                        .accessibilityHidden(true)   // spoken via the editor's label suffix
                }
            }
            .textStyle(.labelSm600)
            .a11y(A11yElement.Field.label, in: accessibilityID)

            editorBox

            HStack(alignment: .firstTextBaseline) {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let characterLimit {
                    Text(TextInput.counterText(count: text.count, maxLength: characterLimit, style: countStyle))
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
        // Animate message rows in/out (their `.transition` lives in
        // `InfoMessageList`); gated by `microAnimations` + Reduce Motion, and
        // by the subtree `FieldDefaults.messagesAnimated` default.
        .animation(MicroMotion.animation(.fast, enabled: messagesAnimated, reduceMotion: reduceMotion), value: messages)
        // External focus bridge (TextInput parity): a `true` write focuses the
        // editor; blurring resets the external binding so the owner stays in sync.
        .onChange(of: externalFocus?.wrappedValue ?? false) { _, want in
            if want && !isFocused && !isReadOnly { isFocused = true }   // E1 — no programmatic focus either
        }
        .onChange(of: isFocused) { _, now in
            if !now, externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
            if !now { onEditingEnd?(text) }   // form-wiring hook (`.field(_:in:)`)
        }
    }

    /// The editor + placeholder overlay, sized to `minHeight` — everything the
    /// ``FieldStyle`` receives as `configuration.content` (the height stays in
    /// the content; the style only wraps the chrome).
    private var editorCore: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: editorBinding)
                .focused($isFocused)
                .textStyle(.bodyBase400)
                .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                // Caret / selection tint follows the validation state (HeroUI invalid caret).
                .tint(theme.foreground(hasError ? .systemcolorsFgError : .fgHero))
                .scrollContentBackground(.hidden)
                .padding(8)
                .disabled(!isEnabled)
                // E1 — read-only: normal (non-dimmed) chrome + VoiceOver value,
                // but the editor can't be tapped into. NOT `.disabled` (dims).
                .allowsHitTesting(!isReadOnly)
                .a11y(A11yElement.Field.field, in: accessibilityID)
                .accessibilityLabel(isRequired ? label + ", " + String(themeKit: "required") : label)
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
    }

    /// The editor wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// `size` forwards the component's own `TextInputSize` preset (which keys the
    /// editor's *minHeight* here rather than a fixed row height); an explicit
    /// `minHeight(_:)` override changes the content height but still reports the
    /// declared preset to the style.
    @ViewBuilder
    private var editorBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(editorCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: size
        ))
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
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension MultiLineTextInput {
    /// Placeholder shown while the editor is empty.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Caps the input length and shows a `count/limit` counter.
    func characterLimit(_ limit: Int?) -> Self { copy { $0.characterLimit = limit } }

    /// How the character counter reads: `12/50` (`.count`, default) or `38 left`
    /// (`.remaining`) — TextInput parity.
    func countStyle(_ style: TextInputCountStyle) -> Self { copy { $0.countStyle = style } }

    /// Editor-height preset (`.xsmall` 80 … `.large` 160; defaults to `.medium`,
    /// 120). An explicit `minHeight(_:)` wins regardless of order, and an
    /// explicit size wins over the subtree `FieldDefaults.size` default.
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Marks the editor as required: renders an error-token asterisk after the
    /// header label (the `InputLabel` treatment) and appends ", required" to the
    /// editor's accessibility label (HeroUI `isRequired`, TextInput parity).
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Convenience error message appended as an `.error` `InfoMessage`.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Convenience hint appended to the message list as an `.info` `InfoMessage`
    /// (parity with `TextInput.helperText`).
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Convenience warning appended to the message list as a `.warning` `InfoMessage`
    /// (parity with `TextInput.warningText`).
    func warningText(_ text: String?) -> Self { copy { $0.warningText = text } }

    /// Validation / hint messages rendered beneath the editor.
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Minimum editor height (defaults to 120, R4); overrides the `size(_:)` preset.
    func minHeight(_ height: CGFloat) -> Self { copy { $0.minHeightOverride = height } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`) — TextInput parity.
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Internal editing-end hook used by the form wiring (`.field(_:in:)`) to
    /// re-validate against the form's rules when the editor loses focus.
    internal func onEditingEnd(_ handler: ((String) -> Void)?) -> Self { copy { $0.onEditingEnd = handler } }

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
        @State var feedback = ""
        @State var showError = false
        var body: some View {
            VStack(spacing: 16) {
                MultiLineTextInput("Notes", text: $text)
                    .placeholder("Write something…").characterLimit(200)
                MultiLineTextInput("Short note", text: $text)
                    .size(.xsmall).characterLimit(80).countStyle(.remaining)
                // Swapped chrome: underlined editor, same behavior.
                MultiLineTextInput("Underlined", text: $text)
                    .placeholder("No border, just a rule")
                    .fieldStyle(.underlined)
                // Required header + muted on-surface chrome, with an animated
                // error toggle (message rows fade + slide in/out).
                MultiLineTextInput("Feedback", text: $feedback)
                    .placeholder("Required, on-surface")
                    .required()
                    .errorText(showError ? "This field is required." : nil)
                    .fieldStyle(.muted)
                Button(showError ? "Hide error" : "Show error") { showError.toggle() }
                // Read-only (E1): normal chrome + value, editing blocked.
                MultiLineTextInput("Submitted review", text: .constant("Great stay, would book again."))
                    .size(.xsmall)
                    .readOnly()
            }
            .padding()
        }
    }
    return Demo()
}
