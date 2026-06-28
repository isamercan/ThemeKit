//
//  Select.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Single-select dropdown. Two modes: a native `Menu` (with grouped Sections)
//  or a searchable inline panel (`searchable: true`) with a search field +
//  section headers — the reference Select's sectioned + searchable picker.
//

import SwiftUI

/// A single-select dropdown — a native `Menu` by default, or a searchable inline
/// panel with section headers when `searchable` is on.
///
/// ```swift
/// Select("City", options: cities, selection: $city, searchable: true) { $0.name }
/// ```
public struct Select<Option: Hashable>: View {
    public struct Section {
        public let title: String?
        public let options: [Option]
        public init(_ title: String? = nil, _ options: [Option]) { self.title = title; self.options = options }
    }

    private let label: String
    private let sections: [Section]
    @Binding private var selection: Option?
    private let optionTitle: (Option) -> String
    private let placeholder: String
    private let allowClear: Bool
    private let searchable: Bool
    private let size: TextInputSize
    private let infoMessages: [InfoMessage]
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let isLoading: Bool
    private let isOptionEnabled: ((Option) -> Bool)?

    @Environment(\.selectStyle) private var selectStyle

    @State private var open = false
    @State private var query = ""

    public init(
        _ label: String,
        options: [Option],
        selection: Binding<Option?>,
        placeholder: String = "Select",
        allowClear: Bool = false,
        searchable: Bool = false,
        size: TextInputSize = .medium,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        isOptionEnabled: ((Option) -> Bool)? = nil,
        optionTitle: @escaping (Option) -> String
    ) {
        self.init(label, sections: [Section(nil, options)], selection: selection, placeholder: placeholder,
                  allowClear: allowClear, searchable: searchable, size: size, infoMessages: infoMessages,
                  accessibilityID: accessibilityID, isEnabled: isEnabled, isLoading: isLoading,
                  isOptionEnabled: isOptionEnabled, optionTitle: optionTitle)
    }

    public init(
        _ label: String,
        sections: [Section],
        selection: Binding<Option?>,
        placeholder: String = "Select",
        allowClear: Bool = false,
        searchable: Bool = false,
        size: TextInputSize = .medium,
        infoMessages: [InfoMessage] = [],
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        isLoading: Bool = false,
        isOptionEnabled: ((Option) -> Bool)? = nil,
        optionTitle: @escaping (Option) -> String
    ) {
        self.label = label
        self.sections = sections
        self._selection = selection
        self.placeholder = placeholder
        self.allowClear = allowClear
        self.searchable = searchable
        self.size = size
        self.infoMessages = infoMessages
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.isLoading = isLoading
        self.isOptionEnabled = isOptionEnabled
        self.optionTitle = optionTitle
    }

    private var hasValue: Bool { selection != nil }
    private var showsClear: Bool { allowClear && hasValue && isEnabled && !isLoading }
    private func optionEnabled(_ option: Option) -> Bool { isOptionEnabled?(option) ?? true }
    private var hasAnyResults: Bool { sections.contains { !filtered($0.options).isEmpty } }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            ZStack(alignment: .trailing) {
                if searchable {
                    Button { if isEnabled { open.toggle() } } label: { field }
                        .buttonStyle(.plain)
                        .disabled(!isEnabled)
                } else {
                    Menu { menuContent } label: { field }
                        .disabled(!isEnabled)
                }
                clearButton
            }
            .a11y(A11yElement.Select.trigger, in: accessibilityID)
            .accessibilityLabel(label)
            .accessibilityValue(selection.map(optionTitle) ?? "")

            if searchable && open { panel }
            if !infoMessages.isEmpty {
                InfoMessageList(infoMessages).a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        .animation(Motion.fast.animation, value: open)
    }

    // MARK: Trigger field

