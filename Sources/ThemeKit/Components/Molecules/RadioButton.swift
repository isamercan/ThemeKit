//
//  RadioButton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Selected-state indicator of a radio. (Reference RadioButton parity.)
public enum RadioButtonType {
    /// A filled dot in the middle; tap selects (one-way).
    case select
    /// A checkmark glyph; tap toggles on and off.
    case check
}

/// Indicator rendering of a `.check` radio. (Reference RadioButtonStyle.)
public enum RadioButtonStyle {
    /// A checkmark glyph.
    case plain
    /// A small inset filled circle inside a ring (an "inner" dot look).
    case inner
}

/// Gap between the radio and its label. (Reference RadioButtonPadding.)
public enum RadioButtonPadding {
    case small, medium, large
    var value: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.sm.value      // 8
        case .medium: return Theme.SpacingKey.md.value * 0.75   // 12
        case .large: return Theme.SpacingKey.md.value      // 16
        }
    }
}

/// Figma "Control Items" → Radioboxes. Sizes Small (20) / Medium (24);
/// states selected / disabled. Colors from theme tokens. Per the modifier-based
/// architecture (COMPONENT_REFACTOR_RULES R1–R7) the init takes only its label
/// and the `isSelected` binding; every appearance/validation axis is a
/// chainable, order-free modifier. Size is native
/// (`@Environment(\.controlSize)`); `disabled` is native (`@Environment(\.isEnabled)`, R3).
///
///     RadioButton("Remember me", isSelected: $on)
///         .type(.check).radioStyle(.inner).gap(.medium)
///         .description("Stay signed in on this device")
///         .controlSize(.small)            // native size
///         .disabled(!editable)            // native — R3
///
/// The chrome (indicator, label, description) is drawn by the active
/// ``RadioButtonChromeStyle`` when one is set with `.radioButtonChromeStyle(_:)`
/// on the radio or an ancestor; the radio keeps its behaviour, accessibility
/// and validation messages either way.
public struct RadioButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.radioButtonChromeStyle) private var chromeStyle

    @Binding private var isSelected: Bool
    private let label: String?
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    // Appearance — mutated only through the modifiers below (R2).
    private var infoMessages: [InfoMessage] = []
    private var type: RadioButtonType = .select
    private var style: RadioButtonStyle = .plain
    private var gap: RadioButtonPadding = .small
    private var backgroundColor: Color?
    private var accent: SemanticColor?
    private var verticalAlignment: VerticalAlignment = .center
    private var accessibilityID: String?
    private var controlPlacement: HorizontalEdge = .leading   // A3
    private var customLabel: SlotContent?                     // D1 — `.label { }` slot
    private var descriptionText: String?                      // Checkbox parity
    /// Identifier element on the style path; RadioGroup rows set `option.<n>`.
    private var a11yElementName: String = A11yElement.Control.radio.rawValue
    /// Whether the style path speaks "selected" / "not selected" as the value.
    /// RadioGroup rows turn it off to match its built-in rows (trait only).
    private var speaksSelectionValue = true
    @Environment(\.isReadOnly) private var isReadOnly         // E1

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        _ label: String? = nil,
        isSelected: Binding<Bool>
    ) {   // R1 — content + binding
        self.label = label
        self._isSelected = isSelected
    }

    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }
    private var filled: Bool { isSelected && type == .check && style == .plain }
    /// Raw override wins, then the semantic accent (enabled only), then the hero token.
    private var fillColor: Color {
        if let backgroundColor { return backgroundColor }
        if isEnabled, let accent { return theme.resolve(accent).solid }
        return theme.background(isEnabled ? .bgHero : .bgSecondary)
    }

    public var body: some View {
        if chromeStyle.isDefault {
            builtInBody
        } else {
            styledBody
        }
    }

    /// The built-in chrome — unchanged from before the style door existed.
    private var builtInBody: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                if type == .check { isSelected.toggle() } else { isSelected = true }
            } label: {
                HStack(alignment: verticalAlignment, spacing: gap.value) {
                    if controlPlacement == .leading {
                        control
                        labelView
                    } else {
                        labelView
                        control
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, toggling blocked
            .a11y(A11yElement.Control.radio, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(isSelected ? String(themeKit: "selected") : String(themeKit: "not selected"))
            .modifier(RadioDescriptionHint(text: descriptionText))   // description isn't in the label — surface it here
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    /// A custom ``RadioButtonChromeStyle`` draws the chrome; the radio keeps
    /// the tap rule, read-only, the disabled gate, accessibility and messages.
    private var styledBody: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                if type == .check { isSelected.toggle() } else { isSelected = true }
            } label: {
                EmptyView()   // the bridge draws the style's chrome instead
            }
            .buttonStyle(RadioButtonChromeBridge(style: chromeStyle, template: chromeConfiguration))
            .disabled(!isEnabled)
            .allowsHitTesting(!isReadOnly)   // E1 — the chrome stays, toggling blocked
            .a11y(a11yElementName, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .modifier(SelectionValue(isSelected: isSelected, isSpoken: speaksSelectionValue))
            .modifier(RadioDescriptionHint(text: descriptionText))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    /// Everything the style reads except the live press state.
    private var chromeConfiguration: RadioButtonChromeStyleConfiguration {
        RadioButtonChromeStyleConfiguration(
            label: label,
            customLabel: customLabel.map { AnyView($0) },
            description: descriptionText,
            isSelected: isSelected,
            isEnabled: isEnabled,
            isPressed: false,
            isReadOnly: isReadOnly,
            type: type,
            radioStyle: style,
            validation: dominant,
            accent: accent,
            controlSize: controlSize,
            controlPlacement: controlPlacement,
            alignment: verticalAlignment,
            gap: gap,
            animation: motion,
            fillColorOverride: backgroundColor
        )
    }

    /// The radio glyph itself (extracted so `controlPlacement` can branch order).
    private var control: some View {
        Circle()
            .fill(filled ? fillColor : .clear)
            .overlay(Circle().strokeBorder(stroke, lineWidth: 1.5))
            .frame(width: controlSize.checkboxSide, height: controlSize.checkboxSide)
            .overlay(indicator.transition(.scale(scale: 0.6).combined(with: .opacity)))
            .animation(motion, value: isSelected)
    }

    /// The title, with the description under it when one is set.
    @ViewBuilder private var labelView: some View {
        if let descriptionText {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                titleView
                HelperText(descriptionText)
            }
        } else {
            titleView
        }
    }

    /// Built-in string label, or the `.label { }` slot when set (D1/B8).
    @ViewBuilder private var titleView: some View {
        if let customLabel {
            customLabel
        } else if let label {
            Text(label)
                .textStyle(.bodyBase400)
                .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
        }
    }

    private var stroke: Color {
        if !isEnabled { return theme.border(.borderPrimary) }
        if dominant == .error { return theme.border(.systemcolorsBorderError) }
        if dominant == .warning { return theme.border(.systemcolorsBorderWarning) }
        guard isSelected else { return theme.border(.borderPrimary) }
        return accent.map { theme.resolve($0).border } ?? theme.border(.borderHero)
    }

    @ViewBuilder
    private var indicator: some View {
        if isSelected {
            switch (type, style) {
            case (.select, _):
                Circle().fill(fillColor).frame(width: controlSize.checkboxSide * 0.5, height: controlSize.checkboxSide * 0.5)
            case (.check, .plain):
                Image(systemName: "checkmark")
                    .font(.system(size: controlSize.checkboxSide * 0.55, weight: .bold))
                    .foregroundStyle((isEnabled && backgroundColor == nil) ? (accent.map { theme.resolve($0).onSolid } ?? theme.foreground(.fgSecondary)) : theme.foreground(.fgSecondary))
            case (.check, .inner):
                ZStack {
                    Circle().fill(theme.background(.bgWhite))
                    Circle().fill(fillColor).padding(controlSize.checkboxSide * 0.18)
                }
                .frame(width: controlSize.checkboxSide * 0.74, height: controlSize.checkboxSide * 0.74)
            }
        }
    }
}

public extension RadioButton {
    /// Tag-based selection: binds to a shared `selection`, selected when it
    /// equals `tag`. Mirrors the reference's `RadioButton(tag:selection:)`.
    init<V: Hashable>(
        tag: V,
        selection: Binding<V?>
    ) {
        // The deselect branch only ever fires for `.check` radios (a `.select`
        // radio's tap sets `isSelected = true`, never false), so clearing to
        // `nil` is correct for both — and, crucially, it does NOT capture `type`,
        // so the `.type(.check)` modifier governs behavior correctly (R1).
        self.init(
            isSelected: Binding(
                get: { selection.wrappedValue == tag },
                set: { newValue in selection.wrappedValue = newValue ? tag : nil }
            )
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RadioButton {
    /// Selected-state indicator: `.select` (one-way dot) or `.check` (togglable checkmark).
    func type(_ t: RadioButtonType) -> Self { copy { $0.type = t } }

    /// Indicator rendering of a `.check` radio: `.plain` glyph or `.inner` dot.
    func radioStyle(_ s: RadioButtonStyle) -> Self { copy { $0.style = s } }

    /// Gap between the radio and its label: small / medium / large.
    func gap(_ p: RadioButtonPadding) -> Self { copy { $0.gap = p } }

    /// Override the selected-fill color (defaults to the `.bgHero` token, R4);
    /// prefer the token-fed `accent(_:)`. Wins over `accent`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func fillColor(_ c: Color?) -> Self { copy { $0.backgroundColor = c } }

    /// Semantic tint for the selected fill/border (glyph auto-contrasts); `nil`
    /// (default) uses the hero tokens. (daisyUI `radio-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Validation / info messages rendered under the control (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Vertical alignment of the radio against a multi-line label.
    func alignment(_ a: VerticalAlignment) -> Self { copy { $0.verticalAlignment = a } }

    /// Which side of the label the radio sits on: `.leading` (default) or
    /// `.trailing`. RTL-safe — `HorizontalEdge` follows the layout direction.
    /// (ControlRow `controlPlacement` vocabulary; A3.)
    func controlPlacement(_ edge: HorizontalEdge) -> Self { copy { $0.controlPlacement = edge } }

    /// Replaces the built-in text label with custom content (the canonical
    /// `.label { }` slot). The slot inherits the surrounding text environment;
    /// pass the string init arg too if the control should keep a VoiceOver label.
    func label<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customLabel = SlotContent(content) }
    }

    /// Supporting text under the label, drawn with ``HelperText`` and read by
    /// VoiceOver as the control's hint. `nil` (the default) hides it.
    /// (Checkbox `description(_:)` parity.)
    func description(_ text: String?) -> Self { copy { $0.descriptionText = text } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

extension RadioButton {
    /// The identifier element under ``a11yID(_:)`` on the custom-style path
    /// (default `radio`). RadioGroup names its styled rows `option.<n>`.
    internal func a11yElement(_ element: String) -> Self {
        var c = self
        c.a11yElementName = element
        return c
    }

    /// Whether the custom-style path speaks "selected" / "not selected" as the
    /// accessibility value (default on). RadioGroup's styled rows turn it off:
    /// its built-in rows carry only the selected trait.
    internal func speaksSelectionValue(_ on: Bool) -> Self {
        var c = self
        c.speaksSelectionValue = on
        return c
    }
}

/// The description as the accessibility hint — only when there is one, so a
/// radio without a description carries no hint at all.
struct RadioDescriptionHint: ViewModifier {
    let text: String?

    /// The hint to apply: the description, or `nil` when it's absent or empty.
    static func hint(for text: String?) -> String? {
        guard let text, !text.isEmpty else { return nil }
        return text
    }

    @ViewBuilder
    func body(content: Content) -> some View {
        if let hint = Self.hint(for: text) {
            content.accessibilityHint(hint)
        } else {
            content
        }
    }
}

/// "selected" / "not selected" as the accessibility value, unless the
/// composing control reads the selection from the trait alone.
private struct SelectionValue: ViewModifier {
    let isSelected: Bool
    let isSpoken: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if isSpoken {
            content.accessibilityValue(isSelected ? String(themeKit: "selected") : String(themeKit: "not selected"))
        } else {
            content
        }
    }
}

// MARK: - Preview

/// A preview-only chrome: a filled accent disc with a light center dot, a
/// medium-weight label and a secondary description, fading when disabled.
private struct PreviewDiscRadioChrome: RadioButtonChromeStyle {
    func makeBody(configuration: RadioButtonChromeStyleConfiguration) -> some View {
        PreviewDiscRadioChromeBody(configuration: configuration)
    }
}

private struct PreviewDiscRadioChromeBody: View {
    let configuration: RadioButtonChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        let c = configuration
        let paint = theme.resolve(c.accent ?? .primary)
        let side: CGFloat = 18
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            Circle()
                .fill(c.isSelected ? paint.solid : theme.background(.bgWhite))
                .overlay { Circle().fill(paint.onSolid).padding(side * 0.3).opacity(c.isSelected ? 1 : 0) }
                .overlay { Circle().strokeBorder(paint.border, lineWidth: c.isSelected ? 0 : 1) }
                .frame(width: side, height: side)
                .animation(c.animation, value: c.isSelected)
            if c.label != nil || c.description != nil {
                VStack(alignment: .leading, spacing: 2) {
                    if let label = c.label {
                        Text(label).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
                    }
                    if let description = c.description {
                        Text(description).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
            }
        }
        .opacity(c.isEnabled ? (c.isPressed ? 0.8 : 1) : 0.4)
        .contentShape(Rectangle())
    }
}

#Preview {
    PreviewMatrix("RadioButton") {
        PreviewCase("Unselected") { RadioButton(isSelected: .constant(false)) }
        PreviewCase("Selected") { RadioButton(isSelected: .constant(true)) }
        PreviewCase("Small") { RadioButton(isSelected: .constant(true)).controlSize(.small) }
        PreviewCase("Disabled") { RadioButton(isSelected: .constant(true)).disabled(true) }
        PreviewCase("Check + inner") { RadioButton("Remember me", isSelected: .constant(true)).type(.check).radioStyle(.inner).gap(.medium) }
        PreviewCase("Success accent") { RadioButton("Success accent", isSelected: .constant(true)).accent(.success) }
        PreviewCase("Error accent") { RadioButton("Error accent", isSelected: .constant(true)).type(.check).accent(.error) }
        PreviewCase("Large") { RadioButton("Large radio", isSelected: .constant(true)).controlSize(.large) }   // C4
        PreviewCase("Trailing control") {   // A3
            RadioButton("Radio on the trailing side", isSelected: .constant(true))
                .controlPlacement(.trailing)
        }
        PreviewCase("Label slot") {   // D1
            RadioButton("Card payment", isSelected: .constant(true))
                .label {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Image(systemName: "creditcard")
                        Text("Card payment").fontWeight(.semibold)
                    }
                    .textStyle(.bodyBase400)
                }
        }
        PreviewCase("Read-only") { RadioButton("Read-only (tap does nothing)", isSelected: .constant(true)).readOnly() }   // E1
        PreviewCase("Description") {
            RadioButton("Pay later", isSelected: .constant(true))
                .description("Pay at the property before check-in.")
                .alignment(.top)
        }
        PreviewCase("Custom chrome style") {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                RadioButton("Selected", isSelected: .constant(true))
                    .description("A chrome draws the indicator, label and description.")
                RadioButton("Unselected", isSelected: .constant(false))
                RadioButton("Disabled", isSelected: .constant(true)).disabled(true)
                RadioButton("Success accent", isSelected: .constant(true)).accent(.success)
                RadioButton(isSelected: .constant(true))   // indicator only
            }
            .radioButtonChromeStyle(PreviewDiscRadioChrome())
        }
        PreviewCase("Built-in vs .default") {
            HStack {
                RadioButton("Built-in", isSelected: .constant(true))
                RadioButton("Default", isSelected: .constant(true)).radioButtonChromeStyle(.default)
            }
        }
    }
}
