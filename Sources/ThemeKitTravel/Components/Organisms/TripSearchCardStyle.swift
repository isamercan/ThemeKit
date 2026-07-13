//
//  TripSearchCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``TripSearchCard`` — the Class B exemplar of ADR-0004
//  (per-component style protocols). Unlike Class A (typed data the style lays
//  out itself), this component owns *live interactive controls* — the draft
//  binding, the airport-picker and passenger sheets, the swap spin, the
//  compact expansion — so the configuration hands styles **pre-wired,
//  type-erased field units** plus typed read-only signals. Styles ARRANGE the
//  units; they never re-wire them. Five built-ins:
//
//    .card       the stacked editor — today's card. Default.
//    .hero       larger treatment for landing headers: `.lg` padding, elevated
//                shell, large CTA.
//    .compact    a collapsed summary row that expands into the editor on tap.
//    .inlineBar  one horizontal run for wide/iPad headers; narrow widths fall
//                back to the stacked editor via `ViewThatFits`.
//    .pill       a floating capsule showing the route summary that expands
//                into the editor (Airbnb/Skyscanner home header).
//
//      TripSearchCard(draft: $draft) { search($0) }
//          .airports(suggestions: results)
//          .tripSearchCardStyle(.pill)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints *chrome* (card-shaped presets keep composing the neutral
//  `Card`, so `.cardStyle(_:)` still re-chromes them); the token theme colors
//  everything. Motion is resolved in the component (`MicroMotion` ∧ ¬Reduce
//  Motion): ``TripSearchCardConfiguration/toggleExpand`` is already animation-
//  gated, and the expansion/trip-type animations ride on the component's own
//  `.animation(_:value:)` — styles never read the motion environment.
//
//  Unit granularity (ADR-0004 §9.2): the route unit ships *welded*
//  (origin + swap + destination, accessibility-size fallback inside). Note for
//  custom one-row styles: nesting the welded unit's own `ViewThatFits` inside
//  another `ViewThatFits` row can settle on the stacked route arrangement
//  instead of rejecting the row — a graceful degradation, audited under
//  ADR-0004 §9.4. Splitting the unit later is additive.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The pre-wired inputs a ``TripSearchCardStyle`` arranges. The `AnyView`
/// fields are fully interactive units built by the component (bindings,
/// sheets and callbacks included) — place them, never rebuild them. The typed
/// fields are read-only signals for arrangement decisions; the component's
/// `@State` (expansion, sheets, swap spin) never leaves the component.
public struct TripSearchCardConfiguration {
    // Pre-wired field units — fully interactive; styles arrange, never re-wire.
    /// The ``TripTypeToggle`` bound to the draft; `nil` when the caller hid it
    /// with `showsTripType(false)`.
    public let tripType: AnyView?
    /// Origin + swap + destination — the accessibility-size fallback (stacked
    /// fields with a floating swap) lives *inside* the unit.
    public let routeFields: AnyView
    /// Departure date (+ the animated return date for round trips).
    public let dateFields: AnyView
    /// The passengers `FieldButton` and its `GuestSelector` bottom sheet.
    public let passengersField: AnyView
    /// The labeled ``CabinClassSelector`` section; `nil` when the caller hid
    /// it with `showsCabinPicker(false)`.
    public let cabinField: AnyView?
    /// The completeness-disabled submit control — full width, standard size
    /// (the stacked editor's CTA). Custom `.ctaLabel { }` content is already
    /// wired in.
    public let cta: AnyView
    /// The submit control at large size, full width — hero treatments.
    public let heroCta: AnyView
    /// The submit control hugging its content — single-row runs.
    public let inlineCta: AnyView
    /// Header slot above the editor (`.header { }`); `nil` = none.
    public let header: AnyView?
    /// Promo slot under the CTA (`.promo { }`); `nil` = none.
    public let promo: AnyView?
    /// Footer slot below the editor and promo (`.footer { }`); `nil` = none.
    public let footer: AnyView?

