//
//  SearchBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SearchView. Magnifying-glass
//  leading icon, clear button, optional back / trailing actions.
//
//  Optional typeahead: pass a static `.suggestions(_:)` list or an async
//  `suggest` provider (init) to get a results dropdown (debounced, with a
//  loading spinner and a "no results" state — the same shape as `Autocomplete`).
//  Use `.recent(_:onClear:)` to show a recent-searches list while the field is
//  focused and empty. `.onCommit(_:)` fires on the return/search key;
//  `.onSelect(_:)` fires when a suggestion or recent item is tapped. With none
//  of these set, the bar behaves exactly as before.
//

import SwiftUI

/// A search field with optional typeahead suggestions, a recent-searches list and
/// submit/clear callbacks.
///
/// ```swift
/// SearchBar(text: $query)
///     .suggestions(cities)
///     .recent(recents)
///     .onCommit(search)
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
    @Environment(\.isEnabled) private var isEnabled

    // Appearance/config — mutated only through the modifiers below (R2); the
    // async init seeds a 0.3s debounce baseline, which `.debounce(_:)` can
    // still override. Typeahead / recent-search features are all opt-in.
    private var placeholder: String = "Search"
    private var source: Source = .none
    private var recent: [String] = []
    private var onSearch: ((String) -> Void)? = nil
    private var onSelect: ((String) -> Void)? = nil
    private var onSubmit: ((String) -> Void)? = nil
    private var onClearRecent: (() -> Void)? = nil
    private var showBackButton: Bool = false
    private var trailingSystemImage: String? = nil
    private var onBack: (() -> Void)? = nil
    private var onTrailing: (() -> Void)? = nil
    private var debounce: TimeInterval = 0
    private var maxResults: Int = 6
    private var accessibilityID: String? = nil

    @FocusState private var isFocused: Bool
    @State private var results: [String] = []
    @State private var isLoading = false
    @State private var searchTask: Task<Void, Never>?

    /// Classic bar. Add a static suggestion list via `.suggestions(_:)` and
    /// recent searches via `.recent(_:onClear:)`.
    public init(text: Binding<String>) {   // R1
        self._text = text
    }

    /// Async suggestions from a provider (e.g. a remote search). Debounced, with a
    /// loading spinner and an empty state; the previous request is cancelled when
    /// the query changes (same lifecycle as `Autocomplete`).
    public init(   // R1
        text: Binding<String>,
        suggest: @escaping (String) async -> [String]
    ) {
        self._text = text
        self.source = .asyncProvider(suggest)
        self.debounce = 0.3   // async baseline; `.debounce(_:)` overrides
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
                DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SearchBar {
    /// Placeholder shown while the field is empty.
    func placeholder(_ text: String) -> Self { copy { $0.placeholder = text } }

    /// Static typeahead suggestions, filtered locally as the user types (classic init only).
    func suggestions(_ items: [String]) -> Self { copy { $0.source = items.isEmpty ? .none : .staticList(items) } }

    /// Recent searches shown while the field is focused and empty; the optional
    /// action drives the header's Clear button.
    func recent(_ items: [String], onClear: (() -> Void)? = nil) -> Self {
        copy { $0.recent = items; $0.onClearRecent = onClear }
    }

    /// Fires with the query text on each (debounced) change.
    func onSearch(_ action: ((String) -> Void)?) -> Self { copy { $0.onSearch = action } }

    /// Fires when a suggestion or recent item is tapped.
    func onSelect(_ action: ((String) -> Void)?) -> Self { copy { $0.onSelect = action } }

    /// Fires with the query text on the return/search key (named to avoid SwiftUI's `.onSubmit`).
    func onCommit(_ action: ((String) -> Void)?) -> Self { copy { $0.onSubmit = action } }

    /// Shows a leading back chevron; the optional action fires on tap.
    func backButton(_ on: Bool = true, action: (() -> Void)? = nil) -> Self {
        copy { $0.showBackButton = on; $0.onBack = action }
    }

    /// A trailing SF Symbol button (shown when the field is empty); the optional
    /// action fires on tap (e.g. a barcode scanner).
    func trailingIcon(_ systemName: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.trailingSystemImage = systemName; $0.onTrailing = action }
    }

    /// Debounce interval for typeahead / `onSearch` (async init defaults to 0.3s).
    func debounce(_ interval: TimeInterval) -> Self { copy { $0.debounce = interval } }

    /// Caps the number of suggestion rows (default 6).
    func maxResults(_ count: Int) -> Self { copy { $0.maxResults = count } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
            SearchBar(text: $text)
                .placeholder("Where to?")
                .suggestions(cities)
                .recent(["Ankara", "Bursa"], onClear: { })
                .onSelect { _ in }
                .onCommit { _ in }
                .padding()
        }
    }
    return Demo()
}
