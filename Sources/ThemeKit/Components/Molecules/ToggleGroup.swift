//
//  ToggleGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Rows of labelled switches with optional supporting text. Multi-state
/// owned by the caller (single Set binding).
public struct ToggleGroup<Option: Hashable>: View {
    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let label: (Option) -> String
    private let description: (Option) -> String?
    private let accessibilityID: String?

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        accessibilityID: String? = nil,
        label: @escaping (Option) -> String,
        description: @escaping (Option) -> String? = { _ in nil }
    ) {
        self.title = title
        self.options = options
        self._selection = selection
        self.accessibilityID = accessibilityID
        self.label = label
        self.description = description
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(Theme.shared.text(.textPrimary))
            }
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(option))
                            .textStyle(.labelBase600)
                            .foregroundStyle(Theme.shared.text(.textPrimary))
                        if let description = description(option) {
                            Text(description)
                                .textStyle(.bodySm400)
                                .foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                    }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    ThemeToggle(isOn: Binding(
                        get: { selection.contains(option) },
                        set: { isOn in if isOn { selection.insert(option) } else { selection.remove(option) } }
                    ))
                    .a11y("option.\(index)", in: accessibilityID)
                    .accessibilityLabel(label(option))
                    .accessibilityValue(selection.contains(option) ? String(themeKit: "on") : String(themeKit: "off"))
                    .accessibilityAddTraits(selection.contains(option) ? .isSelected : [])
                }
            }
        }
    }
}

#Preview {
    struct Demo: View {
        @State var sel: Set<String> = ["push"]
        var body: some View {
            ToggleGroup(
                title: "Notifications",
                options: ["push", "email", "sms"],
                selection: $sel,
                label: { ["push": "Push", "email": "Email", "sms": "SMS"][$0] ?? $0 },
                description: { _ in "Lorem ipsum supporting text." }
            )
            .padding()
        }
    }
    return Demo()
}
