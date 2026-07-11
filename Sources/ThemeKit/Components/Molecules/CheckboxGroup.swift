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
    @Environment(\.fieldDefaults) private var fieldDefaults   // F4 — requiredIndicator default

    private let title: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var infoMessages: [InfoMessage] = []
    private var selectAllTitle: String?
    private var isOptionEnabled: ((Option) -> Bool)?
    private var groupDescription: String?                     // E5
    private var axis: Axis = .vertical                        // A6
    private var controlPlacement: HorizontalEdge = .leading   // A5 — forwarded to rows
    /// `.required()` — group-level asterisk after the title (E2).
    private var isRequired = false
    private var accessibilityID: String? = nil
    @Environment(\.isReadOnly) private var isReadOnly         // E1 — rows own the tap

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
                // E2 — group-level required mark: the group has no `InputLabel`,
                // so render the same error-token asterisk manually (the
                // MultiLineTextInput treatment), honoring `FieldDefaults.requiredIndicator`.
                HStack(spacing: 2) {
                    Text(title).foregroundStyle(titleColor)
                    if isRequired && (fieldDefaults.requiredIndicator ?? true) {
                        Text(verbatim: "*")
                            .foregroundStyle(theme.foreground(.systemcolorsFgError))
                            .accessibilityHidden(true)   // spoken via the title's label suffix
                    }
                }
                .textStyle(.labelMd600)
                .accessibilityLabel(isRequired ? title + ", " + String(themeKit: "required") : title)
            }
            if let groupDescription {
                HelperText(groupDescription)   // E5 — group-level supporting text
            }
            if let selectAllTitle {
                Button {
                    guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                    toggleAll()
                } label: {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        if controlPlacement == .leading {   // A5 — group-level placement
                            Checkbox(isChecked: .constant(allSelected)).indeterminate(someSelected)
                            selectAllLabel(selectAllTitle)
                            Spacer()
                        } else {
                            selectAllLabel(selectAllTitle)
                            Spacer()
                            Checkbox(isChecked: .constant(allSelected)).indeterminate(someSelected)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(selectableOptions.isEmpty)
                .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, toggling blocked
                .opacity(isEnabled ? 1 : 0.4)
                .accessibilityLabel(selectAllTitle)
                .accessibilityAddTraits(allSelected ? .isSelected : [])
                DividerView().size(.small)
            }
            optionsContainer
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    private func selectAllLabel(_ title: String) -> some View {
        Text(title)
            .textStyle(.labelBase600)
            .foregroundStyle(theme.text(.textPrimary))
    }

    /// Lays the option rows out along `axis` (A6 — HStack/VStack mirror for RTL
    /// automatically; copies RadioGroup's `.axis(_:)` container).
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
            let isOn = selection.contains(option)
            let enabled = optionEnabled(option)
            let box = Checkbox(isChecked: .constant(isOn))
            let rowLabel = Text(label(option))
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
            Button {
                guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                if isOn { selection.remove(option) } else { selection.insert(option) }
            } label: {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if controlPlacement == .leading {   // A5 — group-level placement
                        box
                        rowLabel
                        if axis == .vertical { Spacer() }
                    } else {
                        rowLabel
                        if axis == .vertical { Spacer() }
                        box
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, toggling blocked
            .opacity(enabled ? 1 : 0.4)
            .a11y("option.\(index)", in: accessibilityID)
            .accessibilityLabel(label(option))
            .accessibilityAddTraits(isOn ? .isSelected : [])
        }
    }
}

#Preview {
    PreviewMatrix("CheckboxGroup") {
        PreviewCase("Vertical (default)") {
            CheckboxGroup(title: "Amenities", options: ["Wifi", "Pool", "Parking", "Breakfast"], selection: .constant(["Wifi"])) { $0 }
        }
        PreviewCase("Horizontal") {
            CheckboxGroup(title: "Horizontal", options: ["Wifi", "Pool", "Parking"], selection: .constant(["Wifi"])) { $0 }
                .axis(.horizontal)                                                  // A6
        }
        PreviewCase("Trailing boxes + select all + description") {
            CheckboxGroup(title: "Trailing boxes", options: ["Wifi", "Pool", "Parking"], selection: .constant(["Wifi"])) { $0 }
                .controlPlacement(.trailing)                                        // A5
                .selectAll("All amenities")
                .description("Filters apply to all room types.")                    // E5
        }
        PreviewCase("Required") {
            CheckboxGroup(title: "Required group", options: ["Wifi", "Pool"], selection: .constant(["Wifi"])) { $0 }
                .required()                                                         // E2
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension CheckboxGroup {
    /// Validation / info messages rendered under the group (drives the title color).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Adds a "select all" master row with the given title (nil hides it).
    func selectAll(_ title: String?) -> Self { copy { $0.selectAllTitle = title } }

    /// Group-level supporting text rendered under the title via `HelperText`
    /// (Ant/HeroUI group `description`; E5).
    func description(_ text: String?) -> Self { copy { $0.groupDescription = text } }

    /// Marks the whole group required: an error-token asterisk after the title
    /// (honoring `FieldDefaults.requiredIndicator`) and ", required" in the
    /// title's a11y label. (E2 — HeroUI `isRequired`, Ant required mark.)
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Layout axis of the option rows: `.vertical` (default) or `.horizontal`.
    /// (Ant `Checkbox.Group` / HeroUI `orientation`; A6.) The "select all"
    /// master row always keeps its own line above the options.
    func axis(_ a: Axis) -> Self { copy { $0.axis = a } }

    /// Which side of each row's label the box sits on: `.leading` (default)
    /// or `.trailing`, forwarded to every option row and the "select all" row.
    /// RTL-safe — `HorizontalEdge` follows the layout direction. (A5.)
    func controlPlacement(_ edge: HorizontalEdge) -> Self { copy { $0.controlPlacement = edge } }

    /// Per-option enablement predicate (nil enables every option).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
