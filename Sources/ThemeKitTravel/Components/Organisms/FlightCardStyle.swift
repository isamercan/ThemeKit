//
//  FlightCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightCard`` — the Class A exemplar of ADR-0004
//  (per-component style protocols): the configuration hands styles the *typed
//  flight data* (airline, legs, price, badge, scarcity…), not pre-laid content,
//  so a style owns the entire arrangement. Three built-ins:
//
//    .standard   airline header + route + price/CTA footer — today's card. Default.
//    .condensed  one-line route summary + trailing price, no airline header row.
//    .tile       vertical card for destination carousels: logo top, route mid,
//                price bottom.
//
//      FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB",
//                 departure: dep, arrival: arr)
//          .price(1_299)
//          .flightCardStyle(.condensed)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints *chrome* (card-shaped presets keep routing their surface,
//  elevation, selection and radius through `\.cardStyle`); the token theme
//  colors everything. The component resolves MicroMotion / Reduce Motion before
//  calling a style — styles read ``FlightCardConfiguration/isMotionEnabled``,
//  never the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightCardStyle`` lays out. Fields a given style doesn't
/// use are simply ignored — every built-in degrades gracefully when optional
/// data is absent (no price → no footer, no badge → no chip, `isFavorite == nil`
/// → no heart and no reserved space).
public struct FlightCardConfiguration {
    /// The header airline (the first leg's airline for multi-leg itineraries).
    public let airline: String
    /// The itinerary — one entry for a single segment (synthesized by the
    /// component, carrying its `stops`), one per slice for `init(legs:)`.
    public let legs: [FlightLeg]
    /// `true` when the card was built with `FlightCard(legs:)` — multi-leg
    /// layouts draw per-leg dividers and per-leg airline overlines.
    public let isMultiLeg: Bool
    /// SF Symbol used when no custom ``logo`` is provided.
    public let airlineSystemImage: String
    /// Custom airline logo slot (a `RemoteImage` when the component was given a
    /// logo URL); fall back to ``airlineSystemImage`` when `nil`. Styles size it.
    public let logo: AnyView?
    /// Fare-brand chip text next to the airline, e.g. "Eco Flex".
    public let fareBrand: String?
    /// Header badge text, e.g. "Cheapest".
    public let badge: String?
    /// The header badge's style (`.success` unless overridden).
    public let badgeStyle: BadgeStyle
    /// The fare; `nil` hides the price block.
    public let priceAmount: Decimal?
    /// Currency code for ``priceAmount`` — already resolved by the component
    /// through the FormatDefaults chain (explicit → `formatDefaults` →
    /// `locale.currency` → `"USD"`). Optional for additive safety only.
    public let currencyCode: String?
    /// Seats-left count for the scarcity line; `nil` hides it.
    public let scarcity: Int?
    /// Stop count for the single-segment form (multi-leg stops live per-leg).
    public let stops: Int
    /// Selected state — card-shaped styles feed it to the `CardStyle` shell.
    public let isSelected: Bool
    /// The footer CTA's title (localized, re-resolved every body pass).
    public let selectTitle: String
    /// The select action; `nil` hides the CTA (whole-card tap in row styles).
    public let onSelect: (() -> Void)?
    /// Brand-chrome accent (`FlightCard.accent(_:)`), or `nil` for the theme's
    /// hero tokens — resolve via ``accentForeground(_:)``.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Shell elevation, fed to the active `CardStyle` by card-shaped styles.
    public let elevation: CardElevation
    /// Replacement for the built-in header row (`.header { }`); `nil` = built-in.
    public let header: AnyView?
    /// Replacement for the built-in price/CTA footer (`.footer { }`).
    public let footer: AnyView?
    /// Favourite state — `nil` means no heart was requested (the default; styles
    /// render no heart and reserve no space). Set by ``FlightCard/favorite()`` /
    /// ``FlightCard/favorite(_:)``.
    public let isFavorite: Bool?
    /// Flips ``isFavorite``. Styles with a heart call this.
    public let toggleFavorite: (() -> Void)?
    /// Micro-animations resolved by the component (`MicroMotion` ∧ ¬Reduce
    /// Motion) — gate symbol effects on this; never read the motion environment.
    public let isMotionEnabled: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The itinerary's first leg — every style's primary subject.
    public var leg: FlightLeg? { legs.first }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the card.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The `accent(_:)` override's base, else the theme's hero foreground — the
    /// value the built-ins hardcoded before the accent axis existed.
    public func accentForeground(_ theme: Theme) -> Color { accent.map { theme.resolve($0).base } ?? theme.foreground(.fgHero) }