    // Typed signals for arrangement decisions.
    /// A read-only snapshot of the bound draft — for summaries and emphasis
    /// only; mutate it exclusively through the pre-wired units.
    public let draft: TripSearchDraft
    /// `true` when the draft can be submitted (route + dates chosen). The CTA
    /// units already disable themselves — this is for layout decisions.
    public let isDraftComplete: Bool
    /// Collapsed styles (`.compact`, `.pill`) read this…
    public let isExpanded: Bool
    /// …and flip it. Already `MicroMotion`-gated in the component — call it
    /// directly, never wrap it in `withAnimation`.
    public let toggleExpand: () -> Void
    /// Semantic tint (`accent(_:)`), or `nil` for the theme's hero chroma —
    /// resolve via ``accentFill(_:)`` / ``accentOnFill(_:)``.
    public let accent: SemanticColor?
    /// Explicit surface fill (`surface(_:)`), or `nil` to let the style choose
    /// its default (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Explicit shell elevation (`elevation(_:)`), or `nil` to let the style
    /// choose (`.card` uses `.soft`, `.hero`/`.pill` lift to `.elevated`).
    public let elevation: CardElevation?
    /// The editor-density axis (`density(_:)`) — resolve gaps via ``stackSpacing``.
    public let editorDensity: TripSearchDensity
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The vertical gap between editor rows, resolved from the editor-density
    /// axis (token-fed: `.compact` → `sm`, `.regular` → `md`).
    public var stackSpacing: CGFloat {
        editorDensity == .compact ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value
    }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the card.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    // Accent resolution — the `accent(_:)` override, else the theme's hero
    // tokens (mirrors the FlightListItemConfiguration convention).
    /// Emphasized fill (the pill's search glyph disc).
    public func accentFill(_ theme: Theme) -> Color { accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero) }
    /// Content color on top of ``accentFill(_:)``.
    public func accentOnFill(_ theme: Theme) -> Color { accent.map { theme.resolve($0).onSolid } ?? theme.foreground(.fgSecondary) }

    // Shared summaries, so collapsed styles speak one language.
    /// "Istanbul (IST) – London (LHR)" — an en dash, not an arrow, so the
    /// string stays direction-neutral under RTL. Falls back to "Where to?"
    /// while the route is incomplete.
    public func routeSummary() -> String {
        guard let origin = draft.origin, let destination = draft.destination else {
            return String(themeKitTravel: "Where to?")
        }
        return "\(AirportPicker.displayText(origin)) – \(AirportPicker.displayText(destination))"
    }

    /// "Jan 5 – Jan 12 · 2 travelers · Economy" — captured-locale formatting.
    public func detailSummary() -> String {
        var parts: [String] = []
        if let departure = draft.departureDate {
            var dates = shortDate(departure)
            if draft.tripType == .roundTrip, let ret = draft.returnDate {
                dates += " – " + shortDate(ret)
            }
            parts.append(dates)
        }
        let travelers = draft.passengers.total
        parts.append(travelers == 1
            ? String(themeKitTravel: "1 traveler")
            : String(themeKitTravel: "\(travelers) travelers"))
        parts.append(draft.cabin.label)
        return parts.joined(separator: " · ")
    }

    /// An abbreviated captured-locale date ("Jan 5").
    public func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale))
    }
}

// MARK: - Protocol

/// Defines a `TripSearchCard`'s entire presentation. Implement `makeBody` to
/// arrange the configuration's pre-wired field units. Set one with
/// `.tripSearchCardStyle(_:)`; the default is ``CardTripSearchCardStyle``.
public protocol TripSearchCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: TripSearchCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The stacked editor column every card-shaped built-in shares — today's
/// `editorStack`, arranged from the pre-wired units verbatim.
private struct TripSearchEditorStack: View {
    let configuration: TripSearchCardConfiguration
    /// `true` swaps the standard CTA for the large hero CTA.
    var isProminent = false

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.stackSpacing) {
            if let tripType = configuration.tripType { tripType }
            configuration.routeFields
            configuration.dateFields
            configuration.passengersField
            if let cabinField = configuration.cabinField { cabinField }
            if isProminent { configuration.heroCta } else { configuration.cta }
        }
    }
}

