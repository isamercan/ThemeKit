//
//  MultiSelect.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Multiple / tags select with optional search (Ant Select mode="multiple").
//  Selected options render as removable tag chips; the dropdown is a token-bound
//  panel with a search field and checkable rows. The single-value `Select`
//  remains for the simple case.
//

import SwiftUI

public struct MultiSelect<Option: Hashable>: View {
    private let label: String?
    private let options: [Option]
    @Binding private var selection: Set<Option>
    private let optionTitle: (Option) -> String
    private let placeholder: String
    private let searchable: Bool
    private let allowClear: Bool
    private let maxTagCount: Int?
    private let infoMessages: [InfoMessage]
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let isLoading: Bool
    private let isOptionEnabled: ((Option) -> Bool)?

    @State private var open = false
    @State private var query = ""

    public init(
        label: String? = nil,
        options: [Option],
        selection: Binding<Set<Option>>,
        placeholder: String = String(themeKit: "Select"),
        searchable: Bool = true,
        allowClear: Bool = true,
        maxTagCount: Int? = nil,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        isOptionEnabled: ((Option) -> Bool)? = nil,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.options = options
        self._selection = selection
        self.placeholder = placeholder
        self.searchable = searchable
        self.allowClear = allowClear
        self.maxTagCount = maxTagCount
        self.infoMessages = infoMessages
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isOptionEnabled = isOptionEnabled
        self.optionTitle = optionTitle
    }

    private var fieldBorder: Color {
        if open { return Theme.shared.border(.borderHero) }
        switch infoMessages.dominantKind {
        case .error: return Theme.shared.border(.systemcolorsBorderError)
        case .warning: return Theme.shared.border(.systemcolorsBorderWarning)
        default: return Theme.shared.border(.borderPrimary)
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
                        .foregroundStyle(Theme.shared.text(.textTertiary))
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
                        Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                }
                if isLoading {
                    Spinner(size: IconSize.sm.value, lineWidth: 2)
                } else {
                    Icon(systemName: open ? "chevron.up" : "chevron.down", size: .sm, color: Theme.shared.text(.textTertiary))
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .frame(minHeight: 56)
            .frame(maxWidth: .infinity)
            .background(Theme.shared.background(isEnabled ? .bgWhite : .bgSecondaryLight),
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
                    Icon(systemName: "magnifyingglass", size: .sm, color: Theme.shared.text(.textTertiary))
                    TextField("Ara", text: $query)
                        .textStyle(.bodyBase400)
                        .tint(Theme.shared.foreground(.fgHero))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(44)
                DividerView(size: .small)
            }
            if isLoading {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Spinner(size: IconSize.sm.value, lineWidth: 2)
                    Text(String(themeKit: "Searching…")).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textTertiary))
                    Spacer()
                }
                .padding(Theme.SpacingKey.md.value)
            } else if filtered.isEmpty {
                Text(String(themeKit: "No results"))
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
                    .padding(Theme.SpacingKey.md.value)
            } else {
                ForEach(filtered, id: \.self) { opt in
                    let enabled = optionEnabled(opt)
                    Button { toggle(opt) } label: {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Checkbox(isChecked: .constant(selection.contains(opt)), size: .small)
                                .allowsHitTesting(false)
                            Text(optionTitle(opt))
                                .textStyle(.bodyBase400)
                                .foregroundStyle(Theme.shared.text(.textPrimary))
                            Spacer()
                        }
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .padding(.vertical, Theme.SpacingKey.sm.value)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(RowPressStyle())
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
                    if opt != filtered.last { DividerView(size: .small).padding(.leading, Theme.SpacingKey.md.value) }
                }
            }
        }
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
        )
        .themeShadow(.soft)
    }

    private func toggle(_ opt: Option) {
        if selection.contains(opt) { selection.remove(opt) } else { selection.insert(opt) }
    }
}

#Preview {
    struct Demo: View {
        @State var picks: Set<String> = ["İstanbul"]
        let cities = ["İstanbul", "Ankara", "İzmir", "Antalya", "Bursa", "Adana"]
        var body: some View {
            MultiSelect(label: "Cities", options: cities, selection: $picks) { $0 }
                .padding()
        }
    }
    return Demo()
}
