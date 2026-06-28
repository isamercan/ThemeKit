//
//  RadioGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A labelled, single-select group composed from the RadioButton atom.
/// Selection state is owned by the caller (single optional binding).
public struct RadioGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let infoMessages: [InfoMessage]
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let isOptionEnabled: ((Option) -> Bool)?
    private let label: (Option) -> String
    private var accessibilityID: String? = nil

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Option?>,
        infoMessages: [InfoMessage] = [],
        isOptionEnabled: ((Option) -> Bool)? = nil,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.infoMessages = infoMessages
        self.isOptionEnabled = isOptionEnabled
        self.label = label
    }

    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    private var titleColor: Color {
        switch infoMessages.dominantKind {
        case .error: return theme.foreground(.systemcolorsFgError)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        default: return theme.text(.textPrimary)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(titleColor)
            }
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let enabled = optionEnabled(option)
                Button {
                    selection = option
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        RadioButton(isSelected: .constant(selection == option))
                        Text(label(option))
                            .textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
                .a11y("option.\(index)", in: accessibilityID)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(selection == option ? .isSelected : [])
            }
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }
}

/// Fill style of a `RadioButtonGroup` (Ant `Radio.Group optionType="button"`).
public enum RadioGroupButtonStyle { case solid, outline }

/// A connected, segmented button-style single-select radio group — a distinct
/// API from the stacked `RadioGroup` and the enclosed `SegmentedControl`.
public struct RadioButtonGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let options: [Option]
    @Binding private var selection: Option?
    private let style: RadioGroupButtonStyle
    private let expandsHorizontally: Bool
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let isOptionEnabled: ((Option) -> Bool)?
    private let label: (Option) -> String
    private var accessibilityID: String? = nil

    public init(
        options: [Option],
        selection: Binding<Option?>,
        style: RadioGroupButtonStyle = .solid,
        expandsHorizontally: Bool = false,
        isOptionEnabled: ((Option) -> Bool)? = nil,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.style = style
        self.expandsHorizontally = expandsHorizontally
        self.isOptionEnabled = isOptionEnabled
        self.label = label
    }

    private var radius: CGFloat { Theme.RadiusKey.sm.value }
    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let isSelected = selection == option
                let enabled = optionEnabled(option)
                Button { selection = option } label: {
                    Text(label(option))
                        .textStyle(isSelected ? .labelBase700 : .labelBase600)
                        .foregroundStyle(foreground(isSelected))
                        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .background(background(isSelected))
                        .overlay(alignment: .leading) {
                            if index > 0 {
                                Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(!enabled)
                .opacity(enabled ? 1 : 0.4)
                .a11y("option.\(index)", in: accessibilityID)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(theme.border(style == .outline ? .borderHero : .borderPrimary), lineWidth: 1)
        )
    }

    private func foreground(_ isSelected: Bool) -> Color {
        guard isSelected else { return theme.text(.textSecondary) }
        switch style {
        case .solid: return theme.foreground(.fgSecondary)
        case .outline: return theme.text(.textHero)
        }
    }

    private func background(_ isSelected: Bool) -> Color {
        guard isSelected else { return theme.background(.bgWhite) }
        switch style {
        case .solid: return theme.background(.bgHero)
        case .outline: return theme.background(.bgHero).opacity(0.1)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var sel: String? = "Economy"
        @State var seg: String? = "Gün"
        var body: some View {
            VStack(spacing: 24) {
                RadioGroup(title: "Class", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                RadioButtonGroup(options: ["Gün", "Hafta", "Ay"], selection: $seg, style: .solid) { $0 }
                RadioButtonGroup(options: ["Gün", "Hafta", "Ay"], selection: $seg, style: .outline, expandsHorizontally: true) { $0 }
            }
            .padding()
        }
    }
    return Demo()
}

public extension RadioGroup {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
