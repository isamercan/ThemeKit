//
//  Checkbox.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

extension ControlSize {
    /// Square side for checkbox / radio glyphs — maps the native control size to
    /// ThemeKit's Figma "Control Items" metrics (Small 20 / Medium 24 / Large 28).
    /// Driven by the native `.controlSize(_:)` cascade (default `.regular` → 24).
    var checkboxSide: CGFloat {
        switch self {
        case .mini, .small: return 20
        case .large, .extraLarge: return 28   // C4 — HeroUI `lg` box size
        default: return 24   // .regular (default)
        }
    }
}

/// Visual style of the checkbox box. (Reference Checkbox parity.)
public enum CheckboxType: Equatable {
    /// Standard box: fills with the accent and shows a white checkmark when on.
    case plain
    /// When on, draws a smaller inset filled square inside a persistent outline.
    case inner
    /// The box is always filled with `color` (a swatch); checkmark on when on.
    case customInner(color: Color)
}

/// Figma "Control Items" → Checkboxes. Sizes Small (20) / Medium (24);
/// states checked / disabled / indeterminate. Colors from theme tokens. Per the
/// modifier-based architecture (COMPONENT_REFACTOR_RULES R1–R7) the init takes only
/// its label and the `isChecked` binding; every appearance/validation axis is a
/// chainable, order-free modifier. Size is native
/// (`@Environment(\.controlSize)`); `disabled` is native (`@Environment(\.isEnabled)`, R3).
///
///     Checkbox("I accept the terms", isChecked: $on)
///         .type(.inner).indeterminate(mixed).alignment(.top)
///         .controlSize(.small)            // native size
///         .disabled(!editable)            // native — R3
public struct Checkbox: View {
    @Environment(\.theme) private var theme

