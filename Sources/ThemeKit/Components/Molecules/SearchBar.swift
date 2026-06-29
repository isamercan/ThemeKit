//
//  SearchBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SearchView. Magnifying-glass
//  leading icon, clear button, optional back / trailing actions.
//
//  Optional typeahead: pass a static `suggestions` list or an async `suggest`
//  provider to get a results dropdown (debounced, with a loading spinner and a
//  "no results" state — the same shape as `Autocomplete`). Pass `recent` to show
//  a recent-searches list while the field is focused and empty. `onSubmit` fires
//  on the return/search key; `onSelect` fires when a suggestion or recent item is
//  tapped. With none of these set, the bar behaves exactly as before.
//

import SwiftUI

/// A search field with optional typeahead suggestions, a recent-searches list and
/// submit/clear callbacks.
///
/// ```swift
/// SearchBar(text: $query, suggestions: cities, recent: recents, onSubmit: search)
/// ```
public struct SearchBar: View {
    @Environment(\.theme) private var theme


    /// Where typeahead suggestions come from. `.none` keeps the classic bar
    /// (no dropdown) for callers that don't opt in.
    private enum Source {
        case none
        case staticList([String])
        case asyncProvider((String) async -> [String])
    }

    @Binding private var text: String
    private let placeholder: String
    private let onSearch: ((String) -> Void)?
    private var accessibilityID: String? = nil
    @Environment(\.isEnabled) private var isEnabled

    // Typeahead / recent-search additions (all opt-in).
    private let source: Source
    private let recent: [String]
    private let onSelect: ((String) -> Void)?
    private let onSubmit: ((String) -> Void)?
    private let onClearRecent: (() -> Void)?

    // Chrome + tuning — set via chainable modifiers (the async init seeds a 0.3s
    // debounce as its baseline, which `.debounce(_:)` can still override).
    private var showBackButton: Bool = false
    private var trailingSystemImage: String? = nil
    private var onBack: (() -> Void)? = nil
    private var onTrailing: (() -> Void)? = nil
    private var debounce: TimeInterval = 0
    private var maxResults: Int = 6

    @FocusState private var isFocused: Bool
    @State private var results: [String] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    /// Classic bar, optionally with a static suggestion list and recent searches.
    /// Every new parameter is defaulted, so existing call sites are unaffected.
    public init(
        text: Binding<String>,
        placeholder: String = "Search",
        suggestions: [String] = [],
        recent: [String] = [],
        onSearch: ((String) -> Void)? = nil,
        onSelect: ((String) -> Void)? = nil,
        onSubmit: ((String) -> Void)? = nil,
        onClearRecent: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.source = suggestions.isEmpty ? .none : .staticList(suggestions)
        self.recent = recent
        self.onSearch = onSearch
        self.onSelect = onSelect
        self.onSubmit = onSubmit
        self.onClearRecent = onClearRecent
    }

