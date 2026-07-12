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
//  The *arrangement* is owned by the active ``AirportPickerStyle`` from the
//  environment (ADR-0004, Class B): the component wires the live search field,
//  the built sections, rows and chips into an `AirportPickerConfiguration` and
//  hands those pre-wired units to the style — `.list` (default) is today's
//  sectioned rows verbatim, `.compact` densifies (the promoted
//  `AirportPickerDensity.compact` knob), `.codeGrid` renders the browse
//  sections as an IATA chip grid. `AirportPickerPresentation` stays orthogonal
//  (presentation ≠ style): the trigger + sheet/popover/cover machinery live
//  here, never in a style.
//

import SwiftUI
import ThemeKit

/// Where the picker lives: embedded in the screen (`.inline`), or behind a
/// field-shaped trigger that opens a bottom sheet (`.sheet`), a popover
/// (`.popover` — anchored, for iPad/Mac), or a full-screen cover
/// (`.fullScreenCover` — phone-first immersive search; falls back to a sheet
/// on macOS, where full-screen covers don't exist).
public enum AirportPickerPresentation: Sendable { case inline, sheet, popover, fullScreenCover }

/// Vertical density of the suggestion rows: `.regular` (default) or
/// `.compact` (tighter row padding and section gaps for dense pickers).
/// Promoted to ``AirportPickerStyle`` presets by ADR-0004 — prefer
/// `.airportPickerStyle(.compact)`.
public enum AirportPickerDensity: Sendable { case compact, regular }

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
    /// The active arrangement (ADR-0004) — set once per subtree with `.airportPickerStyle(_:)`.
    @Environment(\.airportPickerStyle) private var envStyle
    @Environment(\.componentDensity) private var componentDensity
    @Environment(\.locale) private var locale

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
    private var placeholderTextOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var placeholderText: String { placeholderTextOverride ?? String(themeKitTravel: "City or airport") }
    private var presentationStyle: AirportPickerPresentation = .inline
    /// T2 empty slot. Local erasure (ThemeKit's `SlotContent` is internal to
    /// that module); `nil` = built-in "No airports found" state. The closure is
    /// evaluated immediately at the modifier call site, so nothing escapes.
    private var customEmpty: AnyView?
    private var accentColor: SemanticColor?
    private var accessibilityID: String?
    /// Per-airport row replacement (`(airport, isSelected)`); nil = built-in row.
    private var rowContentSlot: ((Airport, Bool) -> AnyView)?
    /// Replaces the built-in Skeleton loading rows.
    private var loadingSlot: AnyView?
    private var nearbyTitle: String?
    private var recentTitle: String?
    private var popularTitle: String?
    private var chipVariantValue: FillVariant = .soft
    private var sheetDetents: [BottomSheetDetent] = [.large]
    private var triggerIconName = "airplane"
    /// The deprecated `.density(_:)` knob — `nil` (unset) defers to the
    /// environment ``AirportPickerStyle``; explicit wins over it (ADR-0004 §5).
    private var densityOverride: AirportPickerDensity?
    /// Optional surface fill behind the search UI; `nil` = transparent (today's default).
    private var surfaceKey: Theme.BackgroundColorKey?

    /// Query is internal UI state (§9.4); selection is the controlled outcome.
    @State private var query = ""
    @State private var isSheetPresented = false

    /// Genuine dimensions with no semantic token — fixed row-anatomy constants.
    private enum Metrics {
        static let chipMinWidth: CGFloat = 44          // aligns the code column
        static let chipTapTarget: CGFloat = 44         // HIG minimum for the grid chip unit
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
        case .popover: popoverTrigger
        case .fullScreenCover: fullScreenTrigger
        }
    }

    /// The embedded form — the active style arranges the search field and
    /// sections directly in the screen (no internal scrolling).
    private var inlineBody: some View {
        styledSearch(isPresented: false)
    }

    // MARK: - Style dispatch (ADR-0004)

    /// Hands the pre-wired units + typed signals to the resolved style. The
    /// component keeps search/debounce/selection wiring and the presentation
    /// machinery; the style only arranges.
    private func styledSearch(isPresented: Bool) -> some View {
        resolvedStyle.makeBody(configuration: configuration(isPresented: isPresented))
    }

    /// ADR-0004 §5 precedence: an explicitly-set deprecated `.density(_:)`
    /// wins over the environment style (source-behaviour stability during
    /// migration) — `.compact` maps to ``CompactAirportPickerStyle``,
    /// `.regular` to the default ``ListAirportPickerStyle``.
    private var resolvedStyle: AnyAirportPickerStyle {
        guard let densityOverride else { return envStyle }
        return densityOverride == .compact
            ? AnyAirportPickerStyle(CompactAirportPickerStyle())
            : AnyAirportPickerStyle(ListAirportPickerStyle())
    }

    /// Gathers the pre-wired units (Class B) and typed signals for the style.
    private func configuration(isPresented: Bool) -> AirportPickerConfiguration {
        AirportPickerConfiguration(
            searchField: AnyView(searchField),
            loadingView: AnyView(loadingContentView),
            emptyView: AnyView(emptyState),
            sections: builtSections,
            sectionView: { AnyView(self.sectionView($0)) },
            sectionHeader: { AnyView(self.sectionHeaderView($0)) },
            row: { AnyView(self.row($0)) },
            selectableRow: { airport, label in AnyView(self.selectableRow(airport, label: label)) },
            codeChip: { AnyView(self.codeChip($0.code)) },
            selectableChip: { AnyView(self.selectableChip($0)) },
            customRowLabel: rowContentSlot.map { slot in
                { (airport: Airport) -> AnyView in slot(airport, self.isSelected(airport)) }
            },
            query: query,
            isLoading: isLoading,
            showsEmptyState: !isLoading && !query.isEmpty && suggestions.isEmpty,
            isPresented: isPresented,
            selection: selection,
            select: { self.select($0) },
            chipVariant: chipVariantValue,
            accent: accentColor,
            surfaceKey: surfaceKey,
            density: componentDensity,
            locale: locale)
    }

    /// The sections the active style arranges — pre-filtered (never empty),
    /// with resolved titles: the browse lists before typing, or the single
    /// results section while a query has suggestions.
    private var builtSections: [AirportPickerSection] {
        if query.isEmpty {
            var sections: [AirportPickerSection] = []
            if !nearbyAirports.isEmpty {
                sections.append(AirportPickerSection(
                    kind: .nearby, title: nearbyTitle ?? String(themeKitTravel: "Nearby"),
                    airports: nearbyAirports, onClear: nil))
            }
            if !recentAirports.isEmpty {
                sections.append(AirportPickerSection(
                    kind: .recent, title: recentTitle ?? String(themeKitTravel: "Recent"),
                    airports: recentAirports, onClear: onClearRecent))
            }
            if !popularAirports.isEmpty {
                sections.append(AirportPickerSection(
                    kind: .popular, title: popularTitle ?? String(themeKitTravel: "Popular"),
                    airports: popularAirports, onClear: nil))
            }
            return sections
        }
        guard !suggestions.isEmpty else { return [] }
        return [AirportPickerSection(kind: .results, title: nil, airports: suggestions, onClear: nil)]
    }

    // MARK: - Presented forms (sheet / popover / full-screen cover)

    /// The shared search UI hosted by every presented form — the style pins
    /// the search field and scrolls the sections (`isPresented` signal).
    private var presentedSearch: some View {
        styledSearch(isPresented: true)
    }

    /// The field-shaped trigger shared by the presented forms. FieldButton
    /// natively honors `.disabled(_:)` and `.readOnly(_:)`.
    private var trigger: some View {
        FieldButton(selection.map(Self.displayText) ?? placeholderText) { isSheetPresented = true }
            .icon(triggerIconName)
            .placeholder(selection == nil)
            .travelA11y("trigger", in: accessibilityID)
    }

    /// `.sheet`: the trigger opens the search UI in a `BottomSheet`; detents
    /// come from `.detents(_:)` (default `[.large]`).
    private var sheetTrigger: some View {
        trigger
            .bottomSheet(isPresented: $isSheetPresented, detents: sheetDetents) {
                presentedSearch
            }
    }

    /// `.popover`: the trigger anchors the search UI in a popover — the
    /// iPad/Mac counterpart of the bottom sheet.
    private var popoverTrigger: some View {
        trigger
            .popover(isPresented: $isSheetPresented) {
                presentedSearch
                    .padding(Theme.SpacingKey.md.value)
                    .frame(minWidth: 320, minHeight: 360)
            }
    }

    /// `.fullScreenCover`: immersive phone-first search. macOS has no
    /// full-screen cover, so it degrades to a plain sheet there.
    @ViewBuilder
    private var fullScreenTrigger: some View {
        #if os(iOS)
        trigger
            .fullScreenCover(isPresented: $isSheetPresented) {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                    HStack {
                        Spacer()
                        CloseButton { isSheetPresented = false }
                    }
                    presentedSearch
                }
                .padding(Theme.SpacingKey.md.value)
                .background(theme.background(.bgWhite))
            }
        #else
        trigger
            .sheet(isPresented: $isSheetPresented) {
                presentedSearch.padding(Theme.SpacingKey.md.value)
            }
        #endif
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

    // MARK: - Section units (handed to the style)

    /// The full stock section unit: header + rows + hairline dividers, plus
    /// the results accessibility identifier — `.list` places these verbatim.
    @ViewBuilder
    private func sectionView(_ section: AirportPickerSection) -> some View {
        if section.kind == .results {
            sectionStack(section)
                .travelA11y("results", in: accessibilityID)
        } else {
            sectionStack(section)
        }
    }

    private func sectionStack(_ section: AirportPickerSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionHeaderView(section)
            ForEach(section.airports) { airport in
                row(airport)
                if airport.id != section.airports.last?.id {
                    DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
                }
            }
        }
    }

    /// The header-only unit (title + Clear); nothing when the section is untitled.
    @ViewBuilder
    private func sectionHeaderView(_ section: AirportPickerSection) -> some View {
        if let title = section.title {
            sectionHeader(title, onClear: section.onClear)
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

    // MARK: - Row & chip units (bold IATA code chip + city/airport text)

    private func isSelected(_ airport: Airport) -> Bool { selection?.id == airport.id }

    /// The stock wired row: label (or the `.rowContent` slot) at regular
    /// padding, wrapped in the shared selection wiring.
    private func row(_ airport: Airport) -> some View {
        selectableRow(airport, label: AnyView(
            rowLabel(airport)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.vertical, Theme.SpacingKey.sm.value)))
    }

    @ViewBuilder
    private func rowLabel(_ airport: Airport) -> some View {
        if let rowContentSlot {
            rowContentSlot(airport, isSelected(airport))
        } else {
            builtInRowLabel(airport, isSelected: isSelected(airport))
        }
    }

    /// The single source of row interaction — tap → select, read-only gating,
    /// VoiceOver label/traits — reused by every style through the
    /// configuration's `selectableRow` unit.
    private func selectableRow(_ airport: Airport, label: AnyView) -> some View {
        Button { select(airport) } label: {
            label
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
        // Buttons carry `.isButton`; reads "IST, Istanbul Airport, Istanbul".
        .accessibilityLabel("\(airport.code), \(airport.name), \(airport.city)")
        .accessibilityAddTraits(isSelected(airport) ? .isSelected : [])
        .travelA11y("row.\(airport.code)", in: accessibilityID)
    }

    /// The wired chip unit for grid/cloud styles: the stock code chip, an
    /// accent ring when selected, a 44pt hit target and the row's VoiceOver
    /// treatment.
    private func selectableChip(_ airport: Airport) -> some View {
        Button { select(airport) } label: {
            codeChip(airport.code)
                .overlay {
                    if isSelected(airport) {
                        RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                            .strokeBorder(accentColor?.accent ?? theme.foreground(.fgHero), lineWidth: 1)
                    }
                }
                .frame(minWidth: Metrics.chipMinWidth, minHeight: Metrics.chipTapTarget)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .allowsHitTesting(!isReadOnly)
        .accessibilityLabel("\(airport.code), \(airport.name), \(airport.city)")
        .accessibilityAddTraits(isSelected(airport) ? .isSelected : [])
        .travelA11y("chip.\(airport.code)", in: accessibilityID)
    }

    /// The stock row anatomy — IATA chip + city/airport + selection checkmark.
    private func builtInRowLabel(_ airport: Airport, isSelected: Bool) -> some View {
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
    }

    /// Bold IATA code chip — token-fed fill/foreground, accent-tintable, with
    /// a `FillVariant` axis (`.soft` default, `.solid`, `.outline`, `.ghost`).
    private func codeChip(_ code: String) -> some View {
        let tone = accentColor ?? .primary
        let shape = RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
        let fill: Color
        let text: Color
        switch chipVariantValue {
        case .soft:
            fill = accentColor?.soft ?? theme.background(.bgSecondaryLight)
            text = accentColor?.accent ?? theme.text(.textPrimary)
        case .solid:
            fill = tone.solid
            text = tone.onSolid
        case .outline:
            fill = .clear
            text = accentColor?.accent ?? theme.text(.textPrimary)
        case .ghost:
            fill = .clear
            text = accentColor?.accent ?? theme.text(.textSecondary)
        }
        return Text(code)
            .textStyle(.labelSm700)
            .foregroundStyle(text)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .frame(minWidth: Metrics.chipMinWidth)
            .background(fill, in: shape)
            .overlay {
                if chipVariantValue == .outline {
                    shape.strokeBorder(accentColor?.border ?? theme.border(.borderPrimary), lineWidth: 1)
                }
            }
    }

    // MARK: - Loading (Skeleton rows) & empty states

    /// The loading unit handed to the style — the caller's `.loadingContent`
    /// slot when set, else the built-in Skeleton rows.
    @ViewBuilder
    private var loadingContentView: some View {
        if let loadingSlot { loadingSlot } else { loadingRows }
    }

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
    func placeholder(_ text: String) -> Self { copy { $0.placeholderTextOverride = text } }

    /// `.inline` (default) embeds the picker; `.sheet`, `.popover` and
    /// `.fullScreenCover` render a field-shaped trigger that opens the search
    /// UI in the matching container (`.fullScreenCover` degrades to a sheet on
    /// macOS).
    func presentation(_ p: AirportPickerPresentation) -> Self { copy { $0.presentationStyle = p } }

    /// Replaces the built-in suggestion row with caller content, built per
    /// `(airport, isSelected)`. Selection tap handling, read-only gating and
    /// the row's VoiceOver label/traits are preserved around the slot.
    func rowContent(@ViewBuilder _ content: @escaping (Airport, Bool) -> some View) -> Self {
        copy { $0.rowContentSlot = { AnyView(content($0, $1)) } }
    }

    /// Replaces the built-in Skeleton loading rows shown while `.loading(true)`.
    func loadingContent<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.loadingSlot = AnyView(content()) }
    }

    /// Overrides the pre-typing section headers; `nil` keeps the stock
    /// English-generic titles ("Nearby" / "Recent" / "Popular").
    func sectionTitles(nearby: String? = nil, recent: String? = nil, popular: String? = nil) -> Self {
        copy {
            $0.nearbyTitle = nearby
            $0.recentTitle = recent
            $0.popularTitle = popular
        }
    }

    /// Fill style of the IATA code chip: `.soft` (default), `.solid`,
    /// `.outline` or `.ghost` — all resolved from the accent's semantic ladder.
    func chipVariant(_ v: FillVariant) -> Self { copy { $0.chipVariantValue = v } }

    /// Detents for the `.sheet` presentation (default `[.large]`).
    func detents(_ detents: [BottomSheetDetent]) -> Self {
        copy { $0.sheetDetents = detents.isEmpty ? [.large] : detents }
    }

    /// SF Symbol on the field-shaped trigger (default `"airplane"`).
    func triggerIcon(_ systemName: String) -> Self { copy { $0.triggerIconName = systemName } }

    /// Row density: `.regular` (default) or `.compact`. Deprecate-forward
    /// (ADR-0004): `.compact` maps to the ``CompactAirportPickerStyle`` preset,
    /// `.regular` to ``ListAirportPickerStyle``; when explicitly set it wins
    /// over an ancestor `.airportPickerStyle(_:)` for source-behaviour
    /// stability during migration.
    @available(*, deprecated, message: "Use .airportPickerStyle(.compact)")
    func density(_ d: AirportPickerDensity) -> Self { copy { $0.densityOverride = d } }

    /// Surface fill behind the search field and sections (background token
    /// key); unset keeps the transparent default — the picker rides its
    /// screen's background.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

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
    Airport(code: "SAW", name: "Istanbul East Airport", city: "Istanbul", countryCode: "TR"),
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

#Preview("Flexibility — row slot · chip variants · density · titles") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State var popoverSel: Airport?
        @State var coverSel: Airport?
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Custom row content — tap/selection/a11y preserved.
                    AirportPicker(selection: .constant(previewAirports[0]),
                                  suggestions: [previewAirports[0], previewAirports[2]])
                        .seedQuery("i")
                        .rowContent { airport, isSelected in
                            HStack(spacing: Theme.SpacingKey.sm.value) {
                                Icon(systemName: isSelected ? "airplane.circle.fill" : "airplane.circle")
                                    .size(.md)
                                Text("\(airport.city) — \(airport.code)").textStyle(.labelBase600)
                                Spacer()
                            }
                        }
                    // Solid chip variant + custom section titles + the compact style
                    // (the promoted `.density(.compact)` knob, ADR-0004).
                    AirportPicker(selection: .constant(nil), suggestions: [])
                        .chipVariant(.solid)
                        .accent(.info)
                        .sectionTitles(recent: "Your searches", popular: "Trending routes")
                        .recent([previewAirports[2], previewAirports[4]])
                        .popular([previewAirports[0], previewAirports[5]])
                        .airportPickerStyle(.compact)
                    // Outline chips.
                    AirportPicker(selection: .constant(nil), suggestions: [])
                        .chipVariant(.outline)
                        .popular([previewAirports[3], previewAirports[6]])
                    // Custom loading slot.
                    AirportPicker(selection: .constant(nil), suggestions: [])
                        .seedQuery("Lon")
                        .loading()
                        .loadingContent {
                            Text("Searching airports…")
                                .textStyle(.bodySm400)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, Theme.SpacingKey.lg.value)
                        }
                    // Popover + full-screen cover triggers (custom icon, tight detents).
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        AirportPicker(selection: $popoverSel, suggestions: previewAirports)
                            .presentation(.popover)
                            .triggerIcon("airplane.departure")
                        AirportPicker(selection: $coverSel, suggestions: previewAirports)
                            .presentation(.fullScreenCover)
                            .detents([.medium])
                    }
                }
                .padding()
            }
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
