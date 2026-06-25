//
//  CheckboxGroup.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A labelled, multi-select group composed from the Checkbox atom.
//  Selection state is owned by the caller (single Set binding — no per-row state).
//

import SwiftUI

public struct CheckboxGroup<Option: Hashable>: View {
    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let infoMessages: [InfoMessage]
    private let label: (Option) -> String
    private let accessibilityID: String?

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
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
                let isOn = selection.contains(option)
                Button {
                    if isOn { selection.remove(option) } else { selection.insert(option) }
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Checkbox(isChecked: .constant(isOn))
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
