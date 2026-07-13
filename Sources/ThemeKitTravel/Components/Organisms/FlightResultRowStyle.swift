//
//  FlightResultRowStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightResultRow`` (ADR-0004, Wave 1 — Class A). The
//  configuration hands styles the row's *typed flight data* (legs, price, save
//  state, meta chips), not pre-laid content, so a style owns the entire layout.
//  Law: component style arranges content; shell style (`CardStyle`) paints
//  chrome; token theme colors everything.
//
//    .row      identity / route / price+CTA columns — the default, today's look
//    .stacked  identity above a full-width route, price row below (narrow widths)
//    .minimal  no Select button — the whole row is the tap target, trailing chevron
//
//      FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB",
//                      departure: dep, arrival: arr)
//          .price(2_899).onSelect { }
//          .flightResultRowStyle(.minimal)
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightResultRowStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no price → no price column, no meta → no meta row).
public struct FlightResultRowConfiguration {
    /// The airline display name (identity block headline).
    public let airline: String
    /// All legs in render order — `legs[0]` is the outbound (built from the
    /// component's init), the rest come from `returnLeg(...)`/`addLeg(_:)`.
    public let legs: [FlightLeg]
    public let flightNo: String?
    public let cabin: String?
    /// The fallback airline SF Symbol, tinted with ``accentForeground(_:)``.
    public let airlineSystemImage: String
    /// A remote airline logo — when set it replaces `airlineSystemImage`.
    public let airlineLogoURL: URL?
    public let priceAmount: Decimal?
    /// Resolved currency code — explicit `price(_:currencyCode:)` →
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"`.
    public let currencyCode: String
    public let priceFractionDigits: Int
    /// Secondary total-price line under the fare (`totalPrice(_:label:)`) —
    /// render via ``totalLine()`` so all styles format it identically.
    public let totalAmount: Decimal?
    public let totalLabel: String?
    /// Baggage chip text, e.g. "15 kg".
    public let baggage: String?
    public let badge: String?
    public let badgeStyle: BadgeStyle
    /// Urgency note shown in error red, e.g. "5 seats left!".
    public let urgencyText: String?
    /// Selected state — card-shaped styles feed it to the `CardStyle` shell.
    public let isSelected: Bool
    /// Read-only surfaces disable the save toggles and the `.minimal` row tap.
    public let isReadOnly: Bool
    /// Shell elevation for card-shaped styles (default `.none` — flat, hairline).
    public let elevation: CardElevation
    /// Favourite state — `nil` means no heart was requested (styles render no
    /// heart and reserve no space). Set by ``FlightResultRow/favorite()`` /
    /// ``FlightResultRow/favorite(_:)``.
    public let isFavorite: Bool?
    /// Flips `isFavorite`. Styles with a heart call this.
    public let toggleFavorite: (() -> Void)?
    /// Bookmark (save) state — `nil` means no bookmark was requested.
    public let isBookmarked: Bool?
    /// Flips `isBookmarked`. Styles with a bookmark call this.
    public let toggleBookmark: (() -> Void)?
    /// The resolved driver for the heart's bounce `symbolEffect` — equals the
    /// favourite flag while micro-animations are on and Reduce Motion is off,
    /// constant `false` otherwise. Motion is resolved by the *component*
    /// (ADR-0004 §4); styles must never read the motion environment themselves.
    public let favoriteBounceValue: Bool
    public let selectTitle: String
    /// The Select action. `.row`/`.stacked` render it as a button; `.minimal`
    /// makes the whole row the tap target.
    public let onSelect: (() -> Void)?
    public let detailsTitle: String
    /// Secondary "open details" action — styles with a details affordance show it.
    public let onDetails: (() -> Void)?
    /// Optional replacement for the style's meta row (`.footer { }`).
    public let footer: AnyView?
    /// Optional replacement for the style's price/action area (`.trailing { }`).
    public let trailing: AnyView?
    /// Brand-chrome accent (`.accent(_:)`), or `nil` for the theme's hero
    /// tokens — resolve via ``accentForeground(_:)``.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The outbound leg — every style's primary subject.
    public var leg: FlightLeg { legs[0] }
    /// Return/multi-city legs stacked after the outbound (may be empty).
    public var extraLegs: [FlightLeg] { Array(legs.dropFirst()) }
    /// Stops on the outbound leg (0 = direct).
    public var stops: Int { leg.stops }
    /// Whether any of badge / baggage / urgency is present (the meta chips).
    public var hasMetaContent: Bool { badge != nil || baggage != nil || urgencyText != nil }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the row.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The brand-chrome tint: the `accent(_:)` override's base, else the theme's
    /// hero foreground — `nil` reproduces the classic rendering exactly.
    public func accentForeground(_ theme: Theme) -> Color { accent.map { theme.resolve($0).base } ?? theme.foreground(.fgHero) }