    @Binding private var isChecked: Bool
    private let label: String?
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    // Appearance — mutated only through the modifiers below (R2).
    private var infoMessages: [InfoMessage] = []
    private var customSize: CGFloat?
    private var type: CheckboxType = .plain
    private var isIndeterminate: Bool = false
    private var alignment: VerticalAlignment = .center
    private var accent: SemanticColor?
    private var accessibilityID: String?
    private var controlPlacement: HorizontalEdge = .leading   // A2
    private var customLabel: SlotContent?                     // D1 — `.label { }` slot
    private var lineThrough = false                           // E4
    @Environment(\.isReadOnly) private var isReadOnly         // E1

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        _ label: String? = nil,
        isChecked: Binding<Bool>
    ) {   // R1 — content + binding
        self.label = label
        self._isChecked = isChecked
    }

    private var side: CGFloat { customSize ?? controlSize.checkboxSide }
    private var selected: Bool { isChecked || isIndeterminate }
    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }

    /// Selected fill — the semantic accent when set (and enabled), else the hero token.
    private var selectedFill: Color {
        if isEnabled, let accent { return accent.solid }
        return theme.background(isEnabled ? .bgHero : .bgSecondary)
    }
    /// Glyph tint on top of the selected fill (auto-contrasts against an accent).
    private var glyphColor: Color {
        if isEnabled, let accent { return accent.onSolid }
        return theme.foreground(.fgSecondary)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                isChecked.toggle()
            } label: {
                HStack(alignment: alignment, spacing: Theme.SpacingKey.sm.value) {
                    if controlPlacement == .leading {
                        box
                        labelView
                    } else {
                        labelView
                        box
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, toggling blocked
            .a11y(A11yElement.Control.checkbox, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(isIndeterminate ? String(themeKit: "mixed") : (isChecked ? String(themeKit: "selected") : String(themeKit: "not selected")))
            .accessibilityAddTraits(isChecked ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    /// Built-in string label, or the `.label { }` slot when set (D1/B8). Both
    /// inherit the `lineThrough` treatment while checked (E4).
    @ViewBuilder private var labelView: some View {
        if let customLabel {
            customLabel
                .strikethrough(lineThrough && isChecked)
        } else if let label {
            Text(label)
                .textStyle(.bodyBase400)
                .strikethrough(lineThrough && isChecked)
                .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
        }
    }

    private var radius: CGFloat { Theme.RadiusRole.selector.value }

    private var box: some View {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(stroke, lineWidth: 1.5)
            )
            .frame(width: side, height: side)
            .overlay(glyph.transition(.scale(scale: 0.7).combined(with: .opacity)))
            .animation(motion, value: selected)
    }

    private var fill: Color {
        switch type {
        case .customInner(let color):
            return color
        case .plain, .inner:
            guard selected else { return .clear }
            // `.inner` keeps the outer box transparent; the inset square is the fill.
            if case .inner = type { return .clear }
            return selectedFill
        }
    }

    private var stroke: Color {
        if case .customInner = type { return .clear }
        if !isEnabled { return theme.border(.borderPrimary) }
        if dominant == .error { return theme.border(.systemcolorsBorderError) }
        if dominant == .warning { return theme.border(.systemcolorsBorderWarning) }
        guard selected else { return theme.border(.borderPrimary) }
        return accent?.border ?? theme.border(.borderHero)
    }

    @ViewBuilder
    private var glyph: some View {
        if case .inner = type {
            if selected {
                RoundedRectangle(cornerRadius: max(radius - 2, 1), style: .continuous)
                    .fill(selectedFill)
                    .padding(side * 0.2)
                    .overlay {
                        if isIndeterminate {
                            Image(systemName: "minus")
                                .font(.system(size: side * 0.34, weight: .bold))
                                .foregroundStyle(glyphColor)
                        }
                    }
            }
        } else if selected {
            Image(systemName: isIndeterminate ? "minus" : "checkmark")
                .font(.system(size: side * 0.6, weight: .bold))
                .foregroundStyle(glyphColor)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Checkbox {
    /// Visual style of the box: `.plain`, `.inner`, or `.customInner(color:)`.
    func type(_ t: CheckboxType) -> Self { copy { $0.type = t } }

    /// Always fills the box with a semantic swatch (the `.customInner` type),
    /// resolved from the token's solid role — the token-bound path.
    func customInner(_ color: SemanticColor) -> Self {
        copy { $0.type = .customInner(color: color.solid) }
    }

    /// Raw swatch fill (back-compat); prefer the token-bound `customInner(_:)`.
    @available(*, deprecated, message: "Use customInner(_:) with a SemanticColor token.")
    func customInner(color: Color) -> Self {
        copy { $0.type = .customInner(color: color) }
    }

    /// Renders the indeterminate (mixed) state instead of a checkmark.
    func indeterminate(_ on: Bool = true) -> Self { copy { $0.isIndeterminate = on } }

    /// Vertical alignment of the box against a multi-line label.
    func alignment(_ a: VerticalAlignment) -> Self { copy { $0.alignment = a } }

    /// Which side of the label the box sits on: `.leading` (default) or
    /// `.trailing`. RTL-safe — `HorizontalEdge` follows the layout direction.
    /// (ControlRow `controlPlacement` vocabulary; A2.)
    func controlPlacement(_ edge: HorizontalEdge) -> Self { copy { $0.controlPlacement = edge } }

    /// Replaces the built-in text label with custom content (the canonical
    /// `.label { }` slot). The slot inherits the surrounding text environment
    /// and the `lineThrough()` treatment; pass the string init arg too if the
    /// control should keep a VoiceOver label.
    func label<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customLabel = SlotContent(content) }
    }

    /// Strikes the label through while checked (HeroUI Checkbox `lineThrough`).
    func lineThrough(_ on: Bool = true) -> Self { copy { $0.lineThrough = on } }

    /// Overrides the box side length, bypassing the native `.controlSize` metric.
    func customSize(_ side: CGFloat?) -> Self { copy { $0.customSize = side } }

    /// Semantic tint for the selected fill/border (glyph auto-contrasts); `nil`
    /// (default) uses the hero tokens. (daisyUI `checkbox-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Validation / info messages rendered under the control (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

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
    VStack(alignment: .leading, spacing: 12) {
        Checkbox(isChecked: .constant(false))
        Checkbox(isChecked: .constant(true))
        Checkbox(isChecked: .constant(true)).indeterminate()
        Checkbox(isChecked: .constant(true)).controlSize(.small)
        Checkbox(isChecked: .constant(true)).disabled(true)
        Checkbox("Success accent", isChecked: .constant(true)).accent(.success)
        Checkbox("Warning accent", isChecked: .constant(true)).accent(.warning)
        Checkbox("Large box", isChecked: .constant(true)).controlSize(.large)          // C4
        Checkbox("Box on the trailing side", isChecked: .constant(true))
            .controlPlacement(.trailing)                                               // A2
        Checkbox("Buy milk", isChecked: .constant(true)).lineThrough()                 // E4
        Checkbox("Terms", isChecked: .constant(false))
            .label {                                                                   // D1
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text("I accept the")
                    Text("Terms of Service").underline().fontWeight(.semibold)
                }
                .textStyle(.bodyBase400)
            }
        Checkbox("Read-only (tap does nothing)", isChecked: .constant(true)).readOnly() // E1
    }
    .padding()
}
