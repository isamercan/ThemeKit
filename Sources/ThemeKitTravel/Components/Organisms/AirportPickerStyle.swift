//
//  AirportPickerStyle.swift
//  ThemeKit
//
//  The styling hook for ``AirportPicker`` — a Class B configuration of ADR-0004
//  (per-component style protocols): the component owns the *live interaction*
//  (search field with debounced `onQueryChange`, selection wiring, read-only
//  gating, presentation sheets), and hands styles **pre-wired units** plus typed
//  signals. Styles arrange; they never re-wire. Three built-ins:
//
//    .list      the sectioned suggestion list — search field over nearby /
//               recent / popular / results rows (IATA chip + city/airport).
//               Today's picker, verbatim. Default.
//    .compact   dense rows — tight padding, subtitle hidden (the promotion of
//               the deprecated `AirportPickerDensity.compact` knob).
//    .codeGrid  the browse sections (nearby/recent/popular) as a tappable
//               IATA-code chip grid; typed results keep the full rows.
//
//      AirportPicker(selection: $origin, suggestions: results)
//          .popular(curated.popular)
//          .airportPickerStyle(.codeGrid)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the token
//  theme colors everything. ``AirportPickerPresentation`` stays orthogonal —
//  presentation ≠ style: the trigger, bottom sheet, popover and full-screen
//  cover machinery live in the component; styles only read the
//  ``AirportPickerConfiguration/isPresented`` signal to pin the search field
//  and scroll the sections inside a presented container.
//

import SwiftUI
import ThemeKit

// MARK: - Section model

/// One suggestion section the component built for the active style — typed,
/// pre-filtered (empty sections are never handed to a style), with the resolved
/// title (custom override or the localized stock string) and, for `.recent`,
/// the caller's clear action.
public struct AirportPickerSection: Identifiable {
    /// Which list this section carries; `.results` is the typed-query list.
    public enum Kind: Hashable, Sendable { case nearby, recent, popular, results }

    public let kind: Kind
    /// The resolved header title; `nil` for `.results` (no header today).
    public let title: String?
    public let airports: [Airport]
    /// The Clear action for `.recent`; `nil` elsewhere.
    public let onClear: (() -> Void)?

    public var id: Kind { kind }
}

// MARK: - Configuration

/// What an ``AirportPickerStyle`` arranges. Class B (ADR-0004 §2.2): the
/// interactive units arrive **pre-wired** — the search field already debounces
/// the caller's `onQueryChange`, rows/chips already select on tap with
/// read-only gating and VoiceOver labels — so a style composes them at any
/// granularity (whole ``sectionView``, or ``sectionHeader`` + ``row`` /
/// ``selectableChip``, or a fully custom label through ``selectableRow``)
/// without ever duplicating interaction logic.
public struct AirportPickerConfiguration {
    // MARK: Pre-wired units — fully interactive; styles arrange, never re-wire.

    /// The live search unit (the composed `SearchBar`): binding, placeholder,
    /// debounced `onQueryChange`, result-count announcement and read-only
    /// gating are wired by the component.
    public let searchField: AnyView
    /// What to show while the caller's lookup is in flight — the built-in
    /// Skeleton rows, or the caller's `.loadingContent { }` slot.
    public let loadingView: AnyView
    /// The typed-query-with-no-matches state — built-in, or `.emptyContent { }`.
    public let emptyView: AnyView

    // MARK: Arrangeable typed data.

    /// The sections to arrange, already resolved for the current query: the
    /// non-empty *nearby / recent / popular* lists before typing, or the single
    /// `.results` section while a query has suggestions. Never contains empty
    /// sections.
    public let sections: [AirportPickerSection]

    // MARK: Per-section / per-airport unit builders (wiring stays in the component).