    /// Whether a leg lands on a different calendar day than it departs
    /// (feeds ``FlightRoute/nextDay(_:)``).
    public func crossesMidnight(_ leg: FlightLeg) -> Bool {
        !Calendar.current.isDate(leg.departure, inSameDayAs: leg.arrival)
    }

    /// The formatted total-price line ("3 travellers: 43.068 TL"), or `nil`
    /// when no total was set — whole-number currency in the captured locale.
    public func totalLine() -> String? {
        guard let totalLabel, let totalAmount else { return nil }
        let amount = totalAmount.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale))
        return "\(totalLabel): \(amount)"
    }
}

// MARK: - Protocol

/// Defines a `FlightResultRow`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's flight data. Set one with
/// `.flightResultRowStyle(_:)`; the default is ``RowFlightResultRowStyle``.
public protocol FlightResultRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightResultRowConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The `CardStyle` shell gate — fill, corner clipping and hairline border are
/// drawn by the active `CardStyle` from the environment, so `.cardStyle(_:)`
/// keeps swapping the chrome under every card-shaped preset (ADR-0004 §6).
private struct ResultRowShell: View {
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FlightResultRowConfiguration
    let content: AnyView

    var body: some View {
        // `.none` matches the classic chrome: no shadow, hairline border.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: content,
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
    }
}

/// Airline identity: logo (remote or SF-Symbol fallback) + name/flight-no/cabin.
private struct ResultIdentityBlock: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        HStack(spacing: 6) {
            if let url = configuration.airlineLogoURL {
                RemoteImage(url).ratio(1).frame(width: 22, height: 22)
            } else {
                Image(systemName: configuration.airlineSystemImage).font(.title3)
                    .foregroundStyle(configuration.accentForeground(theme))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(configuration.airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let flightNo = configuration.flightNo {
                    Text(flightNo).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
                }
                if let cabin = configuration.cabin {
                    Text(cabin).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
    }
}

/// The outbound `FlightRoute` plus any return/multi-city legs, stacked.
private struct ResultRouteColumn: View {
    let configuration: FlightResultRowConfiguration

    var body: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            FlightRoute(from: configuration.leg.origin, to: configuration.leg.destination,
                        departure: configuration.leg.departure, arrival: configuration.leg.arrival)
                .stops(configuration.stops).nextDay(configuration.crossesMidnight(configuration.leg))
            ForEach(configuration.extraLegs) { leg in
                FlightRoute(from: leg.origin, to: leg.destination, departure: leg.departure, arrival: leg.arrival)
                    .stops(leg.stops).nextDay(configuration.crossesMidnight(leg))
            }
        }
    }
}

