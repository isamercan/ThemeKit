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
///
/// The field's *chrome* (fill, border, shape) is delegated to the ambient
/// ``FieldStyle`` (`.fieldStyle(_:)`), like `TextInput`. The suggestion
/// dropdown is a popover card, not a field, and keeps its own chrome.
public struct Autocomplete: View {
    @Environment(\.theme) private var theme
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.fieldDefaults) private var fieldDefaults
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no editing.
    @Environment(\.isReadOnly) private var isReadOnly

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
    /// Clear affordance — on by default (Autocomplete's classic behavior);
    /// `.clearable(false)` hides it (Select-parity axis, E6). Set only by the
    /// `.clearable(_:)` modifier, so the subtree `FieldDefaults.clearable` can
    /// fill the default without overriding an explicit per-field choice (F5):
    /// `explicitClearable ?? fieldDefaults.clearable ?? true`.
    private var explicitClearable: Bool?
    /// Caller-driven loading state (async option fetch outside the built-in provider).
    private var externalLoading = false
    private var infoMessages: [InfoMessage] = []
    /// Explicit `.size(_:)` preset — wins over the subtree `FieldDefaults.size`.
    private var explicitSize: TextInputSize?
    /// `.required()` — asterisk on the label + ", required" in the a11y label.
    private var isRequired = false

    // Declarative validation (daisyUI Validator) — TextInput's plumbing: rules
    // run against the bound text at `effectiveValidationTrigger`; failures merge
    // into the rendered messages, driving the border state automatically.
    private var validationRules: [ValidationRule] = []
    /// Set only by an explicit `on:` argument to `validate(_:on:)`; `nil` falls
    /// back to `FieldDefaults.validationTrigger`, then `.editingEnd` (F5).
    private var explicitValidationTrigger: ValidationTrigger?
    private var onValidation: ((Bool) -> Void)?
    @State private var validationMessages: [InfoMessage] = []

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
        isFocused && !isReadOnly && !text.isEmpty && (isLoading || !results.isEmpty || isEmptyResult)
    }

    private var isEmptyResult: Bool { !isLoading && results.isEmpty }

    /// Explicit `infoMessages(_:)` plus any current `validate(_:on:)` failures.
    private var messages: [InfoMessage] { infoMessages + validationMessages }
    private var dominant: InfoMessage.Kind? { messages.dominantKind }
    private var hasError: Bool { dominant == .error }
    private var hasWarning: Bool { dominant == .warning }
    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → the classic scaled 48pt.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }
    /// Whether `.required()` renders its asterisk (`FieldDefaults.requiredIndicator`;
    /// the accessibility ", required" suffix is unaffected).
    private var showsRequiredIndicator: Bool { fieldDefaults.requiredIndicator ?? true }
    private var showsSpinner: Bool { isLoading || externalLoading }
    /// Explicit `.clearable(_:)` → subtree `FieldDefaults.clearable` → on (Autocomplete's classic default, F5).
    private var effectiveClearable: Bool { explicitClearable ?? fieldDefaults.clearable ?? true }
    /// Explicit `on:` argument → subtree `FieldDefaults.validationTrigger` → `.editingEnd` (F5).
    private var effectiveValidationTrigger: ValidationTrigger {
        explicitValidationTrigger ?? fieldDefaults.validationTrigger ?? .editingEnd
    }
    private var showsClear: Bool { effectiveClearable && !text.isEmpty && isEnabled && !isReadOnly }
    private var a11yLabel: String {
        let base = label ?? placeholder
        return isRequired ? base + ", " + String(themeKit: "required") : base
    }

    /// Runs the declared rules (first failure only, via `Validator`);
    /// publishes the result and reports validity.
    private func runValidation(_ value: String) {
        guard !validationRules.isEmpty else { return }
        let failures = Validator.validate(value, validationRules)
        if failures != validationMessages { validationMessages = failures }
        onValidation?(!failures.contains { $0.kind == .error })
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let label { InputLabel(label).required(isRequired && showsRequiredIndicator).hasError(hasError) }

            fieldBox

            if showsDropdown { dropdown }

            if !messages.isEmpty {
                InfoMessageList(messages)
                    .a11y(A11yElement.Field.message, in: accessibilityID)
            }
        }
        .onAppear { update(for: text) }
        .onDebouncedChange(of: text, for: debounce) { value in
            update(for: value)
            onSearch?(value)
        }
        // `.live` validates every change; other triggers re-validate once a
        // failure is visible so the error clears as the user fixes it.
        .onChange(of: text) { _, value in
            if effectiveValidationTrigger == .live || !validationMessages.isEmpty { runValidation(value) }
        }
        .onChange(of: isFocused) { _, now in
            if !now, effectiveValidationTrigger == .editingEnd { runValidation(text) }   // validate on blur
        }
    }

    /// The composed field row (icon + editor + spinner/clear), padded and sized —
    /// everything a `FieldStyle` receives as `configuration.content`. The fixed
    /// 48pt control height is layout, not chrome, so it stays here.
    private var fieldCore: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: "magnifyingglass").size(.sm).color(theme.text(.textTertiary))
            TextField(placeholder, text: $text)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                // Caret / selection tint follows the validation state.
                .tint(theme.foreground(hasError ? .systemcolorsFgError : .fgHero))
                .focused($isFocused)
                .disabled(!isEnabled)
                // Read-only keeps the normal chrome + VoiceOver value but
                // blocks focus/editing (E1 — distinct from `.disabled`).
                .allowsHitTesting(!isReadOnly)
                .onSubmit { runValidation(text) }   // submit is the strongest trigger
                .a11y(A11yElement.Field.field, in: accessibilityID)
                .accessibilityLabel(a11yLabel)
            if showsSpinner {
                Spinner().size(IconSize.sm.value).lineWidth(2)
            } else if showsClear {
                Button { text = "" } label: {
                    Icon(systemName: "xmark.circle.fill").size(.sm).color(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .a11y(A11yElement.Field.clear, in: accessibilityID)
                .accessibilityLabel(String(themeKit: "Clear"))
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .scaledControlHeight(effectiveSize?.height ?? 48)
    }

    /// The field row wrapped in the active ``FieldStyle`` chrome (fill + border).
    /// Configuration mapping: `isFocused` ← the field's `@FocusState`;
    /// `isEnabled` ← `\.isEnabled`; `hasError` / `hasWarning` follow the dominant
    /// message kind (explicit `infoMessages` + validation failures). With no
    /// explicit `.size(_:)` and no subtree `FieldDefaults.size` the height stays
    /// the classic scaled 48pt (nominal `.medium`), carried by the content.
    @ViewBuilder
    private var fieldBox: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(fieldCore),
            isFocused: isFocused,
            isEnabled: isEnabled,
            hasError: hasError,
            hasWarning: hasWarning,
            size: effectiveSize ?? .medium
        ))
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

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? 48pt`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    /// Show a trailing clear button while the field has text (on by default —
    /// Autocomplete's classic behavior; pass `false` to hide it). An explicit
    /// call wins over the subtree `FieldDefaults.clearable` default (F5).
    func clearable(_ on: Bool = true) -> Self { copy { $0.explicitClearable = on } }

    /// Shows a loading spinner in place of the clear button (caller-driven
    /// async option fetch; the built-in async provider spins automatically).
    func loading(_ on: Bool = true) -> Self { copy { $0.externalLoading = on } }

    /// Validation / info messages rendered under the field (drives the border state).
    func infoMessages(_ messages: [InfoMessage]) -> Self { copy { $0.infoMessages = messages } }

    /// Marks the field required: an error-token asterisk on the label (honoring
    /// `FieldDefaults.requiredIndicator`) and ", required" in the a11y label.
    func required(_ on: Bool = true) -> Self { copy { $0.isRequired = on } }

    /// Declarative validation (daisyUI Validator): `rules` run against the bound
    /// text at `trigger` (`.editingEnd` on blur, `.live` per keystroke, `.submit`
    /// on return). Failures merge into the rendered messages and border state.
    /// Omitting `on:` follows the subtree `FieldDefaults.validationTrigger`
    /// default, then `.editingEnd` (F5); an explicit trigger always wins.
    ///
    ///     Autocomplete("City", text: $city, suggestions: cities)
    ///         .validate([.required(), .minLength(2)])
    func validate(_ rules: [ValidationRule], on trigger: ValidationTrigger? = nil) -> Self {
        copy { $0.validationRules = rules; if let trigger { $0.explicitValidationTrigger = trigger } }
    }

    /// Reports validity after each `validate(_:on:)` pass — `true` when no
    /// error-severity failure is present.
    func onValidation(_ handler: @escaping (Bool) -> Void) -> Self { copy { $0.onValidation = handler } }

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
    // The suggestion dropdown is focus-driven; each cell shows the field chrome
    // as a single static frame (type in the demo for live suggestions).
    let cities = ["Istanbul", "Izmir", "Izmit", "Ankara", "Antalya", "Bursa"]
    PreviewMatrix("Autocomplete") {
        PreviewCase("Default") { Autocomplete("Destination", text: .constant(""), suggestions: cities) }
        // Same field, underlined chrome via the ambient FieldStyle.
        PreviewCase("Underlined chrome") {
            Autocomplete("Destination", text: .constant(""), suggestions: cities)
                .fieldStyle(.underlined)
        }
        // Required + validation + loading spinner (E6 axes).
        PreviewCase("Required + validation") {
            Autocomplete("City", text: .constant(""), suggestions: cities)
                .required()
                .validate([.required(), .minLength(2)])
        }
        PreviewCase("Loading") { Autocomplete("Fetching", text: .constant(""), suggestions: cities).loading() }
        // Read-only: normal chrome + value, no editing or clear (E1).
        PreviewCase("Read-only") {
            Autocomplete("Origin (read-only)", text: .constant("Istanbul"), suggestions: cities)
                .readOnly()
        }
        // Size ramp — explicit `.size(_:)` wins over `FieldDefaults.size`.
        PreviewCase("Small") { Autocomplete("Small", text: .constant(""), suggestions: cities).size(.small) }
        PreviewCase("Large · not clearable") {
            Autocomplete("Large", text: .constant(""), suggestions: cities).size(.large)
                .clearable(false)
        }
        PreviewCase("Disabled") { Autocomplete("Disabled", text: .constant(""), suggestions: cities).disabled(true) }
    }
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