    // Shared formatting, so all styles speak one language.
    public func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
    public func duration(of leg: FlightLeg) -> String {
        let minutes = max(0, Int(leg.arrival.timeIntervalSince(leg.departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    public func stopsText(_ leg: FlightLeg) -> String {
        switch leg.stops {
        case 0: return String(themeKit: "Nonstop")
        case 1: return String(themeKit: "1 stop")
        default: return String(themeKit: "\(leg.stops) stops")
        }
    }
}

// MARK: - Protocol

/// Defines a `FlightCard`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's flight data. Set one with `.flightCardStyle(_:)`;
/// the default is ``StandardFlightCardStyle``.
public protocol FlightCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The heart toggle shared by `.standard` and `.tile` — bounce is gated on the
/// component-resolved ``FlightCardConfiguration/isMotionEnabled``.
private struct FlightCardFavoriteHeart: View {
    @Environment(\.theme) private var theme
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: FlightCardConfiguration

    var body: some View {
        let isFavorite = configuration.isFavorite ?? false
        return Button { configuration.toggleFavorite?() } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.body)
                .foregroundStyle(isFavorite ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                .symbolEffect(.bounce, value: configuration.isMotionEnabled ? isFavorite : false)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .accessibilityLabel(isFavorite
            ? String(themeKit: "Remove from favourites")
            : String(themeKit: "Add to favourites"))
    }
}

/// The urgent "N seats left" line shared by `.standard` and `.tile`.
private struct FlightCardScarcityRow: View {
    @Environment(\.theme) private var theme
    let count: Int

    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Image(systemName: "flame.fill").font(.caption2)
            Text(count == 1 ? String(themeKit: "1 seat left") : String(themeKit: "\(count) seats left"))
                .textStyle(.bodySm400)
        }
        .foregroundStyle(theme.foreground(.systemcolorsFgError))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - .standard

/// Today's ``FlightCard`` look, extracted verbatim: airline header (logo, name,
/// fare-brand chip, badge, heart), the route track per leg, an optional scarcity
/// line and the price + Select footer — all inside the active `CardStyle` shell.
public struct StandardFlightCardStyle: FlightCardStyle {
    public init() {}
    public func makeBody(configuration: FlightCardConfiguration) -> some View {
        StandardFlightCardChrome(configuration: configuration)
    }
}

private struct StandardFlightCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FlightCardConfiguration

    /// The brand-chrome tint: explicit accent when set, else the theme's hero
    /// foreground — `nil` reproduces the pre-style rendering exactly.
    private var accentBase: Color { configuration.accentForeground(theme) }

    var body: some View {
        // The shell (fill, corner clipping, border) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        // `.none` matches the classic chrome: no shadow, hairline border.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(spacing: configuration.spacing(.md)) {
            if let header = configuration.header { header } else { builtInHeader }
            routeContent
            if let scarcity = configuration.scarcity { FlightCardScarcityRow(count: scarcity) }
            if configuration.footer != nil || configuration.priceAmount != nil || configuration.onSelect != nil {
                footer
            }
        }
        .padding(configuration.spacing(.md))
    }

    private var builtInHeader: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let logo = configuration.logo {
                logo.frame(width: 22, height: 22)
            } else {
                Image(systemName: configuration.airlineSystemImage)
                    .font(.title3)
                    .foregroundStyle(accentBase)
            }
            Text(configuration.airline).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            if let fareBrand = configuration.fareBrand {
                Text(fareBrand).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(theme.background(.bgSecondaryLight), in: Capsule())
            }
            Spacer()
            if let badge = configuration.badge {
                Badge(badge).badgeStyle(configuration.badgeStyle).size(.small)
            }
            if configuration.isFavorite != nil { FlightCardFavoriteHeart(configuration: configuration) }
        }
    }

    @ViewBuilder private var routeContent: some View {
        if configuration.isMultiLeg {
            VStack(spacing: configuration.spacing(.md)) {
                ForEach(Array(configuration.legs.enumerated()), id: \.offset) { index, leg in
                    if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                    legRow(leg)
                }
            }
        } else if let leg = configuration.leg {
            route(leg)
        }
    }

    private func legRow(_ leg: FlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Per-leg airline only when it differs from the header airline (avoids
            // repeating the carrier on the first leg when the header shows it).
            if configuration.legs.count > 1, leg.airline != configuration.airline {
                Text(leg.airline).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            }
            route(leg)
        }
    }