/// Header → editor → promo → footer — today's expanded `cardBody`, verbatim.
private struct TripSearchEditorBody: View {
    let configuration: TripSearchCardConfiguration
    var isProminent = false
    /// Collapsing styles pin a trailing chevron-up above the editor.
    var showsCollapseHeader = false

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.stackSpacing) {
            if showsCollapseHeader { TripSearchCollapseHeader(configuration: configuration) }
            if let header = configuration.header { header }
            TripSearchEditorStack(configuration: configuration, isProminent: isProminent)
            if let promo = configuration.promo { promo }
            if let footer = configuration.footer { footer }
        }
    }
}

/// The collapsed one-line summary (`.compact`, and `.pill` with capsule
/// chrome): magnifier, route + detail summaries, an expand affordance. The tap
/// calls the component-gated ``TripSearchCardConfiguration/toggleExpand``.
private struct TripSearchSummaryRow: View {
    @Environment(\.theme) private var theme
    let configuration: TripSearchCardConfiguration
    /// `.pill` swaps the trailing chevron for an accent search disc and draws
    /// its own capsule chrome around the row.
    var isPill = false

    var body: some View {
        Button(action: configuration.toggleExpand) {
            if isPill {
                row
                    .padding(.vertical, Theme.SpacingKey.sm.value)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .background(theme.background(configuration.surface(default: .bgWhite)),
                                in: Capsule(style: .continuous))
                    .overlay(Capsule(style: .continuous).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
                    .contentShape(Capsule(style: .continuous))
            } else {
                row.contentShape(Rectangle())
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKitTravel: "Edit search"))
        .accessibilityValue("\(configuration.routeSummary()), \(configuration.detailSummary())")
        .accessibilityAddTraits(.isButton)
    }

    private var row: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: "magnifyingglass")
                .size(.sm)
                .color(theme.text(.textTertiary))
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.routeSummary())
                    .textStyle(.labelBase600)
                    .foregroundStyle(configuration.draft.origin == nil
                        ? theme.text(.textTertiary)
                        : theme.text(.textPrimary))
                let detail = configuration.detailSummary()
                if !detail.isEmpty {
                    Text(detail)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            .lineLimit(1)
            Spacer(minLength: Theme.SpacingKey.xs.value)
            if isPill {
                Icon(systemName: "magnifyingglass")
                    .size(.sm)
                    .color(configuration.accentOnFill(theme))
                    .padding(Theme.SpacingKey.xs.value)
                    .background(configuration.accentFill(theme), in: Circle())
            } else {
                Icon(systemName: "chevron.down")
                    .size(.sm)
                    .color(theme.text(.textTertiary))
            }
        }
    }
}

/// The trailing chevron-up that collapses an expanded editor back to its
/// summary (`.compact` expanded, `.pill` expanded).
private struct TripSearchCollapseHeader: View {
    @Environment(\.theme) private var theme
    let configuration: TripSearchCardConfiguration

    var body: some View {
        HStack {
            Spacer()
            Button(action: configuration.toggleExpand) {
                Icon(systemName: "chevron.up")
                    .size(.sm)
                    .color(theme.text(.textTertiary))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKitTravel: "Collapse search"))
        }
    }
}

// MARK: - .card (default)

/// Today's stacked editor, extracted verbatim: trip type, route, dates,
/// passengers, cabin and a full-width CTA inside the neutral `Card`
/// (`.md` padding, `.soft` elevation unless overridden).
public struct CardTripSearchCardStyle: TripSearchCardStyle {
    public init() {}
    public func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        Card { TripSearchEditorBody(configuration: configuration) }
            .contentPadding(.md)
            .elevation(configuration.elevation ?? .soft)
            .surface(configuration.surface(default: .bgWhite))
    }
}

// MARK: - .hero

/// The landing-header treatment: the same stacked editor with `.lg` padding,
/// an `.elevated` shell (unless overridden) and the large CTA.
public struct HeroTripSearchCardStyle: TripSearchCardStyle {
    public init() {}
    public func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        Card { TripSearchEditorBody(configuration: configuration, isProminent: true) }
            .contentPadding(.lg)
            .elevation(configuration.elevation ?? .elevated)
            .surface(configuration.surface(default: .bgWhite))
    }
}

