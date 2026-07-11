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
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var infoMessages: [InfoMessage] = []
    private var isOptionEnabled: ((Option) -> Bool)?
    private var description: (Option) -> String? = { _ in nil }
    private var groupDescription: String?                     // E5
    private var accent: SemanticColor?
    private var axis: Axis = .vertical
    private var controlPlacement: HorizontalEdge = .leading   // A4 — forwarded to rows
    private var accessibilityID: String? = nil
    @Environment(\.isReadOnly) private var isReadOnly         // E1 — rows own the tap

    public init(
        title: String? = nil,
        options: [Option],
        selection: Binding<Option?>,
        label: @escaping (Option) -> String
    ) {   // R1 — content + data + binding + required label closure
        self.title = title
        self.options = options
        self._selection = selection
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
            if let groupDescription {
                HelperText(groupDescription)   // E5 — group-level supporting text
            }
            optionsContainer
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
    }

    /// Lays the option rows out along `axis` (HStack/VStack mirror for RTL automatically).
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
            let description = description(option)
            let radio = RadioButton(isSelected: .constant(selection == option)).accent(accent)
            let labelBlock = VStack(alignment: .leading, spacing: 2) {
                Text(label(option))
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                if let description {
                    Text(description)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Button {
                guard !isReadOnly else { return }   // E1 — VoiceOver activation is not hit-tested
                selection = option
            } label: {
                // Top-align the radio against the label block when supporting text is present.
                HStack(alignment: description == nil ? .center : .top, spacing: Theme.SpacingKey.sm.value) {
                    if controlPlacement == .leading {   // A4 — group-level placement
                        radio
                        labelBlock
                        if axis == .vertical { Spacer() }
                    } else {
                        labelBlock
                        if axis == .vertical { Spacer() }
                        radio
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(!enabled)
            .allowsHitTesting(!isReadOnly)   // E1 — normal chrome, selection blocked
            .opacity(enabled ? 1 : 0.4)
            .a11y("option.\(index)", in: accessibilityID)
            .accessibilityLabel(label(option))
            .accessibilityAddTraits(selection == option ? .isSelected : [])
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
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    private let label: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var style: RadioGroupButtonStyle = .solid
    private var expandsHorizontally: Bool = false
    private var isOptionEnabled: ((Option) -> Bool)?
    private var accessibilityID: String? = nil

    public init(
        options: [Option],
        selection: Binding<Option?>,
        label: @escaping (Option) -> String
    ) {   // R1 — data + binding + required label closure
        self.options = options
        self._selection = selection
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
        @State var seg: String? = "Day"
        var body: some View {
            VStack(spacing: 24) {
                RadioGroup(title: "Class", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                RadioGroup(title: "Class + descriptions", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .optionDescription {
                        ["Economy": "Standard seat and cabin baggage.",
                         "Business": "Priority boarding, lounge access and flat bed."][$0]
                    }
                    .accent(.success)
                RadioGroup(title: "Horizontal", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .axis(.horizontal)
                RadioGroup(title: "Trailing radios", options: ["Economy", "Business", "First"], selection: $sel) { $0 }
                    .controlPlacement(.trailing)                                        // A4
                    .description("Fares are per passenger, taxes included.")            // E5
                RadioButtonGroup(options: ["Day", "Week", "Month"], selection: $seg) { $0 }
                RadioButtonGroup(options: ["Day", "Week", "Month"], selection: $seg) { $0 }
                    .groupStyle(.outline).fullWidth()
            }
            .padding()
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RadioGroup {
    /// Validation / info messages rendered under the group (drives the title color).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Per-option enablement predicate (nil enables every option).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Supporting text rendered under each row's label (return nil for none).
    func optionDescription(_ description: @escaping (Option) -> String?) -> Self { copy { $0.description = description } }

    /// Group-level supporting text rendered under the title via `HelperText`
    /// (Ant/HeroUI group `description`; E5). Distinct from `optionDescription`.
    func description(_ text: String?) -> Self { copy { $0.groupDescription = text } }

    /// Which side of each row's label the radio sits on: `.leading` (default)
    /// or `.trailing`, forwarded to every option row. RTL-safe —
    /// `HorizontalEdge` follows the layout direction. (A4.)
    func controlPlacement(_ edge: HorizontalEdge) -> Self { copy { $0.controlPlacement = edge } }

    /// Semantic tint forwarded to every radio's selected fill/border; `nil`
    /// (default) uses the hero tokens. (HeroUI item variant / daisyUI `radio-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    /// Layout axis of the option rows: `.vertical` (default) or `.horizontal`.
    /// (HeroUI RadioGroup `orientation`.)
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

public extension RadioButtonGroup {
    /// Fill style of the group: `.solid` or `.outline`.
    func groupStyle(_ style: RadioGroupButtonStyle) -> Self { copy { $0.style = style } }

    /// Expands the group to fill the available width, sharing it across segments.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.expandsHorizontally = on } }

    /// Per-option enablement predicate (nil enables every option).
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