    private func route(_ leg: FlightLeg) -> some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            timeColumn(leg.departure, code: leg.origin, alignment: .leading)
            legPath(leg)
            timeColumn(leg.arrival, code: leg.destination, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private func legPath(_ leg: FlightLeg) -> some View {
        VStack(spacing: 4) {
            Text(configuration.duration(of: leg)).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            HStack(spacing: 4) {
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
                line
                Image(systemName: "airplane").font(.system(size: 12)).foregroundStyle(accentBase)
                line
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
            }
            Group {
                if let layover = leg.layover { Text(layover) } else { Text(configuration.stopsText(leg)) }
            }
            .textStyle(.overline400)
            .foregroundStyle(leg.stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private func timeColumn(_ date: Date, code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            // Captured-locale rule: schedule times honour the injected \.locale.
            Text(configuration.time(date))
                .textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            Text(code)
                .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
        }
    }

    private var line: some View {
        Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
    }

    @ViewBuilder private var footer: some View {
        if let footerSlot = configuration.footer {
            footerSlot
        } else {
            HStack {
                if let price = configuration.priceAmount {
                    PriceTag(price, currencyCode: configuration.currencyCode ?? "USD").size(.large).emphasis(.hero)
                }
                Spacer()
                if let onSelect = configuration.onSelect {
                    // Accent set → semantic-colored ThemeButton; nil → the stock
                    // hero PrimaryButton, byte-for-byte the classic rendering.
                    if let accent = configuration.accent {
                        ThemeButton(configuration.selectTitle) { onSelect() }.color(accent).size(.small)
                    } else {
                        PrimaryButton(configuration.selectTitle) { onSelect() }.size(.small)
                    }
                }
            }
        }
    }
}

// MARK: - .condensed

/// One-line route summary + trailing price — no airline header row. Dense
/// result lists; the whole row taps through to `onSelect` when it is set.
public struct CondensedFlightCardStyle: FlightCardStyle {
    public init() {}
    public func makeBody(configuration: FlightCardConfiguration) -> some View {
        CondensedFlightCardChrome(configuration: configuration)
    }
}

private struct CondensedFlightCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FlightCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(tappableRow),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
    }

    @ViewBuilder private var tappableRow: some View {
        if let onSelect = configuration.onSelect {
            Button(action: onSelect) { row }
                .buttonStyle(.plain)
        } else {
            row
        }
    }

    private var row: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let logo = configuration.logo {
                logo.frame(width: 22, height: 22)
            } else {
                Image(systemName: configuration.airlineSystemImage)
                    .font(.body)
                    .foregroundStyle(configuration.accentForeground(theme))
            }
            VStack(alignment: .leading, spacing: configuration.spacing(.xs)) {
                ForEach(Array(configuration.legs.enumerated()), id: \.offset) { _, leg in
                    legLine(leg)
                }
            }
            Spacer(minLength: configuration.spacing(.sm))
            trailingBlock
        }
        .padding(configuration.spacing(.sm))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }

    /// "06:40 – 09:15 / IST–ESB · 2h 20m · Nonstop" — one line per leg.
    private func legLine(_ leg: FlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(configuration.time(leg.departure)) – \(configuration.time(leg.arrival))")
                .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                .lineLimit(1)
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Text("\(leg.origin)–\(leg.destination) · \(configuration.duration(of: leg))")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                Text(leg.layover ?? configuration.stopsText(leg))
                    .textStyle(.labelSm600)
                    .foregroundStyle(leg.stops == 0
                        ? theme.foreground(.systemcolorsFgSuccess)
                        : theme.text(.textTertiary))
            }
            .lineLimit(1)
        }
    }

    @ViewBuilder private var trailingBlock: some View {
        VStack(alignment: .trailing, spacing: 2) {
            if let badge = configuration.badge {
                Badge(badge).badgeStyle(configuration.badgeStyle).size(.small)
            }
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode ?? "USD").size(.medium).emphasis(.hero)
            } else if configuration.onSelect != nil {
                Icon(systemName: "chevron.forward").size(.xs).accent(.neutral)
            }
        }
    }
}

// MARK: - .tile

/// A vertical card for destination carousels: logo/badge top, route mid, price
/// bottom. Shows the itinerary's first leg; the whole tile taps through to
/// `onSelect` when it is set.
public struct TileFlightCardStyle: FlightCardStyle {
    public init() {}
    public func makeBody(configuration: FlightCardConfiguration) -> some View {
        TileFlightCardChrome(configuration: configuration)
    }
}