// MARK: - .compact

/// A collapsed summary row ("IST – LHR · dates · travelers") that expands into
/// the full editor on tap — `isExpanded`/`toggleExpand` drive the flip; the
/// expansion animation is the component's (`MicroMotion`-gated).
public struct CompactTripSearchCardStyle: TripSearchCardStyle {
    public init() {}
    public func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        Card {
            if configuration.isExpanded {
                TripSearchEditorBody(configuration: configuration, showsCollapseHeader: true)
            } else {
                TripSearchSummaryRow(configuration: configuration)
            }
        }
        .contentPadding(.md)
        .elevation(configuration.elevation ?? .soft)
        .surface(configuration.surface(default: .bgWhite))
    }
}

// MARK: - .inlineBar

/// One horizontal run of the core units — route, dates, passengers, CTA — for
/// wide/iPad headers. When the row can't fit (narrow widths, accessibility
/// type sizes) `ViewThatFits` falls back to the stacked editor — nothing is
/// ever clipped. Trip type and cabin stay draft-driven (no room in one row).
public struct InlineBarTripSearchCardStyle: TripSearchCardStyle {
    public init() {}
    public func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        Card {
            VStack(alignment: .leading, spacing: configuration.stackSpacing) {
                if let header = configuration.header { header }
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                        configuration.routeFields
                        configuration.dateFields
                        configuration.passengersField
                        configuration.inlineCta
                    }
                    TripSearchEditorStack(configuration: configuration)
                }
                if let promo = configuration.promo { promo }
                if let footer = configuration.footer { footer }
            }
        }
        .contentPadding(.md)
        .elevation(configuration.elevation ?? .soft)
        .surface(configuration.surface(default: .bgWhite))
    }
}

// MARK: - .pill

/// The floating home-header capsule (Airbnb/Skyscanner): a route-summary pill
/// with an accent search disc that expands into the full editor on an
/// elevated card. Collapse it back with the chevron; both flips ride
/// `isExpanded`/`toggleExpand` (component-gated motion).
public struct PillTripSearchCardStyle: TripSearchCardStyle {
    public init() {}
    public func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        PillTripSearchChrome(configuration: configuration)
    }
}

private struct PillTripSearchChrome: View {
    let configuration: TripSearchCardConfiguration

    var body: some View {
        if configuration.isExpanded {
            Card { TripSearchEditorBody(configuration: configuration, showsCollapseHeader: true) }
                .contentPadding(.md)
                .elevation(configuration.elevation ?? .elevated)
                .surface(configuration.surface(default: .bgWhite))
        } else {
            TripSearchSummaryRow(configuration: configuration, isPill: true)
        }
    }
}

// MARK: - Static accessors

