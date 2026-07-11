//
//  AirportPicker.swift
//  ThemeKitTravel
//
//  Organism (edition, §9.4). Airport search & select — a query field over
//  sectioned suggestion rows: *nearby / recent / popular* before typing,
//  caller-supplied results while typing, `Skeleton` rows while the caller's
//  lookup is in flight, and a replaceable `.emptyContent { }` slot (T2).
//
//  The component NEVER performs lookup itself (house rule 1 — no `Task` /
//  network): the caller owns the search and feeds `suggestions`; the component
//  owns DEBOUNCE of the query callback. Debounce is delegated to the composed
//  `SearchBar`'s `.onSearch`/`.debounce` pair, which throttles through the same
//  `onDebouncedChange(of:for:)` helper `Autocomplete.debounce(_:)` uses — one
//  mechanism, zero re-implementation.
//
//  Presentation: `.inline` embeds the field + sections in the screen;
//  `.sheet` renders a `FieldButton` trigger that opens the same search UI in
//  the shared `BottomSheet` (`.bottomSheet(isPresented:detents:)`).
//
//  Rows are fixed anatomy (bold IATA code chip + city/airport text) — no Style
//  protocol until real archetypes exist (promotion rule).
//

import SwiftUI
import ThemeKit

/// Where the picker lives: embedded in the screen (`.inline`) or behind a
/// field-shaped trigger that opens a bottom sheet (`.sheet`).
public enum AirportPickerPresentation: Sendable { case inline, sheet }

