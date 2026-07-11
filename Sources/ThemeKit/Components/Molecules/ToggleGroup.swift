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
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var description: (Option) -> String? = { _ in nil }
    private var axis: Axis = .vertical
    private var accent: SemanticColor?
    private var isOptionEnabled: ((Option) -> Bool)?
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

    private func optionEnabled(_ option: Option) -> Bool { isEnabled && (isOptionEnabled?(option) ?? true) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let title {
                Text(title).textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
            }
            optionsContainer
        }
    }

    /// Lays the rows out along `axis` (HStack/VStack mirror for RTL automatically).
    @ViewBuilder private var optionsContainer: some View {
        switch axis {
        case .horizontal:
            HStack(alignment: .top, spacing: Theme.SpacingKey.md.value) { optionRows }
        case .vertical:
            VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) { optionRows }
        }
    }

    private var optionRows: some View {
        ForEach(Array(options.enumerated()), id: \.element) { index, option in
            let enabled = optionEnabled(option)
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(label(option))
                        .textStyle(.labelBase600)
                        .foregroundStyle(enabled ? theme.text(.textPrimary) : theme.text(.textDisabled))
                    if let description = description(option) {
                        Text(description)
                            .textStyle(.bodySm400)
                            .foregroundStyle(enabled ? theme.text(.textSecondary) : theme.text(.textDisabled))
                    }
                }
                // Vertical rows push the switch to the trailing edge; in a
                // horizontal group each label+switch pair hugs instead.
                if axis == .vertical {
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                }
                ThemeToggle(isOn: Binding(
                    get: { selection.contains(option) },
                    set: { isOn in if isOn { selection.insert(option) } else { selection.remove(option) } }
                ))
                .accent(accent)
                .disabled(!enabled)   // native — R3
                .a11y("option.\(index)", in: accessibilityID)
                .accessibilityLabel(label(option))
                .accessibilityValue(selection.contains(option) ? String(themeKit: "on") : String(themeKit: "off"))
                .accessibilityAddTraits(selection.contains(option) ? .isSelected : [])
            }
        }
    }
}

#Preview {
    @Previewable @State var sel: Set<String> = ["push"]
    @Previewable @State var horizontal: Set<String> = ["wifi"]
    PreviewMatrix("ToggleGroup") {
        PreviewCase("Descriptions") {
            ToggleGroup(
                title: "Notifications",
                options: ["push", "email", "sms"],
                selection: $sel,
                label: { ["push": "Push", "email": "Email", "sms": "SMS"][$0] ?? $0 }
            )
            .optionDescription { _ in "Lorem ipsum supporting text." }
        }
        // E9 — accent + per-option enablement.
        PreviewCase("Accent + per-option enable") {
            ToggleGroup(
                title: "Privacy",
                options: ["analytics", "ads", "tracking"],
                selection: $sel,
                label: { $0.capitalized }
            )
            .accent(.success)
            .optionEnabled { $0 != "tracking" }
        }
        // E9 — horizontal axis: each label + switch pair hugs.
        PreviewCase("Horizontal") {
            ToggleGroup(
                title: "Amenities",
                options: ["wifi", "pool"],
                selection: $horizontal,
                label: { $0.capitalized }
            )
            .axis(.horizontal)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ToggleGroup {
    /// Supporting text rendered under each row's label (return nil for none).
    func optionDescription(_ description: @escaping (Option) -> String?) -> Self { copy { $0.description = description } }

    /// Per-option enablement predicate — disabled rows dim and their switch
    /// stops responding (nil enables every option; the kit-standard group
    /// idiom, cf. `CheckboxGroup.optionEnabled`).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Semantic track tint forwarded to each row's `ThemeToggle`; `nil`
    /// (default) keeps the stock hero track.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Lay the rows out along `axis` (vertical default; HStack/VStack mirror
    /// for RTL automatically — cf. `RadioGroup.axis`).
    func axis(_ a: Axis) -> Self { copy { $0.axis = a } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