/// The bookmark + heart toggle pair — renders nothing when neither was requested.
private struct ResultSaveToggles: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        if configuration.isBookmarked != nil || configuration.isFavorite != nil {
            HStack(spacing: 6) {
                if let isBookmarked = configuration.isBookmarked {
                    Button { configuration.toggleBookmark?() } label: {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 14))
                            .foregroundStyle(isBookmarked ? configuration.accentForeground(theme) : theme.text(.textTertiary))
                            .frame(width: 40, height: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(configuration.isReadOnly)
                        .accessibilityLabel(isBookmarked ? String(themeKit: "Remove saved flight") : String(themeKit: "Save"))
                }
                if let isFavorite = configuration.isFavorite {
                    Button { configuration.toggleFavorite?() } label: {
                        Image(systemName: isFavorite ? "heart.fill" : "heart")
                            .foregroundStyle(isFavorite ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                            .symbolEffect(.bounce, value: configuration.favoriteBounceValue)
                            .frame(width: 40, height: 40).contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(configuration.isReadOnly)
                        .accessibilityLabel(isFavorite ? String(themeKit: "Remove from favourites") : String(themeKit: "Add to favourites"))
                }
            }
        }
    }
}

/// The Select CTA — accent set → semantic-colored button; nil → the button's
/// stock resolution (componentDefaults.accent → .primary), unchanged.
private struct ResultSelectButton: View {
    let configuration: FlightResultRowConfiguration
    let action: () -> Void

    var body: some View {
        if let accent = configuration.accent {
            ThemeButton(configuration.selectTitle) { action() }.color(accent).size(.small)
        } else {
            ThemeButton(configuration.selectTitle) { action() }.size(.small)
        }
    }
}

/// The classic trailing column: save toggles over the fare, total line, Select.
private struct ResultPriceStack: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            ResultSaveToggles(configuration: configuration)
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode)
                    .emphasis(.hero).fractionDigits(configuration.priceFractionDigits)
            }
            if let totalLine = configuration.totalLine() {
                Text(totalLine).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).fixedSize()
            }
            if let onSelect = configuration.onSelect {
                ResultSelectButton(configuration: configuration, action: onSelect)
            }
        }
    }
}

/// The meta row: badge / baggage / urgency chips leading, Details link trailing.
private struct ResultMetaRow: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration
    var showsDetailsLink = true

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let badge = configuration.badge {
                Badge(badge).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small)
            }
            if let baggage = configuration.baggage {
                HStack(spacing: 3) {
                    Image(systemName: "suitcase.fill").font(.system(size: 11))
                        .accessibilityHidden(true)   // decorative; the baggage text carries the meaning
                    Text(baggage).textStyle(.overline500)
                }.foregroundStyle(theme.text(.textTertiary))
            }
            if let urgencyText = configuration.urgencyText {
                Text(urgencyText).textStyle(.overline500).foregroundStyle(theme.foreground(.systemcolorsFgError))
            }
            Spacer()
            if showsDetailsLink, let onDetails = configuration.onDetails {
                TextLink(configuration.detailsTitle) { onDetails() }
            }
        }
    }
}

// MARK: - .row (default — the classic three-column result row)

/// Identity / route / price+CTA columns with a meta row underneath — the
/// classic search-result row and the default. Today's look, verbatim.
public struct RowFlightResultRowStyle: FlightResultRowStyle {
    public init() {}
    public func makeBody(configuration: FlightResultRowConfiguration) -> some View {
        RowChrome(configuration: configuration)
    }
}

private struct RowChrome: View {
    let configuration: FlightResultRowConfiguration

    var body: some View {
        ResultRowShell(configuration: configuration, content: AnyView(rowContent))
    }

    /// The row's inner layout — everything inside the shell.
    private var rowContent: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            HStack(alignment: .center, spacing: configuration.spacing(.sm)) {
                ResultIdentityBlock(configuration: configuration).frame(width: 92, alignment: .leading)
                ResultRouteColumn(configuration: configuration).frame(maxWidth: .infinity)
                Group {
                    if let trailing = configuration.trailing { trailing } else { ResultPriceStack(configuration: configuration) }
                }
                .frame(minWidth: 84, alignment: .trailing)
            }
            if let footer = configuration.footer {
                footer
            } else if configuration.hasMetaContent || configuration.onDetails != nil {
                ResultMetaRow(configuration: configuration)
            }
        }
        .padding(configuration.spacing(.md))
    }
}

// MARK: - .stacked (identity above the route — narrow widths)