    /// The full stock section — header (with Clear for `.recent`), rows,
    /// dividers and the results accessibility identifier. `.list` places these
    /// verbatim.
    public let sectionView: (AirportPickerSection) -> AnyView
    /// The section header alone (title + Clear button, header a11y trait);
    /// renders nothing when ``AirportPickerSection/title`` is `nil`.
    public let sectionHeader: (AirportPickerSection) -> AnyView
    /// The stock wired row: IATA chip + city/airport + selection checkmark
    /// (or the caller's `.rowContent` slot), tap-to-select, read-only gating
    /// and VoiceOver label/traits included.
    public let row: (Airport) -> AnyView
    /// Wraps a style-built label in the component's row wiring (tap → select,
    /// read-only gating, VoiceOver label + selected trait, row a11y id) — for
    /// styles that draw their own row anatomy, like `.compact`.
    public let selectableRow: (Airport, AnyView) -> AnyView
    /// The bold IATA code chip as a plain *visual* (chip variant + accent
    /// applied, no tap wiring) — compose it inside custom labels.
    public let codeChip: (Airport) -> AnyView
    /// The IATA code chip as a *wired* tappable unit (tap → select, selected
    /// accent ring, 44pt hit target, VoiceOver label/traits) — the `.codeGrid`
    /// cell, reusable by any chip-cloud style.
    public let selectableChip: (Airport) -> AnyView
    /// The caller's `.rowContent` slot bound to `(airport, isSelected)`;
    /// `nil` = not set. Styles that build their own labels should prefer this
    /// when present so the caller's replacement survives a style switch.
    public let customRowLabel: ((Airport) -> AnyView)?

    // MARK: Typed signals.

    /// The live query text (internal UI state owned by the component).
    public let query: String
    /// `true` while the caller's lookup is in flight — show ``loadingView``.
    public let isLoading: Bool
    /// `true` when a typed query produced no suggestions (and no lookup is in
    /// flight) — show ``emptyView``.
    public let showsEmptyState: Bool
    /// `true` when the search UI is hosted by a presented container (`.sheet`,
    /// `.popover`, `.fullScreenCover`) rather than embedded inline — built-ins
    /// pin the search field and scroll the sections in that case (the
    /// component's classic behaviour); inline pickers let the screen scroll.
    public let isPresented: Bool
    /// The controlled selection, if any.
    public let selection: Airport?
    /// Selects an airport: updates the binding, echoes the choice into the
    /// query and dismisses a presented container. Guards `.disabled` /
    /// `.readOnly` internally — safe to call from any custom item view.
    public let select: (Airport) -> Void
    /// The `.chipVariant(_:)` axis (`.soft` default) — already applied by
    /// ``codeChip``/``selectableChip``; exposed for styles drawing their own.
    public let chipVariant: FillVariant
    /// The `.accent(_:)` override; `nil` keeps the hero/neutral tokens —
    /// resolve via ``accentForeground(_:)``.
    public let accent: SemanticColor?
    /// The `.surface(_:)` override; `nil` (default) keeps the picker
    /// transparent so it rides its screen's background.
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale

    // MARK: Helpers.

    /// Whether this airport is the current selection.
    public func isSelected(_ airport: Airport) -> Bool { selection?.id == airport.id }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the picker.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The `accent(_:)` override's tint, else the theme's hero foreground —
    /// the value the stock checkmark and Clear button use.
    public func accentForeground(_ theme: Theme) -> Color { accent.map { theme.resolve($0).accent } ?? theme.foreground(.fgHero) }
}

// MARK: - Protocol

/// Defines an `AirportPicker`'s search-UI arrangement. Implement `makeBody` to
/// arrange the configuration's pre-wired units (search field, sections, rows,
/// chips). Set one with `.airportPickerStyle(_:)`; the default is
/// ``ListAirportPickerStyle``. Presentation is *not* part of a style — the
/// trigger + sheet/popover/cover machinery stay in the component.
public protocol AirportPickerStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: AirportPickerConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The scaffold every built-in shares: search field on top, the arranged list
/// below — scrolling under a pinned field inside presented containers (today's
/// behaviour), inline otherwise — over the optional `.surface(_:)` fill.
private struct AirportPickerScaffold<List: View>: View {
    @Environment(\.theme) private var theme
    let configuration: AirportPickerConfiguration
    @ViewBuilder let list: () -> List

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            configuration.searchField
            if configuration.isPresented {
                ScrollView { list() }
            } else {
                list()
            }
        }
        .background {
            if let key = configuration.surfaceKey { theme.background(key) }
        }
    }
}

// MARK: - .list

/// Today's ``AirportPicker`` look, verbatim: the search field over sectioned
/// suggestion rows — bold IATA code chip + city/airport text, hairline
/// dividers, *Nearby / Recent / Popular* headers before typing, the caller's
/// results while typing, Skeleton rows while loading.
public struct ListAirportPickerStyle: AirportPickerStyle {
    public init() {}
    public func makeBody(configuration: AirportPickerConfiguration) -> some View {
        AirportPickerScaffold(configuration: configuration) {
            ListAirportPickerSections(configuration: configuration)
        }
    }
}

