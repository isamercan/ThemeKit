//
//  Checkbox.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ControlSize {
    case small
    case medium

    /// Square side for checkbox / radio.
    var side: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
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
/// states checked / disabled / indeterminate. Colors from theme tokens.
public struct Checkbox: View {
    @Binding private var isChecked: Bool
    private let label: String?
    private let size: ControlSize
    private let customSize: CGFloat?
    private let type: CheckboxType
    private let isIndeterminate: Bool
    private let alignment: VerticalAlignment
    private let infoMessages: [InfoMessage]
    private let isEnabled: Bool
    private let accessibilityID: String?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(
        _ label: String? = nil,
        isChecked: Binding<Bool>,
        size: ControlSize = .medium,
        customSize: CGFloat? = nil,
        type: CheckboxType = .plain,
        isIndeterminate: Bool = false,
        alignment: VerticalAlignment = .center,
        infoMessages: [InfoMessage] = [],
        isEnabled: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self._isChecked = isChecked
        self.size = size
        self.customSize = customSize
        self.type = type
        self.isIndeterminate = isIndeterminate
        self.alignment = alignment
        self.infoMessages = infoMessages
        self.isEnabled = isEnabled
        self.accessibilityID = accessibilityID
    }

    private var side: CGFloat { customSize ?? size.side }
    private var selected: Bool { isChecked || isIndeterminate }
    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                isChecked.toggle()
            } label: {
                HStack(alignment: alignment, spacing: Theme.SpacingKey.sm.value) {
                    box
                    if let label {
                        Text(label)
                            .textStyle(.bodyBase400)
                            .foregroundStyle(isEnabled ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textDisabled))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!isEnabled)
            .a11y(A11yElement.Control.checkbox, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(isIndeterminate ? String(themeKit: "mixed") : (isChecked ? String(themeKit: "selected") : String(themeKit: "not selected")))
            .accessibilityAddTraits(isChecked ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    private var radius: CGFloat { Theme.RadiusKey.xs.value }

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
            return Theme.shared.background(isEnabled ? .bgHero : .bgSecondary)
        }
    }

    private var stroke: Color {
        if case .customInner = type { return .clear }
        if !isEnabled { return Theme.shared.border(.borderPrimary) }
        if dominant == .error { return Theme.shared.border(.systemcolorsBorderError) }
        if dominant == .warning { return Theme.shared.border(.systemcolorsBorderWarning) }
        return selected ? Theme.shared.border(.borderHero) : Theme.shared.border(.borderPrimary)
    }

    @ViewBuilder
    private var glyph: some View {
        if case .inner = type {
            if selected {
                RoundedRectangle(cornerRadius: max(radius - 2, 1), style: .continuous)
                    .fill(Theme.shared.background(isEnabled ? .bgHero : .bgSecondary))
                    .padding(side * 0.2)
                    .overlay {
                        if isIndeterminate {
                            Image(systemName: "minus")
                                .font(.system(size: side * 0.34, weight: .bold))
                                .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                        }
                    }
            }
        } else if selected {
            Image(systemName: isIndeterminate ? "minus" : "checkmark")
                .font(.system(size: side * 0.6, weight: .bold))
                .foregroundStyle(Theme.shared.foreground(.fgSecondary))
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        Checkbox(isChecked: .constant(false))
        Checkbox(isChecked: .constant(true))
        Checkbox(isChecked: .constant(true), isIndeterminate: true)
        Checkbox(isChecked: .constant(true), size: .small)
        Checkbox(isChecked: .constant(true), isEnabled: false)
    }
    .padding()
}
