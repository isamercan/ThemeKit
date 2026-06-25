//
//  RadioGroup.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A labelled, single-select group composed from the RadioButton atom.
//  Selection state is owned by the caller (single optional binding).
//

import SwiftUI

public struct RadioGroup<Option: Hashable>: View {
    private let title: String?
    private let options: [Option]
    @Binding private var selection: Option?
    private let infoMessages: [InfoMessage]
    private let label: (Option) -> String
    private let accessibilityID: String?

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Option?>,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.infoMessages = infoMessages
        self.accessibilityID = accessibilityID
        self.label = label
    }

    private var titleColor: Color {
        switch infoMessages.dominantKind {
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        default: return Theme.shared.text(.textPrimary)
        }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(titleColor)
            }
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                Button {
                    selection = option
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        RadioButton(isSelected: .constant(selection == option))
                        Text(label(option))
                            .textStyle(.bodyBase400)
                            .foregroundStyle(Theme.shared.text(.textPrimary))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
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
    private let options: [Option]
    @Binding private var selection: Option?
    private let style: RadioGroupButtonStyle
    private let expandsHorizontally: Bool
    private let label: (Option) -> String
    private let accessibilityID: String?

    public init(
        options: [Option],
        selection: Binding<Option?>,
        style: RadioGroupButtonStyle = .solid,
        expandsHorizontally: Bool = false,
        accessibilityID: String? = nil,
        label: @escaping (Option) -> String
    ) {
        self.options = options
        self._selection = selection
        self.style = style
        self.expandsHorizontally = expandsHorizontally
        self.accessibilityID = accessibilityID
        self.label = label
    }

    private var radius: CGFloat { Theme.RadiusKey.sm.value }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let isSelected = selection == option
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
                                Rectangle().fill(Theme.shared.border(.borderPrimary)).frame(width: 1)
                            }
                        }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .a11y("option.\(index)", in: accessibilityID)
                .accessibilityLabel(label(option))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(Theme.shared.border(style == .outline ? .borderHero : .borderPrimary), lineWidth: 1)
        )
    }

    private func foreground(_ isSelected: Bool) -> Color {
        guard isSelected else { return Theme.shared.text(.textSecondary) }
        switch style {
        case .solid: return Theme.shared.foreground(.fgSecondary)
        case .outline: return Theme.shared.text(.textHero)
        }
    }

    private func background(_ isSelected: Bool) -> Color {
        guard isSelected else { return Theme.shared.background(.bgWhite) }
        switch style {
        case .solid: return Theme.shared.background(.bgHero)
        case .outline: return Theme.shared.background(.bgHero).opacity(0.1)
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
