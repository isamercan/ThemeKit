//
//  RadioButton.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Figma "Control Items" → Radioboxes. Sizes Small (20) / Medium (24);
//  states selected / disabled. Colors from theme tokens.
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

public struct RadioButton: View {
    @Binding private var isSelected: Bool
    private let label: String?
    private let size: ControlSize
    private let type: RadioButtonType
    private let style: RadioButtonStyle
    private let padding: RadioButtonPadding
    private let backgroundColor: Color?
    private let verticalAlignment: VerticalAlignment
    private let infoMessages: [InfoMessage]
    private let isEnabled: Bool
    private let accessibilityID: String?

    public init(
        _ label: String? = nil,
        isSelected: Binding<Bool>,
        size: ControlSize = .medium,
        type: RadioButtonType = .select,
        style: RadioButtonStyle = .plain,
        padding: RadioButtonPadding = .small,
        backgroundColor: Color? = nil,
        verticalAlignment: VerticalAlignment = .center,
        infoMessages: [InfoMessage] = [],
        isEnabled: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.label = label
        self._isSelected = isSelected
        self.size = size
        self.type = type
        self.style = style
        self.padding = padding
        self.backgroundColor = backgroundColor
        self.verticalAlignment = verticalAlignment
        self.infoMessages = infoMessages
        self.isEnabled = isEnabled
        self.accessibilityID = accessibilityID
    }

    private var dominant: InfoMessage.Kind? { infoMessages.dominantKind }
    private var filled: Bool { isSelected && type == .check && style == .plain }
    private var fillColor: Color { backgroundColor ?? Theme.shared.background(isEnabled ? .bgHero : .bgSecondary) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Button {
                if type == .check { isSelected.toggle() } else { isSelected = true }
            } label: {
                HStack(alignment: verticalAlignment, spacing: padding.value) {
                    Circle()
                        .fill(filled ? fillColor : .clear)
                        .overlay(Circle().strokeBorder(stroke, lineWidth: 1.5))
                        .frame(width: size.side, height: size.side)
                        .overlay(indicator)
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
            .a11y(A11yElement.Control.radio, in: accessibilityID)
            .accessibilityLabel(label ?? "")
            .accessibilityValue(isSelected ? String(globalUIComponents: "selected") : String(globalUIComponents: "not selected"))
            .accessibilityAddTraits(isSelected ? .isSelected : [])

            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    private var stroke: Color {
        if !isEnabled { return Theme.shared.border(.borderPrimary) }
        if dominant == .error { return Theme.shared.border(.systemcolorsBorderError) }
        if dominant == .warning { return Theme.shared.border(.systemcolorsBorderWarning) }
        return (isSelected) ? Theme.shared.border(.borderHero) : Theme.shared.border(.borderPrimary)
    }

    @ViewBuilder
    private var indicator: some View {
        if isSelected {
            switch (type, style) {
            case (.select, _):
                Circle().fill(fillColor).frame(width: size.side * 0.5, height: size.side * 0.5)
            case (.check, .plain):
                Image(systemName: "checkmark")
                    .font(.system(size: size.side * 0.55, weight: .bold))
                    .foregroundStyle(Theme.shared.foreground(.fgSecondary))
            case (.check, .inner):
                ZStack {
                    Circle().fill(Theme.shared.background(.bgWhite))
                    Circle().fill(fillColor).padding(size.side * 0.18)
                }
                .frame(width: size.side * 0.74, height: size.side * 0.74)
            }
        }
    }
}

public extension RadioButton {
    /// Tag-based selection: binds to a shared `selection`, selected when it
    /// equals `tag`. Mirrors the reference's `RadioButton(tag:selection:)`.
    init<V: Hashable>(
        tag: V,
        selection: Binding<V?>,
        size: ControlSize = .medium,
        type: RadioButtonType = .select,
        style: RadioButtonStyle = .plain,
        padding: RadioButtonPadding = .small,
        backgroundColor: Color? = nil,
        infoMessages: [InfoMessage] = [],
        isEnabled: Bool = true,
        accessibilityID: String? = nil
    ) {
        self.init(
            isSelected: Binding(
                get: { selection.wrappedValue == tag },
                set: { newValue in selection.wrappedValue = newValue ? tag : (type == .check ? nil : tag) }
            ),
            size: size,
            type: type,
            style: style,
            padding: padding,
            backgroundColor: backgroundColor,
            infoMessages: infoMessages,
            isEnabled: isEnabled,
            accessibilityID: accessibilityID
        )
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        RadioButton(isSelected: .constant(false))
        RadioButton(isSelected: .constant(true))
        RadioButton(isSelected: .constant(true), size: .small)
        RadioButton(isSelected: .constant(true), isEnabled: false)
    }
    .padding()
}