/// Identity row on top (save toggles trailing), the route full-width beneath,
/// then a price + Select row — trades height for horizontal room, for narrow
/// or split-view result lists.
public struct StackedFlightResultRowStyle: FlightResultRowStyle {
    public init() {}
    public func makeBody(configuration: FlightResultRowConfiguration) -> some View {
        StackedChrome(configuration: configuration)
    }
}

private struct StackedChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        ResultRowShell(configuration: configuration, content: AnyView(stackedContent))
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            HStack(alignment: .center, spacing: configuration.spacing(.sm)) {
                ResultIdentityBlock(configuration: configuration)
                Spacer(minLength: 0)
                ResultSaveToggles(configuration: configuration)
            }
            ResultRouteColumn(configuration: configuration).frame(maxWidth: .infinity)
            if let trailing = configuration.trailing {
                trailing
            } else if configuration.priceAmount != nil || configuration.totalLine() != nil || configuration.onSelect != nil {
                priceRow
            }
            if let footer = configuration.footer {
                footer
            } else if configuration.hasMetaContent || configuration.onDetails != nil {
                ResultMetaRow(configuration: configuration)
            }
        }
        .padding(configuration.spacing(.md))
    }

    /// Fare leading (hero tag + total line), Select trailing.
    private var priceRow: some View {
        HStack(alignment: .center, spacing: configuration.spacing(.sm)) {
            VStack(alignment: .leading, spacing: 2) {
                if let price = configuration.priceAmount {
                    PriceTag(price, currencyCode: configuration.currencyCode)
                        .emphasis(.hero).fractionDigits(configuration.priceFractionDigits)
                }
                if let totalLine = configuration.totalLine() {
                    Text(totalLine).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).fixedSize()
                }
            }
            Spacer(minLength: 0)
            if let onSelect = configuration.onSelect {
                ResultSelectButton(configuration: configuration, action: onSelect)
            }
        }
    }
}

// MARK: - .minimal (whole-row tap, trailing chevron)

/// No Select button and no inner tap targets — the whole row invokes `onSelect`
/// (disabled on read-only surfaces) with a trailing chevron affordance. Meta
/// chips still render; the Details link and save toggles are omitted so the
/// row stays a single accessibility/tap unit.
public struct MinimalFlightResultRowStyle: FlightResultRowStyle {
    public init() {}
    public func makeBody(configuration: FlightResultRowConfiguration) -> some View {
        MinimalChrome(configuration: configuration)
    }
}

private struct MinimalChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        if let onSelect = configuration.onSelect {
            Button { onSelect() } label: {
                ResultRowShell(configuration: configuration, content: AnyView(minimalContent))
            }
            .buttonStyle(.plain)
            .disabled(configuration.isReadOnly)
            .accessibilityHint(configuration.selectTitle)
        } else {
            ResultRowShell(configuration: configuration, content: AnyView(minimalContent))
        }
    }

    private var minimalContent: some View {
        VStack(spacing: configuration.spacing(.sm)) {
            HStack(alignment: .center, spacing: configuration.spacing(.sm)) {
                ResultIdentityBlock(configuration: configuration).frame(width: 92, alignment: .leading)
                ResultRouteColumn(configuration: configuration).frame(maxWidth: .infinity)
                Group {
                    if let trailing = configuration.trailing { trailing } else { priceColumn }
                }
                if configuration.onSelect != nil {
                    Icon(systemName: "chevron.forward").size(.xs).accent(.neutral)
                        .accessibilityHidden(true)   // decorative; the row itself is the button
                }
            }
            if let footer = configuration.footer {
                footer
            } else if configuration.hasMetaContent {
                ResultMetaRow(configuration: configuration, showsDetailsLink: false)
            }
        }
        .padding(configuration.spacing(.md))
    }

    private var priceColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode)
                    .emphasis(.hero).fractionDigits(configuration.priceFractionDigits)
            }
            if let totalLine = configuration.totalLine() {
                Text(totalLine).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).fixedSize()
            }
        }
    }
}

// MARK: - Static accessors