/// Airport search & select. Controlled selection + caller-owned suggestions;
/// the debounced `.onQueryChange` callback is where the caller runs its lookup.
///
/// ```swift
/// AirportPicker(selection: $origin, suggestions: results)
///     .onQueryChange { query in results = store.airports(matching: query) }
///     .recent(store.recentAirports, onClear: store.clearRecents)
///     .popular(curated.popular)
///     .loading(searching)
/// ```
public struct AirportPicker: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled     // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no editing/selection.
    @Environment(\.isReadOnly) private var isReadOnly

    @Binding private var selection: Airport?
    private let suggestions: [Airport]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var queryChangeAction: ((String) -> Void)?
    private var debounceInterval: TimeInterval = 0.25
    private var recentAirports: [Airport] = []
    private var onClearRecent: (() -> Void)?
    private var popularAirports: [Airport] = []
    private var nearbyAirports: [Airport] = []
    private var isLoading = false
    private var placeholderText = String(themeKitTravel: "City or airport")
    private var presentationStyle: AirportPickerPresentation = .inline
    /// T2 empty slot. Local erasure (ThemeKit's `SlotContent` is internal to
    /// that module); `nil` = built-in "No airports found" state. The closure is
    /// evaluated immediately at the modifier call site, so nothing escapes.
    private var customEmpty: AnyView?
    private var accentColor: SemanticColor?
    private var accessibilityID: String?

    /// Query is internal UI state (§9.4); selection is the controlled outcome.
    @State private var query = ""
    @State private var isSheetPresented = false

    /// Genuine dimensions with no semantic token — fixed row-anatomy constants.
    private enum Metrics {
        static let chipMinWidth: CGFloat = 44          // aligns the code column
        static let skeletonRowCount = 4
        static let skeletonChipHeight: CGFloat = 24
        static let skeletonTitle = CGSize(width: 120, height: 12)
        static let skeletonSubtitle = CGSize(width: 180, height: 10)
    }

    /// R1 — controlled selection + the current suggestion list (caller-owned).
    public init(selection: Binding<Airport?>, suggestions: [Airport]) {
        self._selection = selection
        self.suggestions = suggestions
    }

    // MARK: - Body

    public var body: some View {
        switch presentationStyle {
        case .inline: inlineBody
        case .sheet: sheetTrigger
        }
    }

    private var inlineBody: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            searchField
            listContent
        }
    }

    // MARK: - Sheet presentation (reuses the shared BottomSheet)

    /// `.sheet`: a `FieldButton` trigger (label = current selection or the
    /// placeholder) opening the same search UI in a `BottomSheet`. FieldButton
    /// natively honors `.disabled(_:)` and `.readOnly(_:)`.
    private var sheetTrigger: some View {
        FieldButton(selection.map(Self.displayText) ?? placeholderText) { isSheetPresented = true }
            .icon("airplane")
            .placeholder(selection == nil)
            .travelA11y("trigger", in: accessibilityID)
            .bottomSheet(isPresented: $isSheetPresented, detents: [.large]) {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                    searchField
                    ScrollView { listContent }
                }
            }
    }

    // MARK: - Search field (debounce delegated to SearchBar → onDebouncedChange)

    /// The composed `SearchBar`. Its `.onSearch`/`.debounce` pair throttles the
    /// caller's `onQueryChange` through `onDebouncedChange(of:for:)` — the exact
    /// mechanism behind `Autocomplete.debounce(_:)`. Read-only keeps the normal
    /// chrome but blocks editing (E1 — distinct from `.disabled`).
    private var searchField: some View {
        SearchBar(text: $query)
            .placeholder(placeholderText)
            .onSearch(queryChangeAction)
            .debounce(debounceInterval)
            .a11yID(accessibilityID)
            .allowsHitTesting(!isReadOnly)
            // §9.4 — the field announces result-count changes.
            .accessibilityValue(resultCountValue)
    }

    private var resultCountValue: String {
        guard !query.isEmpty, !isLoading else { return "" }
        return String(themeKitTravel: "\(suggestions.count) results")
    }

    // MARK: - Sections

    @ViewBuilder
    private var listContent: some View {
        if isLoading {
            loadingRows
        } else if query.isEmpty {
            preTypingSections
        } else if suggestions.isEmpty {
            emptyState
        } else {
            section(nil, airports: suggestions)
                .travelA11y("results", in: accessibilityID)
        }
    }

    /// Shown before/alongside typing — each section only when it has airports.
    @ViewBuilder
    private var preTypingSections: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if !nearbyAirports.isEmpty {
                section(String(themeKitTravel: "Nearby"), airports: nearbyAirports)
            }
            if !recentAirports.isEmpty {
                section(String(themeKitTravel: "Recent"), airports: recentAirports, onClear: onClearRecent)
            }
            if !popularAirports.isEmpty {
                section(String(themeKitTravel: "Popular"), airports: popularAirports)
            }
        }
    }

    @ViewBuilder
    private func section(_ title: String?, airports: [Airport], onClear: (() -> Void)? = nil) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let title { sectionHeader(title, onClear: onClear) }
            ForEach(airports) { airport in
                row(airport)
                if airport.id != airports.last?.id {
                    DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
                }
            }
        }
    }

    private func sectionHeader(_ title: String, onClear: (() -> Void)?) -> some View {
        HStack {
            Text(title)
                .textStyle(.labelSm700)
                .foregroundStyle(theme.text(.textTertiary))
                .accessibilityAddTraits(.isHeader)
            Spacer()
            if let onClear {
                Button(action: onClear) {
                    Text(String(themeKitTravel: "Clear"))
                        .textStyle(.labelSm700)
                        .foregroundStyle(accentColor?.accent ?? theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
                .disabled(isReadOnly)
                .accessibilityLabel(String(themeKitTravel: "Clear recent airports"))
                .travelA11y("recent.clear", in: accessibilityID)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
    }

    // MARK: - Row (fixed anatomy: bold IATA code chip + city/airport text)

    private func row(_ airport: Airport) -> some View {
        let isSelected = selection?.id == airport.id
        return Button { select(airport) } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                codeChip(airport.code)
                VStack(alignment: .leading, spacing: 2) {
                    Text(airport.city)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textPrimary))
                    Text(airport.name)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .lineLimit(1)
                Spacer(minLength: Theme.SpacingKey.xs.value)
                if isSelected {
                    Icon(systemName: "checkmark")
                        .size(.sm)
                        .color(accentColor?.accent ?? theme.foreground(.fgHero))
                }
            }
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
        // Buttons carry `.isButton`; reads "IST, Istanbul Airport, Istanbul".
        .accessibilityLabel("\(airport.code), \(airport.name), \(airport.city)")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .travelA11y("row.\(airport.code)", in: accessibilityID)
    }

    /// Bold IATA code chip — token-fed fill/foreground, accent-tintable.
    private func codeChip(_ code: String) -> some View {
        Text(code)
            .textStyle(.labelSm700)
            .foregroundStyle(accentColor?.accent ?? theme.text(.textPrimary))
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .frame(minWidth: Metrics.chipMinWidth)
            .background(
                accentColor?.soft ?? theme.background(.bgSecondaryLight),
                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
            )
    }

    // MARK: - Loading (Skeleton rows) & empty states

    private var loadingRows: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<Metrics.skeletonRowCount, id: \.self) { index in
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    Skeleton(.rounded(Theme.RadiusRole.selector))
                        .size(width: Metrics.chipMinWidth, height: Metrics.skeletonChipHeight)
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                        Skeleton(.rounded(Theme.RadiusRole.selector))
                            .size(width: Metrics.skeletonTitle.width, height: Metrics.skeletonTitle.height)
                        Skeleton(.rounded(Theme.RadiusRole.selector))
                            .size(width: Metrics.skeletonSubtitle.width, height: Metrics.skeletonSubtitle.height)
                    }
                    Spacer()
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.vertical, Theme.SpacingKey.sm.value)
                if index < Metrics.skeletonRowCount - 1 {
                    DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(themeKitTravel: "Loading suggestions"))
    }

    /// Built-in empty state, replaceable via `.emptyContent { }` (T2 slot).
    @ViewBuilder
    private var emptyState: some View {
        if let customEmpty {
            customEmpty
        } else {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Icon(systemName: "airplane.circle").size(.lg).color(theme.text(.textTertiary))
                Text(String(themeKitTravel: "No airports found"))
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.SpacingKey.lg.value)
        }
    }

    // MARK: - Behaviour

    private func select(_ airport: Airport) {
        guard isEnabled, !isReadOnly else { return }
        selection = airport
        query = Self.displayText(airport)
        isSheetPresented = false
    }

    /// "Istanbul (IST)" — the field/trigger echo of a selection.
    static func displayText(_ airport: Airport) -> String {
        "\(airport.city) (\(airport.code))"
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AirportPicker {
    /// Debounced query callback — the caller performs its lookup and updates
    /// `suggestions`. Throttled by `debounce(_:)` (0.25s default) through the
    /// composed `SearchBar` → `onDebouncedChange`, the same mechanism as
    /// `Autocomplete.debounce(_:)`. The component itself never spawns work.
    func onQueryChange(_ action: @escaping (String) -> Void) -> Self {
        copy { $0.queryChangeAction = action }
    }

    /// Debounce interval for the query callback (default 0.25s, clamped ≥ 0).
    func debounce(_ interval: TimeInterval) -> Self {
        copy { $0.debounceInterval = max(0, interval) }
    }

    /// Recent airports shown before typing; the optional action drives the
    /// section header's Clear button.
    func recent(_ airports: [Airport], onClear: (() -> Void)? = nil) -> Self {
        copy { $0.recentAirports = airports; $0.onClearRecent = onClear }
    }

    /// Curated popular airports shown before typing.
    func popular(_ airports: [Airport]) -> Self { copy { $0.popularAirports = airports } }

    /// Airports near the user shown before typing (the caller resolves location).
    func nearby(_ airports: [Airport]) -> Self { copy { $0.nearbyAirports = airports } }

    /// Skeleton rows while the caller's lookup is in flight.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Placeholder for the search field / sheet trigger (default "City or airport").
    func placeholder(_ text: String) -> Self { copy { $0.placeholderText = text } }

    /// `.inline` (default) embeds the picker; `.sheet` renders a field-shaped
    /// trigger opening the search UI in a `BottomSheet`.
    func presentation(_ p: AirportPickerPresentation) -> Self { copy { $0.presentationStyle = p } }

    /// Replaces the built-in "No airports found" state (T2 slot). Shown when a
    /// typed query has no suggestions and no lookup is in flight.
    func emptyContent<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customEmpty = AnyView(content()) }
    }

    /// Semantic tint for the code chips, selection checkmark and Clear action;
    /// `nil` (default) keeps the hero/neutral tokens.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`, e.g. `"<id>.row.IST"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    /// Seeds the internal query (previews/snapshots only — the query is UI
    /// state owned by the component, so this is deliberately not public API).
    internal func seedQuery(_ text: String) -> Self { copy { $0._query = State(initialValue: text) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Private helpers

private extension View {
    /// Namespaced accessibility identifier (`"<namespace>.<element>"`), applied
    /// only when the caller set an `a11yID` (ThemeKit's `.a11y` is internal).
    @ViewBuilder
    func travelA11y(_ element: String, in namespace: String?) -> some View {
        if let namespace {
            accessibilityIdentifier("\(namespace).\(element)")
        } else {
            self
        }
    }
}

// MARK: - Previews

private let previewAirports: [Airport] = [
    Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR"),
    Airport(code: "SAW", name: "Sabiha Gokcen Airport", city: "Istanbul", countryCode: "TR"),
    Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB"),
    Airport(code: "LGW", name: "Gatwick Airport", city: "London", countryCode: "GB"),
    Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US"),
    Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR"),
    Airport(code: "AMS", name: "Schiphol Airport", city: "Amsterdam", countryCode: "NL"),
]

#Preview("Inline — sections") {
    struct Demo: View {
        @State var selection: Airport?
        @State var results: [Airport] = []
        var body: some View {
            AirportPicker(selection: $selection, suggestions: results)
                .onQueryChange { q in
                    results = q.isEmpty ? [] : previewAirports.filter {
                        $0.city.localizedCaseInsensitiveContains(q)
                            || $0.name.localizedCaseInsensitiveContains(q)
                            || $0.code.localizedCaseInsensitiveContains(q)
                    }
                }
                .nearby([previewAirports[1]])
                .recent([previewAirports[2], previewAirports[4]], onClear: { })
                .popular([previewAirports[0], previewAirports[5], previewAirports[6]])
                .padding()
        }
    }
    return Demo()
}

#Preview("Results · loading · empty · read-only") {
    VStack(alignment: .leading, spacing: 24) {
        // Typed query with results — accent tints chips/checkmark.
        AirportPicker(selection: .constant(previewAirports[2]),
                      suggestions: [previewAirports[2], previewAirports[3]])
            .seedQuery("Lon")
            .accent(.info)
        // Caller lookup in flight — Skeleton rows.
        AirportPicker(selection: .constant(nil), suggestions: [])
            .seedQuery("Par")
            .loading()
        // No matches — custom empty slot.
        AirportPicker(selection: .constant(nil), suggestions: [])
            .seedQuery("zzz")
            .emptyContent {
                Text("Try a city name or IATA code").textStyle(.bodySm400)
            }
        // Read-only: normal chrome, no editing or selection (E1).
        AirportPicker(selection: .constant(previewAirports[0]), suggestions: [])
            .recent([previewAirports[0]])
            .readOnly()
    }
    .padding()
}

#Preview("Sheet presentation") {
    struct Demo: View {
        @State var selection: Airport?
        @State var results: [Airport] = []
        var body: some View {
            AirportPicker(selection: $selection, suggestions: results)
                .presentation(.sheet)
                .onQueryChange { q in
                    results = previewAirports.filter { $0.city.localizedCaseInsensitiveContains(q) }
                }
                .popular(previewAirports)
                .padding()
        }
    }
    return Demo()
}

#Preview("Dark") {
    let dark = Theme()
    dark.loadTheme(named: Theme.defaultThemeName, dark: true)
    return VStack(spacing: 24) {
        AirportPicker(selection: .constant(previewAirports[0]), suggestions: [])
            .recent([previewAirports[2]])
            .popular([previewAirports[0], previewAirports[5]])
        AirportPicker(selection: .constant(nil), suggestions: []).loading()
    }
    .padding()
    .background(dark.background(.bgBase))
    .theme(dark)
}
