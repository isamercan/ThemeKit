//
//  Autocomplete.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. A typeahead text field with a filtered suggestion list. State owned
//  by the caller (the bound text); suggestions are filtered as the user types.
//

import SwiftUI

public struct Autocomplete: View {
    private let label: String?
    @Binding private var text: String
    private let suggestions: [String]
    private let placeholder: String
    private let maxResults: Int
    private let debounce: TimeInterval
    private let accessibilityID: String?
    private let isEnabled: Bool
    private let onSelect: (String) -> Void
    private let onSearch: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    public init(
        label: String? = nil,
        text: Binding<String>,
        suggestions: [String],
        placeholder: String = "Ara",
        maxResults: Int = 5,
        debounce: TimeInterval = 0,
        accessibilityID: String? = nil,
        isEnabled: Bool = true,
        onSelect: @escaping (String) -> Void = { _ in },
        onSearch: ((String) -> Void)? = nil
    ) {
        self.label = label
        self._text = text
        self.suggestions = suggestions
        self.placeholder = placeholder
        self.maxResults = maxResults
        self.debounce = debounce
        self.accessibilityID = accessibilityID
        self.isEnabled = isEnabled
        self.onSelect = onSelect
        self.onSearch = onSearch
    }

    private var filtered: [String] {
        guard !text.isEmpty else { return [] }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(text) }.prefix(maxResults).map { $0 }
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass", size: .sm, color: Theme.shared.text(.textTertiary))
                TextField(placeholder, text: $text)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                    .tint(Theme.shared.foreground(.fgHero))
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(label ?? placeholder)
                if !text.isEmpty {
                    Button { text = "" } label: {
                        Icon(systemName: "xmark.circle.fill", size: .sm, color: Theme.shared.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(48)
            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(isFocused ? Theme.shared.border(.borderHero) : Theme.shared.border(.borderPrimary), lineWidth: isFocused ? 1.5 : 1)
            )

            if isFocused && !filtered.isEmpty {
                VStack(spacing: 0) {
                    ForEach(filtered, id: \.self) { suggestion in
                        Button {
                            text = suggestion
                            onSelect(suggestion)
                            isFocused = false
                        } label: {
                            HStack {
                                Text(suggestion).textStyle(.bodyBase400).foregroundStyle(Theme.shared.text(.textPrimary))
                                Spacer()
                            }
                            .padding(.horizontal, Theme.SpacingKey.md.value)
                            .padding(.vertical, Theme.SpacingKey.sm.value)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        if suggestion != filtered.last { DividerView(size: .small).padding(.leading, Theme.SpacingKey.md.value) }
                    }
                }
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: 1)
                )
                .themeShadow(.soft)
            }
        }
        .onDebouncedChange(of: text, for: onSearch == nil ? 0 : debounce) { value in
            onSearch?(value)
        }
    }
}

#Preview {
    struct Demo: View {
        @State var text = ""
        var body: some View {
            Autocomplete(label: "Destination", text: $text,
                         suggestions: ["İstanbul", "İzmir", "İzmit", "Ankara", "Antalya", "Bursa"])
                .padding()
        }
    }
    return Demo()
}