public extension TripSearchCardStyle where Self == CardTripSearchCardStyle {
    /// The stacked editor — today's card. The default.
    static var card: CardTripSearchCardStyle { CardTripSearchCardStyle() }
}
public extension TripSearchCardStyle where Self == HeroTripSearchCardStyle {
    /// Landing-header treatment: `.lg` padding, elevated shell, large CTA.
    static var hero: HeroTripSearchCardStyle { HeroTripSearchCardStyle() }
}
public extension TripSearchCardStyle where Self == CompactTripSearchCardStyle {
    /// Collapsed summary row that expands into the editor on tap.
    static var compact: CompactTripSearchCardStyle { CompactTripSearchCardStyle() }
}
public extension TripSearchCardStyle where Self == InlineBarTripSearchCardStyle {
    /// One-row run for wide/iPad headers; stacks when it can't fit.
    static var inlineBar: InlineBarTripSearchCardStyle { InlineBarTripSearchCardStyle() }
}
public extension TripSearchCardStyle where Self == PillTripSearchCardStyle {
    /// Floating route-summary capsule that expands into the editor
    /// (Airbnb/Skyscanner home header).
    static var pill: PillTripSearchCardStyle { PillTripSearchCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyTripSearchCardStyle: TripSearchCardStyle {
    private let _makeBody: @MainActor (TripSearchCardConfiguration) -> AnyView
    init<S: TripSearchCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: TripSearchCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct TripSearchCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyTripSearchCardStyle(CardTripSearchCardStyle())
}

extension EnvironmentValues {
    var tripSearchCardStyle: AnyTripSearchCardStyle {
        get { self[TripSearchCardStyleKey.self] }
        set { self[TripSearchCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``TripSearchCardStyle`` for `TripSearchCard`s in this view and
    /// its descendants — a home screen can run the `.pill` header while a
    /// results screen keeps the `.compact` editor.
    func tripSearchCardStyle<S: TripSearchCardStyle>(_ style: sending S) -> some View {
        environment(\.tripSearchCardStyle, AnyTripSearchCardStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a soft banner panel arranging only the route, dates and CTA, with
/// the route summary as its headline. Proves external implementability.
private struct BannerTripSearchCardStyle: TripSearchCardStyle {
    func makeBody(configuration: TripSearchCardConfiguration) -> some View {
        BannerChrome(configuration: configuration)
    }

    private struct BannerChrome: View {
        @Environment(\.theme) private var theme
        let configuration: TripSearchCardConfiguration

        var body: some View {
            VStack(alignment: .leading, spacing: configuration.stackSpacing) {
                Text(configuration.routeSummary())
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                configuration.routeFields
                configuration.dateFields
                configuration.cta
            }
            .padding(configuration.spacing(.md))
            .background(theme.background(.bgSecondaryLight),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        }
    }
}

/// Preview-only harness: owns the `@State` draft each interactive case binds to.
private struct TripSearchStyleHarness<Content: View>: View {
    @State private var draft: TripSearchDraft
    private let content: (Binding<TripSearchDraft>) -> Content

    init(_ draft: TripSearchDraft, @ViewBuilder content: @escaping (Binding<TripSearchDraft>) -> Content) {
        self._draft = State(initialValue: draft)
        self.content = content
    }

    var body: some View { content($draft) }
}

private func styleDraft(roundTrip: Bool = true) -> TripSearchDraft {
    var draft = TripSearchDraft()
    draft.tripType = roundTrip ? .roundTrip : .oneWay
    draft.origin = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
    draft.destination = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
    draft.departureDate = Calendar.current.date(byAdding: .day, value: 7, to: .now)
    draft.returnDate = Calendar.current.date(byAdding: .day, value: 14, to: .now)
    draft.passengers = PassengerCount(adults: 2)
    return draft
}

#Preview("TripSearchCardStyle — presets × light/dark") {
    PreviewMatrix("TripSearchCardStyle") {
        PreviewCase(".card (default)") {
            TripSearchStyleHarness(styleDraft()) { TripSearchCard(draft: $0) { _ in } }
        }
        PreviewCase(".hero") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.hero)
            }
        }
        PreviewCase(".compact — collapsed") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.compact)
            }
        }
        PreviewCase(".compact — expanded") {
            TripSearchStyleHarness(styleDraft(roundTrip: false)) {
                TripSearchCard(draft: $0) { _ in }.seedExpanded().tripSearchCardStyle(.compact)
            }
        }
        PreviewCase(".inlineBar (stacks when narrow)") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.inlineBar)
            }
        }
        PreviewCase(".pill — collapsed") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.pill)
            }
        }
        PreviewCase(".pill — collapsed · accent · empty draft") {
            TripSearchStyleHarness(TripSearchDraft()) {
                TripSearchCard(draft: $0) { _ in }.accent(.success).tripSearchCardStyle(.pill)
            }
        }
        PreviewCase(".pill — expanded") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.seedExpanded().tripSearchCardStyle(.pill)
            }
        }
        PreviewCase("Custom (in-preview)") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(BannerTripSearchCardStyle())
            }
        }
    }
}

#Preview("Collapsing presets — XL type / RTL") {
    PreviewMatrix("TripSearchCard — .compact & .pill", schemes: [.light], dynamicType: true, rtl: true) {
        PreviewCase(".compact") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.compact)
            }
        }
        PreviewCase(".pill") {
            TripSearchStyleHarness(styleDraft()) {
                TripSearchCard(draft: $0) { _ in }.tripSearchCardStyle(.pill)
            }
        }
    }
}