private struct ListAirportPickerSections: View {
    let configuration: AirportPickerConfiguration

    var body: some View {
        if configuration.isLoading {
            configuration.loadingView
        } else if configuration.showsEmptyState {
            configuration.emptyView
        } else {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                ForEach(configuration.sections) { configuration.sectionView($0) }
            }
        }
    }
}

// MARK: - .compact

/// Dense rows for tight pickers — the promotion of the deprecated
/// `AirportPickerDensity.compact` knob: tighter row padding and section gaps,
/// and the airport-name subtitle hidden (IATA chip + city only). A caller's
/// `.rowContent` slot still replaces the row label.
public struct CompactAirportPickerStyle: AirportPickerStyle {
    public init() {}
    public func makeBody(configuration: AirportPickerConfiguration) -> some View {
        AirportPickerScaffold(configuration: configuration) {
            CompactAirportPickerSections(configuration: configuration)
        }
    }
}

private struct CompactAirportPickerSections: View {
    @Environment(\.theme) private var theme
    let configuration: AirportPickerConfiguration

    var body: some View {
        if configuration.isLoading {
            configuration.loadingView
        } else if configuration.showsEmptyState {
            configuration.emptyView
        } else {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                ForEach(configuration.sections) { compactSection($0) }
            }
        }
    }

    private func compactSection(_ section: AirportPickerSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.sectionHeader(section)
            ForEach(section.airports) { airport in
                compactRow(airport)
                if airport.id != section.airports.last?.id {
                    DividerView().size(.small).padding(.leading, configuration.spacing(.md))
                }
            }
        }
    }

    /// A style-built dense label handed back through the component's row
    /// wiring — tap, read-only gating and VoiceOver stay single-sourced.
    private func compactRow(_ airport: Airport) -> some View {
        configuration.selectableRow(airport, AnyView(
            compactLabel(airport)
                .padding(.horizontal, configuration.spacing(.md))
                .padding(.vertical, configuration.spacing(.xs))))
    }

    @ViewBuilder
    private func compactLabel(_ airport: Airport) -> some View {
        if let customRowLabel = configuration.customRowLabel {
            customRowLabel(airport)
        } else {
            HStack(spacing: configuration.spacing(.sm)) {
                configuration.codeChip(airport)
                Text(airport.city)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                Spacer(minLength: configuration.spacing(.xs))
                if configuration.isSelected(airport) {
                    Icon(systemName: "checkmark")
                        .size(.sm)
                        .color(configuration.accentForeground(theme))
                }
            }
        }
    }
}

// MARK: - .codeGrid

/// The browse sections (*nearby / recent / popular*) as an adaptive grid of
/// tappable IATA-code chips — a compact departure-board browse for screens
/// where codes carry the meaning. Typed results keep the full stock rows
/// (name + city matter while searching), as do loading and empty states.
public struct CodeGridAirportPickerStyle: AirportPickerStyle {
    public init() {}
    public func makeBody(configuration: AirportPickerConfiguration) -> some View {
        AirportPickerScaffold(configuration: configuration) {
            CodeGridAirportPickerSections(configuration: configuration)
        }
    }
}

private struct CodeGridAirportPickerSections: View {
    let configuration: AirportPickerConfiguration

    /// Genuine dimension with no semantic token — the adaptive grid cell's
    /// minimum width (fits a 3-letter IATA chip with breathing room).
    private static let chipCellMinWidth: CGFloat = 56

    var body: some View {
        if configuration.isLoading {
            configuration.loadingView
        } else if configuration.showsEmptyState {
            configuration.emptyView
        } else {
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                ForEach(configuration.sections) { section in
                    if section.kind == .results {
                        configuration.sectionView(section)
                    } else {
                        gridSection(section)
                    }
                }
            }
        }
    }

    private func gridSection(_ section: AirportPickerSection) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            configuration.sectionHeader(section)
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: Self.chipCellMinWidth),
                                   spacing: configuration.spacing(.xs))],
                alignment: .leading,
                spacing: configuration.spacing(.xs)
            ) {
                ForEach(section.airports) { configuration.selectableChip($0) }
            }
            .padding(.horizontal, configuration.spacing(.md))
            .padding(.vertical, configuration.spacing(.xs))
        }
    }
}

// MARK: - Static accessors