public extension FlightResultRowStyle where Self == RowFlightResultRowStyle {
    /// Identity / route / price+CTA columns — the classic result row. The default.
    static var row: RowFlightResultRowStyle { RowFlightResultRowStyle() }
}
public extension FlightResultRowStyle where Self == StackedFlightResultRowStyle {
    /// Identity above a full-width route with a price row below — narrow widths.
    static var stacked: StackedFlightResultRowStyle { StackedFlightResultRowStyle() }
}
public extension FlightResultRowStyle where Self == MinimalFlightResultRowStyle {
    /// No Select button — the whole row is the tap target, with a trailing chevron.
    static var minimal: MinimalFlightResultRowStyle { MinimalFlightResultRowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightResultRowStyle: FlightResultRowStyle {
    private let _makeBody: @MainActor (FlightResultRowConfiguration) -> AnyView
    init<S: FlightResultRowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightResultRowConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightResultRowStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightResultRowStyle(RowFlightResultRowStyle())
}

extension EnvironmentValues {
    var flightResultRowStyle: AnyFlightResultRowStyle {
        get { self[FlightResultRowStyleKey.self] }
        set { self[FlightResultRowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightResultRowStyle`` for `FlightResultRow`s in this view and
    /// its descendants — one result list can mix archetypes per section.
    func flightResultRowStyle<S: FlightResultRowStyle>(_ style: sending S) -> some View {
        environment(\.flightResultRowStyle, AnyFlightResultRowStyle(style))
    }
}

// MARK: - Previews

#Preview("Styles × light/dark") {
    let dep = Date()
    let sample = FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT",
                                 departure: dep, arrival: dep.addingTimeInterval(90 * 60))
        .flightNo("TK 2434").cabin("Economy").price(3_538.99).baggage("15 kg").badge("Cheapest")
        .onSelect("Select") { }.onDetails { }
    let saved = FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB",
                                departure: dep, arrival: dep.addingTimeInterval(70 * 60))
        .flightNo("BW 810").price(2_899).favorite(.constant(true)).bookmark()
        .totalPrice(8_697, label: "3 travellers").onSelect { }
    return PreviewMatrix("FlightResultRow styles") {
        PreviewCase(".row (default)") { sample }
        PreviewCase(".row — saved + total") { saved }
        PreviewCase(".stacked") { sample.flightResultRowStyle(.stacked) }
        PreviewCase(".stacked — saved + total") { saved.flightResultRowStyle(.stacked) }
        PreviewCase(".minimal") { sample.flightResultRowStyle(.minimal) }
        PreviewCase(".minimal — no action") {
            FlightResultRow(airline: "Sunrise Air", from: "IST", to: "LHR",
                            departure: dep, arrival: dep.addingTimeInterval(3 * 3_600))
                .flightNo("SA 101").price(4_120).urgency("5 seats left!")
                .flightResultRowStyle(.minimal)
        }
    }
}

/// A custom style defined outside the library — proves the protocol is
/// externally implementable: a shell-less one-line boarding strip.
private struct StripFlightResultRowStyle: FlightResultRowStyle {
    func makeBody(configuration: FlightResultRowConfiguration) -> some View {
        StripChrome(configuration: configuration)
    }
}

private struct StripChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightResultRowConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            Image(systemName: configuration.airlineSystemImage)
                .foregroundStyle(configuration.accentForeground(theme))
            Text("\(configuration.leg.origin) → \(configuration.leg.destination)")
                .textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
            Spacer()
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode)
                    .fractionDigits(configuration.priceFractionDigits)
            }
        }
        .padding(configuration.spacing(.sm))
        .background(theme.background(configuration.surface(default: .bgSecondaryLight)),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
}

#Preview("Custom style") {
    let dep = Date()
    return VStack(spacing: 12) {
        FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT",
                        departure: dep, arrival: dep.addingTimeInterval(90 * 60))
            .price(3_538.99)
        FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB",
                        departure: dep, arrival: dep.addingTimeInterval(70 * 60))
            .accent(.info).price(2_899)
    }
    .flightResultRowStyle(StripFlightResultRowStyle())
    .padding()
}