    private var fieldContent: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ZStack(alignment: .leading) {
                Text(label)
                    .textStyle(hasValue ? .labelSm600 : .bodyBase400)
                    .foregroundStyle(hasValue ? Theme.shared.text(.textHero) : Theme.shared.text(.textTertiary))
                    .offset(y: hasValue ? -11 : 0)
                if let selection {
                    Text(optionTitle(selection))
                        .textStyle(.bodyBase400)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                        .offset(y: 9)
                }
            }
            Spacer(minLength: 0)
            if isLoading {
                Spinner(size: IconSize.sm.value, lineWidth: 2)
            } else {
                Icon(systemName: open ? "chevron.up" : "chevron.down", size: .sm,
                     color: showsClear ? .clear : Theme.shared.text(.textTertiary))
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .scaledControlHeight(size.height)
        .frame(maxWidth: .infinity)
    }

    /// The trigger field — content composed here, chrome supplied by the ``SelectStyle``.
    private var field: some View {
        selectStyle.makeBody(configuration: SelectStyleConfiguration(
            content: AnyView(fieldContent),
            isOpen: open,
            isEnabled: isEnabled,
            hasError: infoMessages.dominantKind == .error,
            hasWarning: infoMessages.dominantKind == .warning
        ))
    }

    @ViewBuilder
    private var clearButton: some View {
        if showsClear {
            Button { selection = nil } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .padding(.trailing, Theme.SpacingKey.md.value)
        }
    }

    // MARK: Menu mode

    @ViewBuilder
    private var menuContent: some View {
        ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
            if let title = section.title {
                SwiftUI.Section(title) { rows(section.options) }
            } else {
                rows(section.options)
            }
        }
    }

    @ViewBuilder
    private func rows(_ options: [Option]) -> some View {
        ForEach(options, id: \.self) { option in
            Button {
                selection = option
            } label: {
                if selection == option { Label(optionTitle(option), systemImage: "checkmark") }
                else { Text(optionTitle(option)) }
            }
            .disabled(!optionEnabled(option))
        }
    }

    // MARK: Searchable panel

    private func filtered(_ options: [Option]) -> [Option] {
        guard !query.isEmpty else { return options }
        return options.filter { optionTitle($0).localizedCaseInsensitiveContains(query) }
    }

    @ViewBuilder
    private func panelMessage(spinner: Bool, _ text: String) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if spinner { Spinner(size: IconSize.sm.value, lineWidth: 2) }
            Text(text).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textTertiary))
            Spacer()
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    private var panel: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass", size: .sm, color: Theme.shared.text(.textTertiary))
                TextField("Ara", text: $query).textStyle(.bodyBase400).tint(Theme.shared.foreground(.fgHero))
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(44)
            DividerView(size: .small)

            if isLoading {
                panelMessage(spinner: true, String(themeKit: "Searching…"))
            } else if !hasAnyResults {
                panelMessage(spinner: false, String(themeKit: "No results"))
            } else {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    let opts = filtered(section.options)
                    if !opts.isEmpty {
                        if let title = section.title {
                            Text(title).textStyle(.labelSm600).foregroundStyle(Theme.shared.text(.textTertiary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.SpacingKey.md.value).padding(.vertical, Theme.SpacingKey.xs.value)
                        }
                        ForEach(opts, id: \.self) { option in
                            let enabled = optionEnabled(option)
                            Button { selection = option; open = false; query = "" } label: {
                                HStack {
                                    Text(optionTitle(option)).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textPrimary))
                                    Spacer()
                                    if selection == option {
                                        Icon(systemName: "checkmark", size: .sm, color: Theme.shared.foreground(.fgHero))
                                    }
                                }
                                .padding(.horizontal, Theme.SpacingKey.md.value).padding(.vertical, Theme.SpacingKey.sm.value)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(RowPressStyle())
                            .disabled(!enabled)
                            .opacity(enabled ? 1 : 0.4)
                        }
                    }
                }
            }
        }
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .stroke(Theme.shared.border(.borderPrimary), lineWidth: 1)
        )
        .themeShadow(.soft)
    }
}

#Preview {
    struct Demo: View {
        @State var city: String?
        var body: some View {
            VStack(spacing: 16) {
                Select("City", options: ["İstanbul", "Ankara", "İzmir"], selection: $city, allowClear: true) { $0 }
                Select("Searchable", sections: [.init("Marmara", ["İstanbul", "Bursa"]), .init("Ege", ["İzmir", "Aydın"])],
                       selection: $city, searchable: true) { $0 }
            }
            .padding()
        }
    }
    return Demo()
}