private struct TileFlightCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: FlightCardConfiguration

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(tappableTile),
            elevation: configuration.elevation,
            isSelected: configuration.isSelected,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: .box))
    }

    @ViewBuilder private var tappableTile: some View {
        if let onSelect = configuration.onSelect {
            Button(action: onSelect) { tileContent }
                .buttonStyle(.plain)
        } else {
            tileContent
        }
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            HStack(spacing: configuration.spacing(.sm)) {
                if let logo = configuration.logo {
                    logo.frame(width: 22, height: 22)
                } else {
                    Image(systemName: configuration.airlineSystemImage)
                        .font(.title3)
                        .foregroundStyle(configuration.accentForeground(theme))
                }
                Spacer()
                if let badge = configuration.badge {
                    Badge(badge).badgeStyle(configuration.badgeStyle).size(.small)
                }
                if configuration.isFavorite != nil { FlightCardFavoriteHeart(configuration: configuration) }
            }
            if let leg = configuration.leg {
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.airline)
                        .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    Text("\(leg.origin)–\(leg.destination)")
                        .textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    Text("\(configuration.time(leg.departure)) – \(configuration.time(leg.arrival))"
                         + " · \(configuration.duration(of: leg))")
                        .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    Text(leg.layover ?? configuration.stopsText(leg))
                        .textStyle(.overline400)
                        .foregroundStyle(leg.stops == 0
                            ? theme.foreground(.systemcolorsFgSuccess)
                            : theme.text(.textTertiary))
                }
                .accessibilityElement(children: .combine)
            }
            if let scarcity = configuration.scarcity { FlightCardScarcityRow(count: scarcity) }
            if let price = configuration.priceAmount {
                PriceTag(price, currencyCode: configuration.currencyCode ?? "USD").size(.medium).emphasis(.hero)
            }
        }
        .padding(configuration.spacing(.md))
        .contentShape(Rectangle())
    }
}

// MARK: - Static accessors

public extension FlightCardStyle where Self == StandardFlightCardStyle {
    /// Airline header + route + price/CTA footer — today's card. The default.
    static var standard: StandardFlightCardStyle { StandardFlightCardStyle() }
}
public extension FlightCardStyle where Self == CondensedFlightCardStyle {
    /// One-line route summary + trailing price, no airline header row.
    static var condensed: CondensedFlightCardStyle { CondensedFlightCardStyle() }
}
public extension FlightCardStyle where Self == TileFlightCardStyle {
    /// Vertical card for destination carousels: logo top, route mid, price bottom.
    static var tile: TileFlightCardStyle { TileFlightCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightCardStyle: FlightCardStyle {
    private let _makeBody: @MainActor (FlightCardConfiguration) -> AnyView
    init<S: FlightCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightCardStyle(StandardFlightCardStyle())
}

extension EnvironmentValues {
    var flightCardStyle: AnyFlightCardStyle {
        get { self[FlightCardStyleKey.self] }
        set { self[FlightCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightCardStyle`` for `FlightCard`s in this view and its
    /// descendants — one screen can mix archetypes per section.
    func flightCardStyle<S: FlightCardStyle>(_ style: sending S) -> some View {
        environment(\.flightCardStyle, AnyFlightCardStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: an accent rail + condensed summary + price, no card shell at all.
private struct AccentStripeFlightCardStyle: FlightCardStyle {
    func makeBody(configuration: FlightCardConfiguration) -> some View {
        AccentStripeChrome(configuration: configuration)
    }

    private struct AccentStripeChrome: View {
        @Environment(\.theme) private var theme
        let configuration: FlightCardConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value)
                    .fill(configuration.accentForeground(theme))
                    .frame(width: 4)
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.airline)
                        .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    if let leg = configuration.leg {
                        Text("\(leg.origin)–\(leg.destination) · \(configuration.time(leg.departure))")
                            .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                    }
                }
                Spacer()
                if let price = configuration.priceAmount {
                    PriceTag(price, currencyCode: configuration.currencyCode ?? "USD").size(.medium)
                }
            }
            .padding(configuration.spacing(.sm))
            .background(
                theme.background(.bgSecondaryLight),
                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
        }
    }
}

#Preview("FlightCardStyle — presets × light/dark") {
    let dep = Date()
    let arr = dep.addingTimeInterval(2 * 3_600 + 20 * 60)
    let single = FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr)
        .price(1_299).badge("Cheapest").favorite().onSelect { }
    let multi = FlightCard(legs: [
        FlightLeg(airline: "Anadolu Air", from: "IST", to: "LHR",
                  departure: dep, arrival: dep.addingTimeInterval(4 * 3_600)),
        FlightLeg(airline: "Blue Wings", from: "LHR", to: "IST",
                  departure: dep.addingTimeInterval(7 * 24 * 3_600),
                  arrival: dep.addingTimeInterval(7 * 24 * 3_600 + 4 * 3_600),
                  stops: 1, layover: "1 stop · 2h 10m · AMS")])
        .price(7_178).scarcity(5).onSelect { }
    return PreviewMatrix("FlightCardStyle") {
        PreviewCase("Standard (default)") { single }
        PreviewCase("Standard · multi-leg") { multi }
        PreviewCase("Standard · accent") { single.accent(.success) }
        PreviewCase("Condensed") { single.flightCardStyle(.condensed) }
        PreviewCase("Condensed · multi-leg") { multi.flightCardStyle(.condensed) }
        PreviewCase("Tile") {
            single.flightCardStyle(.tile).frame(width: 220)
        }
        PreviewCase("Custom (in-preview)") { single.flightCardStyle(AccentStripeFlightCardStyle()) }
    }
}
