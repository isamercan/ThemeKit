//
//  ToggleGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. Rows of labelled switches with optional supporting text. Multi-state
/// owned by the caller (single Set binding).
public struct ToggleGroup<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var description: (Option) -> String? = { _ in nil }
    private var accessibilityID: String? = nil

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        label: @escaping (Option) -> String
    ) {   // R1 — content + data + binding + required label closure
        self.title = title
        self.options = options
        self._selection = selection
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
            }
            ForEach(Array(options.enumerated()), id: \.element) { index, option in
                HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(label(option))
                            .textStyle(.labelBase600)
                            .foregroundStyle(theme.text(.textPrimary))
                        if let description = description(option) {
                            Text(description)
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary))
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
                label: { ["push": "Push", "email": "Email", "sms": "SMS"][$0] ?? $0 }
            )
            .optionDescription { _ in "Lorem ipsum supporting text." }
            .padding()
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ToggleGroup {
    /// Supporting text rendered under each row's label (return nil for none).
    func optionDescription(_ description: @escaping (Option) -> String?) -> Self { copy { $0.description = description } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
