//
//  MultiSelect.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Multiple / tags select with optional search (Ant Select mode="multiple").
/// Selected options render as removable tag chips; the dropdown is a token-bound
/// panel with a search field and checkable rows. The single-value `Select`
/// remains for the simple case.
public struct MultiSelect<Option: Hashable>: View {
    @Environment(\.theme) private var theme

    private let label: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let optionTitle: (Option) -> String

    // Appearance/config — mutated only through the modifiers below (R2).
    // Search + clear are on by default, matching a tag picker.
    private var placeholder: String = String(themeKit: "Select")
    private var infoMessages: [InfoMessage] = []
    private var isOptionEnabled: ((Option) -> Bool)? = nil
    private var searchable: Bool = true
    private var allowClear: Bool = true
    private var maxTagCount: Int? = nil
    private var isLoading: Bool = false
    private var accessibilityID: String? = nil
    @Environment(\.isEnabled) private var isEnabled

    @State private var open = false
    @State private var query = ""

    public init(   // R1
        _ label: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.optionTitle = optionTitle
    }

    private var fieldBorder: Color {
        if open { return theme.border(.borderHero) }
        switch infoMessages.dominantKind {
        case .error: return theme.border(.systemcolorsBorderError)
        case .warning: return theme.border(.systemcolorsBorderWarning)
        default: return theme.border(.borderPrimary)
        }
    }

    private var selectedOptions: [Option] { options.filter { selection.contains($0) } }
    private var visibleTags: [Option] { Self.tagLayout(selected: selectedOptions, maxTagCount: maxTagCount).visible }
    private var overflowCount: Int { Self.tagLayout(selected: selectedOptions, maxTagCount: maxTagCount).overflow }
    private func optionEnabled(_ option: Option) -> Bool { isOptionEnabled?(option) ?? true }

    /// Splits selected options into the chips to render and the "+N" overflow count.
    static func tagLayout(selected: [Option], maxTagCount: Int?) -> (visible: [Option], overflow: Int) {
        guard let maxTagCount, maxTagCount >= 0, selected.count > maxTagCount else { return (selected, 0) }
        return (Array(selected.prefix(maxTagCount)), selected.count - maxTagCount)
    }

    private var filtered: [Option] {
        guard searchable, !query.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(query) }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }
            field
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
            if open { panel }
        }
        .animation(Motion.fast.animation, value: open)
    }

    private var field: some View {
        Button {
            if isEnabled { open.toggle() }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if selection.isEmpty {
                    Text(placeholder)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textTertiary))
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            ForEach(visibleTags, id: \.self) { opt in
                                Tag(optionTitle(opt), onRemove: isEnabled ? { selection.remove(opt) } : nil)
                            }
                            if overflowCount > 0 {
                                Tag("+\(overflowCount)")
                            }
                        }
                    }
                }
                Spacer(minLength: 0)
                if allowClear && !selection.isEmpty && isEnabled && !isLoading {
                    Button { selection.removeAll() } label: {
                        Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                }
                if isLoading {
                    Spinner().size(IconSize.sm.value).lineWidth(2)
                } else {
                    Icon(systemName: open ? "chevron.up" : "chevron.down").size(.sm).color(theme.text(.textTertiary))
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity)
            .background(theme.background(isEnabled ? .bgWhite : .bgSecondaryLight),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(fieldBorder, lineWidth: open ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .a11y(A11yElement.Select.trigger, in: accessibilityID)
        .accessibilityLabel(label ?? "")
        .accessibilityValue(String(themeKit: "\(selection.count) selected"))
    }

    private var panel: some View {
        VStack(spacing: 0) {
            if searchable {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Icon(systemName: "magnifyingglass").size(.sm).color(theme.text(.textTertiary))
                    TextField("Search", text: $query)
                        .textStyle(.bodyBase400)
                        .tint(theme.foreground(.fgHero))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(44)
                DividerView().size(.small)
            }
            if isLoading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Spinner().size(IconSize.sm.value).lineWidth(2)
                    Text(String(themeKit: "Searching…")).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    Spacer()
                }
                .padding(Theme.SpacingKey.md.value)
            } else if filtered.isEmpty {
                Text(String(themeKit: "No results"))
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .padding(Theme.SpacingKey.md.value)
            } else {
                ForEach(filtered, id: \.self) { opt in
                    let enabled = optionEnabled(opt)
                    Button { toggle(opt) } label: {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Checkbox(isChecked: .constant(selection.contains(opt)))
                                .controlSize(.small)
                                .allowsHitTesting(false)
                            Text(optionTitle(opt))
                                .textStyle(.bodyBase400)
                                .foregroundStyle(theme.text(.textPrimary))
                            Spacer()
                        }
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
                    if opt != filtered.last { DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value) }
                }
            }
        }
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
        )
        .themeShadow(.soft)
    }

    private func toggle(_ opt: Option) {
        if selection.contains(opt) { selection.remove(opt) } else { selection.insert(opt) }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension MultiSelect {
    /// Placeholder shown while nothing is selected.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Per-option enable predicate; disabled rows are shown greyed and unselectable.
    func optionEnabled(_ predicate: ((Option) -> Bool)?) -> Self { copy { $0.isOptionEnabled = predicate } }

    /// Whether the dropdown shows a search field (default true).
    func searchable(_ on: Bool = true) -> Self { copy { $0.searchable = on } }

    /// Whether a clear-all button is offered (default true).
    func clearable(_ on: Bool = true) -> Self { copy { $0.allowClear = on } }

    /// Caps the visible selected-tag chips, collapsing the rest into a "+N" tag.
    func maxTags(_ count: Int?) -> Self { copy { $0.maxTagCount = count } }

    /// Shows a loading spinner in place of the chevron (async option fetch).
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var picks: Set<String> = ["Istanbul"]
        let cities = ["Istanbul", "Ankara", "Izmir", "Antalya", "Bursa", "Adana"]
        var body: some View {
            MultiSelect("Cities", options: cities, selection: $picks) { $0 }
                .padding()
        }
    }
    return Demo()
}