public extension AirportPickerStyle where Self == ListAirportPickerStyle {
    /// The sectioned suggestion list — IATA chip + city/airport rows. The default.
    static var list: ListAirportPickerStyle { ListAirportPickerStyle() }
}
public extension AirportPickerStyle where Self == CompactAirportPickerStyle {
    /// Dense rows: tight padding, airport-name subtitle hidden.
    static var compact: CompactAirportPickerStyle { CompactAirportPickerStyle() }
}
public extension AirportPickerStyle where Self == CodeGridAirportPickerStyle {
    /// Browse sections as a tappable IATA-code chip grid; results keep rows.
    static var codeGrid: CodeGridAirportPickerStyle { CodeGridAirportPickerStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyAirportPickerStyle: AirportPickerStyle {
    private let _makeBody: @MainActor (AirportPickerConfiguration) -> AnyView
    init<S: AirportPickerStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: AirportPickerConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct AirportPickerStyleKey: EnvironmentKey {
    static let defaultValue = AnyAirportPickerStyle(ListAirportPickerStyle())
}

extension EnvironmentValues {
    var airportPickerStyle: AnyAirportPickerStyle {
        get { self[AirportPickerStyleKey.self] }
        set { self[AirportPickerStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``AirportPickerStyle`` for `AirportPicker`s in this view and its
    /// descendants — origin and destination pickers restyle together. The
    /// deprecated `.density(_:)` modifier, when explicitly set, wins over this
    /// environment style (ADR-0004 §5 source-behaviour stability).
    func airportPickerStyle<S: AirportPickerStyle>(_ style: sending S) -> some View {
        environment(\.airportPickerStyle, AnyAirportPickerStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: sections first with a departure glyph per row, the search field
/// pinned *below* the list. Proves the pre-wired units arrange freely.
private struct SearchLastAirportPickerStyle: AirportPickerStyle {
    func makeBody(configuration: AirportPickerConfiguration) -> some View {
        SearchLastChrome(configuration: configuration)
    }

    private struct SearchLastChrome: View {
        @Environment(\.theme) private var theme
        let configuration: AirportPickerConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                if configuration.isLoading {
                    configuration.loadingView
                } else if configuration.showsEmptyState {
                    configuration.emptyView
                } else {
                    ForEach(configuration.sections) { section in
                        configuration.sectionHeader(section)
                        ForEach(section.airports) { airport in
                            configuration.selectableRow(airport, AnyView(label(airport)))
                        }
                    }
                }
                configuration.searchField
            }
        }

        private func label(_ airport: Airport) -> some View {
            HStack(spacing: configuration.spacing(.sm)) {
                Icon(systemName: "airplane.departure")
                    .size(.sm)
                    .color(configuration.accentForeground(theme))
                Text("\(airport.city) · \(airport.code)")
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                Spacer()
                if configuration.isSelected(airport) {
                    Icon(systemName: "checkmark").size(.sm).color(configuration.accentForeground(theme))
                }
            }
            .padding(.horizontal, configuration.spacing(.md))
            .padding(.vertical, configuration.spacing(.xs))
        }
    }
}

private let styleAirports: [Airport] = [
    Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR"),
    Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB"),
    Airport(code: "LGW", name: "Gatwick Airport", city: "London", countryCode: "GB"),
    Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US"),
    Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR"),
    Airport(code: "AMS", name: "Schiphol Airport", city: "Amsterdam", countryCode: "NL"),
]

#Preview("AirportPickerStyle — presets × light/dark") {
    let browse = AirportPicker(selection: .constant(styleAirports[0]), suggestions: [])
        .nearby([styleAirports[5]])
        .recent([styleAirports[1], styleAirports[3]], onClear: { })
        .popular([styleAirports[0], styleAirports[4]])
    let results = AirportPicker(selection: .constant(styleAirports[1]),
                                suggestions: [styleAirports[1], styleAirports[2]])
        .seedQuery("Lon")
    return PreviewMatrix("AirportPickerStyle", rtl: true) {
        PreviewCase("List (default)") { browse }
        PreviewCase("List · results") { results }
        PreviewCase("Compact") { browse.airportPickerStyle(.compact) }
        PreviewCase("Compact · results") { results.airportPickerStyle(.compact) }
        PreviewCase("Code grid") { browse.airportPickerStyle(.codeGrid) }
        PreviewCase("Code grid · accent + solid chips") {
            browse.chipVariant(.solid).accent(.info).airportPickerStyle(.codeGrid)
        }
        PreviewCase("Custom (in-preview)") { browse.airportPickerStyle(SearchLastAirportPickerStyle()) }
    }
}
