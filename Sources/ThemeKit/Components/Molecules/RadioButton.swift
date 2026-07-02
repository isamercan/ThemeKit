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
///         .controlSize(.small)            // native size
///         .disabled(!editable)            // native — R3
public struct RadioButton: View {
    @Environment(\.theme) private var theme

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
    private var verticalAlignment: VerticalAlignment = .center
    private var accessibilityID: String?

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
    private var fillColor: Color { backgroundColor ?? theme.background(isEnabled ? .bgHero : .bgSecondary) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                if type == .check { isSelected.toggle() } else { isSelected = true }
            } label: {
                HStack(alignment: verticalAlignment, spacing: gap.value) {
                    Circle()
                        .fill(filled ? fillColor : .clear)
                        .overlay(Circle().strokeBorder(stroke, lineWidth: 1.5))
                        .frame(width: controlSize.checkboxSide, height: controlSize.checkboxSide)
                        .overlay(indicator.transition(.scale(scale: 0.6).combined(with: .opacity)))
                        .animation(motion, value: isSelected)
                    if let label {
                        Text(label)
                            .textStyle(.bodyBase400)
                            .foregroundStyle(isEnabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .a11y(A11yElement.Control.radio, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(isSelected ? String(themeKit: "selected") : String(themeKit: "not selected"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    private var stroke: Color {
        if !isEnabled { return theme.border(.borderPrimary) }
        if dominant == .error { return theme.border(.systemcolorsBorderError) }
        if dominant == .warning { return theme.border(.systemcolorsBorderWarning) }
        return (isSelected) ? theme.border(.borderHero) : theme.border(.borderPrimary)
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
                    .foregroundStyle(theme.foreground(.fgSecondary))
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

    /// Override the selected-fill color (defaults to the `.bgHero` token, R4).
    func fillColor(_ c: Color?) -> Self { copy { $0.backgroundColor = c } }

    /// Validation / info messages rendered under the control (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Vertical alignment of the radio against a multi-line label.
    func alignment(_ a: VerticalAlignment) -> Self { copy { $0.verticalAlignment = a } }

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
        RadioButton(isSelected: .constant(false))
        RadioButton(isSelected: .constant(true))
        RadioButton(isSelected: .constant(true)).controlSize(.small)
        RadioButton(isSelected: .constant(true)).disabled(true)
        RadioButton("Remember me", isSelected: .constant(true)).type(.check).radioStyle(.inner).gap(.medium)
    }
    .padding()
}