    /// Async suggestions from a provider (e.g. a remote search). Debounced, with a
    /// loading spinner and an empty state; the previous request is cancelled when
    /// the query changes (same lifecycle as `Autocomplete`).
    public init(
        text: Binding<String>,
        suggest: @escaping (String) async -> [String],
        placeholder: String = "Search",
        recent: [String] = [],
        onSearch: ((String) -> Void)? = nil,
        onSelect: ((String) -> Void)? = nil,
        onSubmit: ((String) -> Void)? = nil,
        onClearRecent: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.source = .asyncProvider(suggest)
        self.recent = recent
        self.debounce = 0.3   // async baseline; `.debounce(_:)` overrides
        self.onSearch = onSearch
        self.onSelect = onSelect
        self.onSubmit = onSubmit
        self.onClearRecent = onClearRecent
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if showBackButton {
                    Button { onBack?() } label: {
                        Icon(systemName: "chevron.left", size: .md, color: theme.text(.textPrimary))
                            .mirrorsInRTL()
                    }
                    .buttonStyle(.plain)
                }

                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Icon(systemName: "magnifyingglass", size: .sm, color: theme.text(.textTertiary))

                    TextField(placeholder, text: $text)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textPrimary))
                        .tint(theme.foreground(.fgHero))
                        .focused($isFocused)
                        .disabled(!isEnabled)
                        .submitLabel(.search)
                        .onSubmit { commitSubmit() }
                        .a11y(A11yElement.Field.field, in: accessibilityID)
                        .accessibilityLabel(placeholder)

                    trailingControl
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .scaledControlHeight(44)
                .background(theme.background(.bgElevatorPrimary),
                           in: RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.base.value, style: .continuous)
                        .strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
                )
            }

            dropdown
        }
        .onAppear { update(for: text) }
        .onDebouncedChange(of: text, for: effectiveDebounce) { value in
            update(for: value)
            onSearch?(value)
        }
    }

    // MARK: - Trailing control (spinner ▸ clear ▸ custom action)

    @ViewBuilder
    private var trailingControl: some View {
        if isLoading {
            Spinner(size: IconSize.sm.value, lineWidth: 2)
        } else if !text.isEmpty {
            Button { text = "" } label: {
                Icon(systemName: "xmark.circle.fill", size: .sm, color: theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
        } else if let trailingSystemImage {
            Button { onTrailing?() } label: {
                Icon(systemName: trailingSystemImage, size: .sm, color: theme.text(.textPrimary))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Dropdown

    /// Pure presentation state for the dropdown — what (if anything) to show given
    /// the current field state. Extracted so the branching is unit-testable.
    enum DropdownContent: Equatable {
        case hidden
        case recent([String])
        case loading
        case results([String])
        case noResults
    }

    static func dropdownContent(
        text: String,
        isFocused: Bool,
        recent: [String],
        results: [String],
        isLoading: Bool,
        hasSuggestions: Bool,
        maxRecent: Int
    ) -> DropdownContent {
        guard isFocused else { return .hidden }
        guard !text.isEmpty else {
            return recent.isEmpty ? .hidden : .recent(Array(recent.prefix(maxRecent)))
        }
        guard hasSuggestions else { return .hidden }
        if isLoading { return .loading }
        return results.isEmpty ? .noResults : .results(results)
    }

    private var hasSuggestions: Bool {
        if case .none = source { return false }
        return true
    }

    private var dropdownState: DropdownContent {
        Self.dropdownContent(
            text: text, isFocused: isFocused, recent: recent, results: results,
            isLoading: isLoading, hasSuggestions: hasSuggestions, maxRecent: maxResults
        )
    }

    @ViewBuilder
    private var dropdown: some View {
        switch dropdownState {
        case .hidden:
            EmptyView()
        case .recent(let items):
            card {
                header(String(themeKit: "Recent"), showsClear: onClearRecent != nil)
                rows(items, leadingSystemImage: "clock.arrow.circlepath")
            }
        case .loading:
            card {
                row {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Spinner(size: IconSize.sm.value, lineWidth: 2)
                        Text(String(themeKit: "Searching…"))
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textTertiary))
                        Spacer()
                    }
                }
            }
        case .noResults:
            card {
                row {
                    Text(String(themeKit: "No results"))
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textTertiary))
                }
            }
        case .results(let items):
            card { rows(items, leadingSystemImage: nil) }
        }
    }

    @ViewBuilder
    private func header(_ title: String, showsClear: Bool) -> some View {
        HStack {
            Text(title)
                .textStyle(.labelSm700)
                .foregroundStyle(theme.text(.textTertiary))
            Spacer()
            if showsClear {
                Button { onClearRecent?() } label: {
                    Text(String(themeKit: "Clear"))
                        .textStyle(.labelSm700)
                        .foregroundStyle(theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    @ViewBuilder
    private func rows(_ items: [String], leadingSystemImage: String?) -> some View {
        ForEach(items, id: \.self) { item in
            Button { select(item) } label: {
                row {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        if let leadingSystemImage {
                            Icon(systemName: leadingSystemImage, size: .sm, color: theme.text(.textTertiary))
                        }
                        Text(item)
                            .textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textPrimary))
                        Spacer()
                    }
                }
            }
            .buttonStyle(.plain)
            if item != items.last {
                DividerView(size: .small).padding(.leading, Theme.SpacingKey.md.value)
            }
        }
    }

    private func card<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        VStack(spacing: 0) { content() }
            .background(theme.background(.bgWhite),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
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

    // MARK: - Behaviour

    /// Effective debounce: only throttle when there's async work to throttle
    /// (a search callback or an async provider); otherwise apply changes at once.
    private var effectiveDebounce: TimeInterval {
        (onSearch == nil && !hasSuggestions) ? 0 : debounce
    }

    private func update(for query: String) {
        searchTask?.cancel()
        guard !query.isEmpty else {
            results = []
            isLoading = false
            return
        }
        switch source {
        case .none:
            results = []
            isLoading = false
        case .staticList(let all):
            results = Autocomplete.staticMatches(query, in: all, max: maxResults)
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

    private func select(_ value: String) {
        text = value
        results = []
        isFocused = false
        onSelect?(value)
    }

    private func commitSubmit() {
        isFocused = false
        onSubmit?(text)
    }
}

#Preview("Classic") {
    struct Demo: View {
        @State var a = ""
        @State var b = "query"
        var body: some View {
            VStack(spacing: 16) {
                SearchBar(text: $a).trailingIcon("barcode.viewfinder")
                SearchBar(text: $b).backButton()
            }
            .padding()
        }
    }
    return Demo()
}

#Preview("Suggestions + recent") {
    struct Demo: View {
        @State var text = ""
        let cities = ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa"]
        var body: some View {
            SearchBar(
                text: $text,
                placeholder: "Where to?",
                suggestions: cities,
                recent: ["Ankara", "Bursa"],
                onSelect: { _ in },
                onSubmit: { _ in },
                onClearRecent: { }
            )
            .padding()
        }
    }
    return Demo()
}

public extension SearchBar {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }

    /// Shows a leading back chevron; the optional action fires on tap.
    func backButton(_ on: Bool = true, action: (() -> Void)? = nil) -> Self {
        var copy = self; copy.showBackButton = on; copy.onBack = action; return copy
    }
    /// A trailing SF Symbol button (shown when the field is empty); the optional
    /// action fires on tap (e.g. a barcode scanner).
    func trailingIcon(_ systemName: String?, action: (() -> Void)? = nil) -> Self {
        var copy = self; copy.trailingSystemImage = systemName; copy.onTrailing = action; return copy
    }
    /// Debounce interval for typeahead / `onSearch` (async init defaults to 0.3s).
    func debounce(_ interval: TimeInterval) -> Self { var copy = self; copy.debounce = interval; return copy }
    /// Caps the number of suggestion rows (default 6).
    func maxResults(_ count: Int) -> Self { var copy = self; copy.maxResults = count; return copy }
}
