//
//  SearchBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SearchView. Magnifying-glass
//  leading icon (replaceable via `.leadingIcon(_:)` / `.leadingIconColor(_:)`),
//  clear button, optional back / trailing actions.
//
//  Validation, like `TextInput`: `.errorText(_:)`, `.infoMessages(_:)` and
//  `.helperText(_:)` render an `InfoMessageList` under the field; the dominant
//  severity drives the ambient `FieldStyle`'s error / warning border, and the
//  helper hides while the field is invalid (hideOnInvalid).
//
//  Optional typeahead: pass a static `.suggestions(_:)` list or an async
//  `suggest` provider (init) to get a results dropdown (debounced, with a
//  loading spinner and a "no results" state — the same shape as `Autocomplete`).
//  Use `.recent(_:onClear:)` to show a recent-searches list while the field is
//  focused and empty. `.onCommit(_:)` fires on the return/search key;
//  `.onSelect(_:)` fires when a suggestion or recent item is tapped. With none
//  of these set, the bar behaves exactly as before.
//
//  The field's *chrome* (fill, border, shape) is delegated to the ambient
//  ``FieldStyle`` (`.fieldStyle(_:)`), like `TextInput`. The back button sits
//  outside the chrome; the dropdown is a popover card and keeps its own chrome.
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
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle


    /// Where typeahead suggestions come from. `.none` keeps the classic bar
    /// (no dropdown) for callers that don't opt in.
    private enum Source {
        case none
        case staticList([String])
        case asyncProvider((String) async -> [String])
    }

    @Binding private var text: String
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.fieldDefaults) private var fieldDefaults

    // Appearance/config — mutated only through the modifiers below (R2); the
    // async init seeds a 0.3s debounce baseline, which `.debounce(_:)` can
    // still override. Typeahead / recent-search features are all opt-in.
    private var placeholderOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholder: String { placeholderOverride ?? String(themeKit: "Search") }
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
    private var leadingSystemImage: String = "magnifyingglass"
    private var leadingIconColorKey: Theme.TextColorKey = .textTertiary

    // Convenience helper/error strings + structured messages — merged into the
    // rendered message list at render time (see `messages`), mirroring
    // `TextInput`; the dominant severity drives the `FieldStyle` border.
    private var helperText: String?
    private var errorText: String?
    private var infoMessages: [InfoMessage] = []

    /// Optional external focus (e.g. driven by `FormValidator.focusBinding`) —
    /// bridged to the field's `@FocusState`, TextInput parity.
    private var externalFocus: Binding<Bool>?
    /// Internal editing-end hook (form wiring): fires with the current text when
    /// the field loses focus.
    private var onEditingEnd: ((String) -> Void)?

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

    /// `infoMessages` plus the helper/error conveniences (computed merge, same
    /// idiom as `TextInput`). The helper hides while the field is invalid
    /// (hideOnInvalid, as in the HeroUI reference) so the error replaces it.
    private var messages: [InfoMessage] {
        var messages = infoMessages
        if let errorText { messages.append(InfoMessage(errorText, kind: .error)) }
        if let helperText, !isInvalid { messages.append(InfoMessage(helperText, kind: .info)) }
        return messages
    }
    /// Whether the field is in an error state (an `errorText` or an
    /// error-severity `InfoMessage`) — gates the helper line.
    private var isInvalid: Bool {
        errorText != nil || infoMessages.contains { $0.kind == .error }
    }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }

    /// SearchBar has no `TextInputSize` modifier of its own; the subtree
    /// `FieldDefaults.size` maps onto its control height (the classic fixed
    /// 44pt equals `.small`, which stays the default).
    private var explicitSize: TextInputSize?
    private var effectiveSize: TextInputSize { explicitSize ?? fieldDefaults.size ?? .small }
    /// Message rows animate when micro-animations are on and the subtree default
    /// doesn't turn message motion off (Reduce Motion still wins inside MicroMotion).
    private var messagesAnimated: Bool { micro && (fieldDefaults.messagesAnimated ?? true) }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if showBackButton {
                    Button { onBack?() } label: {
                        Icon(systemName: "chevron.left").size(.md).color(theme.text(.textPrimary))
                            .mirrorsInRTL()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(themeKit: "Back"))
                }

                fieldBox
            }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }

            dropdown
        }
        // Message rows carry the HeroUI FieldError transition; key it here so
        // it plays (and snaps under `microAnimations(false)` / Reduce Motion /
        // `fieldDefaults(messagesAnimated: false)`).
        .animation(MicroMotion.animation(.fast, enabled: messagesAnimated, reduceMotion: reduceMotion), value: messages)
        .onAppear { update(for: text) }
        .onDebouncedChange(of: text, for: effectiveDebounce) { value in
            update(for: value)
            onSearch?(value)
        }
        // External focus bridge (TextInput parity): a `true` write focuses the
        // field; blurring resets the external binding so the owner stays in sync.
        .onChange(of: externalFocus?.wrappedValue ?? false) { _, want in
            if want && !isFocused { isFocused = true }
        }
        .onChange(of: isFocused) { _, now in
            if !now, externalFocus?.wrappedValue == true { externalFocus?.wrappedValue = false }
            if !now { onEditingEnd?(text) }   // form-wiring hook (`.field(_:in:)`)
        }
    }

    /// The composed field row (search icon + editor + trailing control), padded
    /// and sized — everything a `FieldStyle` receives as `configuration.content`.
    /// The control height is layout, not chrome, so it stays here — the classic
    /// 44pt (`.small`) unless the subtree `FieldDefaults.size` remaps it.
    private var fieldCore: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: leadingSystemImage).size(.sm).color(theme.text(leadingIconColorKey))

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
        .scaledControlHeight(effectiveSize.height)
    }

    /// The field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: `isFocused` ← the field's `@FocusState`;
    /// `isEnabled` ← `\.isEnabled`; `hasError` / `hasWarning` ← the dominant
    /// severity of the merged message list (same derivation as `TextInput`);
    /// `size` is the effective preset — SearchBar has no `TextInputSize` axis of
    /// its own, so it reports `.small` (its classic 44pt height) unless the
    /// subtree `FieldDefaults.size` remaps it. Size-keyed styles always see the
    /// preset that matches the rendered control height.
    @ViewBuilder
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize
        ))
    }

    // MARK: - Trailing control (spinner ▸ clear ▸ custom action)

    @ViewBuilder
    private var trailingControl: some View {
        if isLoading {
            Spinner().size(IconSize.sm.value).lineWidth(2)
        } else if !text.isEmpty {
            Button { text = "" } label: {
                Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Clear text"))
        } else if let trailingSystemImage {
            Button { onTrailing?() } label: {
                Icon(systemName: trailingSystemImage).size(.sm).color(theme.text(.textPrimary))
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
                        Spinner().size(IconSize.sm.value).lineWidth(2)
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
                            Icon(systemName: leadingSystemImage).size(.sm).color(theme.text(.textTertiary))
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
    func placeholder(_ text: String) -> Self { copy { $0.placeholderOverride = text } }

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? .small`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

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

    /// Replaces the leading SF Symbol (defaults to `"magnifyingglass"`).
    func leadingIcon(_ systemName: String) -> Self { copy { $0.leadingSystemImage = systemName } }

    /// Token key for the leading icon's color (defaults to `.textTertiary`).
    func leadingIconColor(_ key: Theme.TextColorKey) -> Self { copy { $0.leadingIconColorKey = key } }

    /// Convenience hint rendered under the field as an `.info` `InfoMessage`;
    /// hidden while the field is invalid (an `errorText` or an error-severity
    /// `infoMessages` entry is active).
    func helperText(_ text: String?) -> Self { copy { $0.helperText = text } }

    /// Convenience error appended to the message list as an `.error`
    /// `InfoMessage`; also flips the ambient `FieldStyle` into its error border.
    func errorText(_ text: String?) -> Self { copy { $0.errorText = text } }

    /// Validation / info messages rendered under the field (their dominant
    /// severity drives the `FieldStyle` error / warning border, as in `TextInput`).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Drive focus from outside (e.g. `FormValidator.focusBinding`) — TextInput parity.
    func externalFocus(_ binding: Binding<Bool>?) -> Self { copy { $0.externalFocus = binding } }

    /// Internal editing-end hook used by the form wiring (`.field(_:in:)`) to
    /// re-validate against the form's rules when the field loses focus.
    internal func onEditingEnd(_ handler: ((String) -> Void)?) -> Self { copy { $0.onEditingEnd = handler } }

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
    @Previewable @State var a = ""
    @Previewable @State var b = "query"
    @Previewable @State var c = ""
    PreviewMatrix("SearchBar") {
        PreviewCase("Trailing icon") { SearchBar(text: $a).trailingIcon("barcode.viewfinder") }
        PreviewCase("Back button + text") { SearchBar(text: $b).backButton() }
        // Same bar, underlined chrome via the ambient FieldStyle.
        PreviewCase("Underlined") { SearchBar(text: $c).fieldStyle(.underlined) }
        PreviewCase("Disabled") { SearchBar(text: .constant("")).disabled(true) }
    }
}

#Preview("Validation + custom icon") {
    struct Demo: View {
        @State var a = "b@d query"
        @State var b = ""
        @State var c = ""
        @State var d = "coffee"
        var body: some View {
            VStack(spacing: 16) {
                // Error message flips the ambient FieldStyle into its error border.
                SearchBar(text: $a)
                    .errorText("Query contains unsupported characters")
                // Helper line (an .info InfoMessage, like TextInput's helperText)…
                SearchBar(text: $b)
                    .helperText("Search by name, code or city")
                // …suppressed while an error is active (hideOnInvalid).
                SearchBar(text: $c)
                    .helperText("Search by name, code or city")
                    .errorText("Something went wrong")
                // Structured messages + a replaceable, token-colored leading icon.
                SearchBar(text: $d)
                    .leadingIcon("location.magnifyingglass")
                    .leadingIconColor(.textHero)
                    .infoMessages([InfoMessage("Searching nearby only", kind: .warning)])
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
