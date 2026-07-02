//
//  Autocomplete.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Molecule. A typeahead text field with a suggestion list. Two sources:
///   • a static `[String]` filtered locally as the user types, or
///   • an async `suggest` provider (remote search) with debounce, a loading
///     spinner, an empty "no results" state, and in-flight cancellation.
/// State (the bound text) is owned by the caller.
public struct Autocomplete: View {
    @Environment(\.theme) private var theme


    /// Where suggestions come from.
    private enum Source {
        case staticList([String])
        case asyncProvider((String) async -> [String])
    }

    private let label: String?
    @Binding private var text: String
    private let source: Source
    private let onSelect: (String) -> Void
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`

    // Appearance/tuning — set via the chainable modifiers below (R2); the async
    // init seeds a 0.3s debounce baseline, which `.debounce(_:)` can still override.
    private var placeholder: String = "Search"
    private var maxResults: Int = 5
    private var debounce: TimeInterval = 0
    private var isSuggestionEnabled: ((String) -> Bool)? = nil
    private var onSearch: ((String) -> Void)? = nil
    private var accessibilityID: String? = nil

    @FocusState private var isFocused: Bool
    @State private var results: [String] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    /// Local filtering over a static list.
    public init(   // R1
        _ label: String? = nil,
        text: Binding<String>,
        suggestions: [String],
        onSelect: @escaping (String) -> Void = { _ in }
    ) {
        self.label = label
        self._text = text
        self.source = .staticList(suggestions)
        self.onSelect = onSelect
    }

    /// Async suggestions from a provider (e.g. a remote search). Debounced, with a
    /// loading spinner and an empty state; the previous request is cancelled when
    /// the query changes.
    public init(   // R1
        _ label: String? = nil,
        text: Binding<String>,
        suggest: @escaping (String) async -> [String],
        onSelect: @escaping (String) -> Void = { _ in }
    ) {
        self.label = label
        self._text = text
        self.source = .asyncProvider(suggest)
        self.onSelect = onSelect
        self.debounce = 0.3   // async baseline; `.debounce(_:)` overrides
    }

    /// Pure matcher for the static source (extracted for testing).
    static func staticMatches(_ query: String, in all: [String], max: Int) -> [String] {
        guard !query.isEmpty else { return [] }
        return all.filter { $0.localizedCaseInsensitiveContains(query) }.prefix(max).map { $0 }
    }

    private func suggestionEnabled(_ suggestion: String) -> Bool { isSuggestionEnabled?(suggestion) ?? true }

    private var showsDropdown: Bool {
        isFocused && !text.isEmpty && (isLoading || !results.isEmpty || isEmptyResult)
    }

    private var isEmptyResult: Bool { !isLoading && results.isEmpty }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label) }

            HStack(spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "magnifyingglass").size(.sm).color(theme.text(.textTertiary))
                TextField(placeholder, text: $text)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                    .tint(theme.foreground(.fgHero))
                    .focused($isFocused)
                    .disabled(!isEnabled)
                    .a11y(A11yElement.Field.field, in: accessibilityID)
                    .accessibilityLabel(label ?? placeholder)
                if isLoading {
                    Spinner().size(IconSize.sm.value).lineWidth(2)
                } else if !text.isEmpty {
                    Button { text = "" } label: {
                        Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .scaledControlHeight(48)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .strokeBorder(isFocused ? theme.border(.borderHero) : theme.border(.borderPrimary), lineWidth: isFocused ? 1.5 : 1)
            )

            if showsDropdown { dropdown }
        }
        .onAppear { update(for: text) }
        .onDebouncedChange(of: text, for: debounce) { value in
            update(for: value)
            onSearch?(value)
        }
    }

    @ViewBuilder
    private var dropdown: some View {
        VStack(spacing: 0) {
            if isLoading {
                row { HStack(spacing: Theme.SpacingKey.sm.value) {
                    Spinner().size(IconSize.sm.value).lineWidth(2)
                    Text(String(themeKit: "Searching…")).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    Spacer()
                } }
            } else if results.isEmpty {
                row { Text(String(themeKit: "No results")).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
            } else {
                ForEach(results, id: \.self) { suggestion in
                    let enabled = suggestionEnabled(suggestion)
                    Button {
                        text = suggestion
                        results = []
                        onSelect(suggestion)
                        isFocused = false
                    } label: {
                        row { HStack {
                            Text(suggestion).textStyle(.bodyBase400).foregroundStyle(theme.text(.textPrimary))
                            Spacer()
                        } }
                    }
                    .buttonStyle(.plain)
                    .disabled(!enabled)
                    .opacity(enabled ? 1 : 0.4)
                    if suggestion != results.last { DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value) }
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

    private func row<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        content()
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
    }

    private func update(for query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            results = []
            isLoading = false
            return
        }
        switch source {
        case .staticList(let all):
            results = Self.staticMatches(query, in: all, max: maxResults)
            isLoading = false
        case .asyncProvider(let provider):
            isLoading = true
            searchTask = Task { @MainActor in
                let found = await provider(query)
                if Task.isCancelled { return }
                results = Array(found.prefix(maxResults))
                isLoading = false
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Autocomplete {
    /// Placeholder shown while the field is empty.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Caps the number of suggestion rows (default 5).
    func maxResults(_ count: Int) -> Self { copy { $0.maxResults = count } }

    /// Debounce interval for typeahead (async init defaults to 0.3s).
    func debounce(_ interval: TimeInterval) -> Self { copy { $0.debounce = interval } }

    /// Per-suggestion enable predicate; disabled rows are shown greyed and unselectable.
    func suggestionEnabled(_ predicate: ((String) -> Bool)?) -> Self { copy { $0.isSuggestionEnabled = predicate } }

    /// Fires with the query text on each (debounced) change.
    func onSearch(_ action: ((String) -> Void)?) -> Self { copy { $0.onSearch = action } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview("Static") {
    struct Demo: View {
        @State var text = ""
        var body: some View {
            Autocomplete("Destination", text: $text,
                         suggestions: ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa"])
                .padding()
        }
    }
    return Demo()
}

#Preview("Async") {
    struct Demo: View {
        @State var text = ""
        let cities = ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa"]
        var body: some View {
            Autocomplete("Destination", text: $text, suggest: { query in
                try? await Task.sleep(nanoseconds: 400_000_000)   // simulate network
                return cities.filter { $0.localizedCaseInsensitiveContains(query) }
            })
            .padding()
        }
    }
    return Demo()
}
