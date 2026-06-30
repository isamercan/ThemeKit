//
//  CheckboxGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A labelled, multi-select group composed from the Checkbox atom.
/// Selection state is owned by the caller (single Set binding — no per-row state).
public struct CheckboxGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let infoMessages: [InfoMessage]
    private let selectAllTitle: String?
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let isOptionEnabled: ((Option) -> Bool)?
    private let label: (Option) -> String
    private var accessibilityID: String? = nil

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        infoMessages: [InfoMessage] = [],
        selectAllTitle: String? = nil,
        isOptionEnabled: ((Option) -> Bool)? = nil,
        label: @escaping (Option) -> String
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.infoMessages = infoMessages
        self.selectAllTitle = selectAllTitle
        self.isOptionEnabled = isOptionEnabled
        self.label = label
    }

    private var titleColor: Color {
        switch infoMessages.dominantKind {
        case .error: return theme.foreground(.systemcolorsFgError)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        default: return theme.text(.textPrimary)
        }
    }

    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    /// Options that the "select all" master is allowed to toggle.
    private var selectableOptions: [Option] { options.filter { optionEnabled($0) } }
    private var selectedSelectable: Int { selectableOptions.filter { selection.contains($0) }.count }
    private var allSelected: Bool { !selectableOptions.isEmpty && selectedSelectable == selectableOptions.count }
    private var someSelected: Bool { selectedSelectable > 0 && !allSelected }

    private func toggleAll() {
        if allSelected { selectableOptions.forEach { selection.remove($0) } }
        else { selectableOptions.forEach { selection.insert($0) } }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(titleColor)
            }
            if let selectAllTitle {
                Button(action: toggleAll) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Checkbox(isChecked: .constant(allSelected)).indeterminate(someSelected)
                        Text(selectAllTitle)
                            .textStyle(.labelBase600)
                            .foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(selectableOptions.isEmpty)
                .opacity(isEnabled ? 1 : 0.4)
                .accessibilityLabel(selectAllTitle)
                .accessibilityAddTraits(allSelected ? .isSelected : [])
                DividerView().size(.small)
            }
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                let isOn = selection.contains(option)
                let enabled = optionEnabled(option)
                Button {
                    if isOn { selection.remove(option) } else { selection.insert(option) }
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Checkbox(isChecked: .constant(isOn))
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
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var sel: Set<String> = ["Wifi"]
        var body: some View {
            CheckboxGroup(title: "Amenities", options: ["Wifi", "Pool", "Parking", "Breakfast"], selection: $sel) { $0 }
                .padding()
        }
    }
    return Demo()
}

public extension CheckboxGroup {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
