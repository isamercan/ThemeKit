//
//  FlightListItemStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightListItem`` — and the most data-rich style
//  protocol in the library: the configuration hands styles the *typed flight
//  data* (legs, fares, deal signals, schedule), not pre-laid content, so a
//  style owns the entire layout. Twelve built-ins cover the industry's
//  search-result archetypes (researched across Skyscanner, Google Flights,
//  Kayak, Hopper, Delta/THY fare boards, Kiwi itineraries, Expedia bundles):
//
//    .compact    one-line timetable row (Google Flights condensed)
//    .timeline   the de-facto standard route-track card (Kayak/Skyscanner) — default
//    .fareBoard  fare-family chips with per-fare prices (Delta/THY shopping)
//    .deal       price-judgment header + strikethrough + sparkline (Hopper)
//    .ticket     perforated boarding-ticket card (Dribbble/airline passes)
//    .journey    expandable per-leg vertical timeline (Kayak/Kiwi details)
//    .slices     one card per itinerary, stacked slice rows (Expedia round trip)
//    .timetable  carrier-grouped departure-time chips (Skyscanner widget)
//    .tray       nested white card on a soft tray with a CTA rail (design-system spec)
//    .tile       vertical card for horizontal carousels (destination-deal shelves)
//    .hero       featured tall card: deal strip + big price + amenities
//    .receipt    checkout summary — labeled fields, no tap affordance
//
//      FlightListItem(legs: [out, back]).price(438, caption: "total")
//          .flightListItemStyle(.slices)
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightListItemStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (a `.deal` item without `dealText` renders as a
/// plain card, `.fareBoard` without fares collapses to its summary line).
public struct FlightListItemConfiguration {
    public let legs: [FlightLeg]
    /// Per-slice captions (aligned with `legs`) for multi-leg styles.
    public let sliceLabels: [String]
    public let flightNo: String?
    public let cabin: String?
    public let airlineSystemImage: String
    /// Custom airline logo slot; fall back to `airlineSystemImage` when `nil`.
    public let logo: AnyView?
    public let priceAmount: Decimal?
    public let originalAmount: Decimal?
    public let currencyCode: String
    public let priceCaption: String?
    public let fares: [FlightFare]
    public let departures: [Date]
    public let scheduleNote: String?
    public let dealText: String?
    public let dealTone: SemanticColor
    public let trend: [Double]
    public let badge: String?
    public let amenities: [String]
    /// Carry-on allowance ("8kg"); `nil` hides the baggage meta entirely.
    public let baggage: String?
    /// Checked-bag allowance; `nil` renders as "not included" next to `baggage`.
    public let checkedBaggage: String?
    public let isExpanded: Bool
    public let isSelected: Bool
    public let isEnabled: Bool
    public let selectTitle: String
    public let onSelect: (() -> Void)?
    /// Secondary "open details" action (styles with a details affordance show it).
    public let detailsTitle: String
    public let onDetails: (() -> Void)?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale
    /// Flips `isExpanded` (animated). Styles with a disclosure affordance call this.
    public let toggleExpand: () -> Void
    /// Favourite state — `nil` means no heart was requested (the default; styles
    /// render no heart and reserve no space). Set by ``FlightListItem/favorite()``
    /// / ``FlightListItem/favorite(_:)``. Custom styles that predate this field
    /// simply ignore it — graceful degradation, no crash, no layout shift.
    public let isFavorite: Bool?
    /// Flips `isFavorite` (animated, `MicroMotion`-gated). Styles with a heart
    /// call this — mirrors `toggleExpand`.
    public let toggleFavorite: (() -> Void)?
    /// Selection accent (`FlightListItem.accent(_:)`), or `nil` for the theme's
    /// hero tokens — resolve via ``accentBorder(_:)`` and friends.
    public let accent: SemanticColor?
    /// Corner-radius role override (`FlightListItem.radius(_:)`); `nil` = the
    /// style's standard `.box`. Resolve via ``cornerRadius``.
    public let radiusRole: Theme.RadiusRole?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// Generic icon + text meta pairs (`FlightListItem.meta(_:)`) — styles with
    /// a meta row render them in order.
    public let metaItems: [(icon: String, text: String)]
    /// Optional trailing accessory for the identity row (`.accessory { }`).
    /// Styles that predate this field simply ignore it.
    public let accessory: AnyView?
    /// Optional footer below the style's content (`.footer { }`).
    public let footer: AnyView?
    /// The chosen fare id — fed by `FlightListItem.selectedFare(_:)` or the
    /// item's own uncontrolled state. Fare-aware styles read this instead of
    /// keeping a private selection.
    public let selectedFareID: String?
    /// Reports a fare-chip tap. Fare-aware styles call this; when `nil`
    /// (a hand-built configuration) styles fall back to local state.
    public let onFareSelect: ((String) -> Void)?
    /// The chosen departure time (`.timetable`) — controlled/uncontrolled like
    /// ``selectedFareID``, via `FlightListItem.selectedDeparture(_:)`.
    public let selectedDeparture: Date?
    /// Reports a departure-chip tap — mirrors ``onFareSelect``.
    public let onDepartureSelect: ((Date) -> Void)?

    /// The itinerary's first leg — every style's primary subject.
    public var leg: FlightLeg { legs[0] }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// The `radius(_:)` override's value, or the standard card `.box` radius.
    public var cornerRadius: CGFloat { (radiusRole ?? .box).value }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the item.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    // Accent resolution — the `accent(_:)` override, else the theme's hero tokens
    // (the values the built-ins hardcoded before the accent axis existed).
    /// Selected-state border tint.
    public func accentBorder(_ theme: Theme) -> Color { accent.map { theme.resolve($0).base } ?? theme.border(.borderHero) }
    /// Emphasized foreground tint (selected text/icons).
    public func accentForeground(_ theme: Theme) -> Color { accent.map { theme.resolve($0).base } ?? theme.foreground(.fgHero) }
    /// Selected-chip fill.
    public func accentFill(_ theme: Theme) -> Color { accent.map { theme.resolve($0).solid } ?? theme.background(.bgHero) }
    /// Content colour on top of ``accentFill(_:)``.
    public func accentOnFill(_ theme: Theme) -> Color { accent.map { theme.resolve($0).onSolid } ?? theme.foreground(.fgSecondary) }

    // Shared formatting, so all styles speak one language.
    public func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }
    public func shortDate(_ date: Date) -> String {
        date.formatted(Date.FormatStyle.dateTime.day().month(.abbreviated).locale(locale))
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

/// Defines a `FlightListItem`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's flight data. Set one with
/// `.flightListItemStyle(_:)`; the default is ``TimelineFlightListItemStyle``.
public protocol FlightListItemStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightListItemConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// Dep-time/code column — the recurring endpoint block of route layouts.
private struct TimeColumn: View {
    @Environment(\.theme) private var theme
    let time: String
    let code: String
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(time).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            Text(code).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
        }
    }
}

/// The drawn route track: endpoint dots, filled stop dots mid-track, duration
/// above and stops below. Built from stacks (not `Path`), so RTL mirrors free.
private struct RouteTrack: View {
    @Environment(\.theme) private var theme
    let leg: FlightLeg
    let duration: String
    let stops: String

    var body: some View {
        VStack(spacing: 3) {
            Text(duration).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            HStack(spacing: 0) {
                Circle().stroke(theme.border(.borderPrimary), lineWidth: 1.5).frame(width: 7, height: 7)
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1.5)
                ForEach(0..<min(leg.stops, 3), id: \.self) { _ in
                    Circle().fill(theme.border(.systemcolorsBorderWarning)).frame(width: 5, height: 5)
                    Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1.5)
                }
                Icon(systemName: "airplane").size(.xs).accent(.primary)
            }
            Text(stops)
                .textStyle(.overline400)
                .foregroundStyle(leg.stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
    }
}

/// One compressed "logo · 06:40 → 09:15 · IST–LHR · Nonstop" line — the slice
/// sub-row shared by `.compact`, `.slices` and `.journey`'s collapsed state.
private struct SliceLine: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration
    let leg: FlightLeg

    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                .frame(width: 24, height: 24)
            VStack(alignment: .leading, spacing: 1) {
                Text("\(configuration.time(leg.departure)) – \(configuration.time(leg.arrival))")
                    .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1).fixedSize()
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text("\(leg.origin)–\(leg.destination) · \(configuration.duration(of: leg))")
                        .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    Text(configuration.stopsText(leg))
                        .textStyle(.labelSm600)
                        .foregroundStyle(leg.stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.foreground(.systemcolorsFgWarning))
                }
                .lineLimit(1).fixedSize()
            }
        }
    }
}

/// The right-aligned price block (caption over PriceTag over strikethrough).
private struct PriceBlock: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration
    var size: PriceSize = .medium

    var body: some View {
        if let amount = configuration.priceAmount {
            VStack(alignment: .trailing, spacing: 2) {
                if let caption = configuration.priceCaption {
                    Text(caption).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                }
                PriceTag(amount, currencyCode: configuration.currencyCode)
                    .original(configuration.originalAmount)
                    .size(size)
            }
        }
    }
}

/// The favourite heart toggle shared by the built-ins — parity with
/// ``FlightCard``'s heart (44pt target, `heart`/`heart.fill`, error-tone fill,
/// bounce gated by `microAnimations` + Reduce Motion). Renders **nothing** when
/// the configuration has no favourite (`isFavorite == nil`), so styles compose
/// it without a layout shift for callers that never asked for a heart.
private struct FavoriteHeart: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isReadOnly) private var isReadOnly
    let configuration: FlightListItemConfiguration

    var body: some View {
        if let isFavorite = configuration.isFavorite {
            Button { configuration.toggleFavorite?() } label: {
                Image(systemName: isFavorite ? "heart.fill" : "heart")
                    .font(.body)
                    .foregroundStyle(isFavorite ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                    .symbolBounceCompat(value: (micro && !reduceMotion) ? isFavorite : false)
                    .frame(minWidth: 44, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isReadOnly)
            .accessibilityLabel(isFavorite
                ? String(themeKit: "Remove from favourites")
                : String(themeKit: "Add to favourites"))
        }
    }
}

/// A tiny price-history sparkline. Drawn in a fixed frame and explicitly
/// mirrored for RTL (a `Path` doesn't follow layout direction on its own).
private struct Sparkline: View {
    @Environment(\.theme) private var theme
    let points: [Double]
    let tone: SemanticColor

    var body: some View {
        GeometryReader { geo in
            let lo = points.min() ?? 0, hi = points.max() ?? 1
            let span = max(hi - lo, .ulpOfOne)
            Path { p in
                for (i, v) in points.enumerated() {
                    let x = geo.size.width * CGFloat(i) / CGFloat(max(points.count - 1, 1))
                    let y = geo.size.height * (1 - CGFloat((v - lo) / span))
                    i == 0 ? p.move(to: CGPoint(x: x, y: y)) : p.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(theme.resolve(tone).base, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .flipsForRightToLeftLayoutDirection(true)
    }
}

/// A row of icon + text meta pairs (`FlightListItem.meta(_:)`). Renders nothing
/// when the configuration carries no meta items.
private struct MetaRow: View {
    @Environment(\.theme) private var theme
    let items: [(icon: String, text: String)]

    var body: some View {
        if !items.isEmpty {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    HStack(spacing: 2) {
                        Icon(systemName: item.icon).size(.xs).accent(.neutral)
                        Text(item.text).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer(minLength: 0)
            }
        }
    }
}

/// The card shell every carded built-in shares: surface fill, continuous
/// corners (radius-role override honored), hairline border (accent-tinted
/// when selected).
private extension View {
    func itemShell(_ configuration: FlightListItemConfiguration, theme: Theme) -> some View {
        self
            .background(theme.background(configuration.surface(default: .bgBase)),
                        in: RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                    .strokeBorder(configuration.isSelected ? configuration.accentBorder(theme) : theme.border(.borderPrimary),
                                  lineWidth: configuration.isSelected ? 1.5 : 1)
            )
    }
}

// MARK: - 1. Compact — one-line timetable row

/// Google-Flights-condensed archetype: a single ~52pt row, no card chrome,
/// hairline separator. For dense schedule lists and date-change screens.
public struct CompactFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        CompactChrome(configuration: configuration)
    }
}

private struct CompactChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                SliceLine(configuration: configuration, leg: configuration.leg)
                Spacer(minLength: Theme.SpacingKey.xs.value)
                FavoriteHeart(configuration: configuration)
                PriceBlock(configuration: configuration, size: .small)
            }
            .padding(.vertical, configuration.spacing(.sm))
            .contentShape(Rectangle())
            .onTapGesture { configuration.onSelect?() }
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
        }
    }
}

// MARK: - 2. Timeline — the de-facto standard card (default)

/// Kayak/Skyscanner archetype: 3-column route block over a footer with the
/// airline identity and price. The library default.
public struct TimelineFlightListItemStyle: FlightListItemStyle {
    private let showsRouteTrack: Bool
    /// - Parameter showsRouteTrack: draw the dotted route track between the
    ///   endpoints (default). `false` swaps in a plain duration/stops column
    ///   for quieter lists.
    public init(showsRouteTrack: Bool = true) {
        self.showsRouteTrack = showsRouteTrack
    }
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TimelineChrome(configuration: configuration, showsRouteTrack: showsRouteTrack)
    }
}

private struct TimelineChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration
    var showsRouteTrack = true

    var body: some View {
        let leg = configuration.leg
        VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
            if let badge = configuration.badge {
                Badge(badge).badgeStyle(.info).size(.small)
            }
            HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                TimeColumn(time: configuration.time(leg.departure), code: leg.origin, alignment: .leading)
                if showsRouteTrack {
                    RouteTrack(leg: leg, duration: configuration.duration(of: leg), stops: configuration.stopsText(leg))
                        .frame(maxWidth: .infinity)
                } else {
                    VStack(spacing: 2) {
                        Text(configuration.duration(of: leg))
                            .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                        Text(configuration.stopsText(leg))
                            .textStyle(.overline400)
                            .foregroundStyle(leg.stops == 0
                                ? theme.foreground(.systemcolorsFgSuccess)
                                : theme.text(.textTertiary))
                    }
                    .frame(maxWidth: .infinity)
                }
                TimeColumn(time: configuration.time(leg.arrival), code: leg.destination, alignment: .trailing)
            }
            MetaRow(items: configuration.metaItems)
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
            HStack(spacing: Theme.SpacingKey.sm.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 22, height: 22)
                VStack(alignment: .leading, spacing: 0) {
                    Text(leg.airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    if let no = configuration.flightNo {
                        Text(no).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                Spacer()
                if let accessory = configuration.accessory { accessory }
                FavoriteHeart(configuration: configuration)
                PriceBlock(configuration: configuration)
            }
            if let footer = configuration.footer { footer }
        }
        .padding(configuration.spacing(.md))
        .itemShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}

// MARK: - 3. Fare board — fare-family chips

/// Delta/THY fare-shopping archetype: a compact summary line over a
/// horizontally scrolling band of fare chips, each with its own price.
public struct FareBoardFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        FareBoardChrome(configuration: configuration)
    }
}

private struct FareBoardChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration
    /// Uncontrolled fallback for hand-built configurations without
    /// `onFareSelect` — `FlightListItem` always feeds the configuration fields
    /// (ADR-F4 `ControllableState`), so this stays dormant for the built-ins.
    @State private var chosen: String?

    private var selectedFareID: String? {
        configuration.onFareSelect != nil ? configuration.selectedFareID : chosen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
            HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                SliceLine(configuration: configuration, leg: configuration.leg)
                if configuration.accessory != nil || configuration.isFavorite != nil {
                    Spacer(minLength: Theme.SpacingKey.xs.value)
                    if let accessory = configuration.accessory { accessory }
                    FavoriteHeart(configuration: configuration)
                }
            }
            if !configuration.fares.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ForEach(configuration.fares) { fare in
                            fareChip(fare)
                        }
                    }
                }
            }
            if let footer = configuration.footer { footer }
        }
        .padding(configuration.spacing(.md))
        .itemShell(configuration, theme: theme)
    }

    private func fareChip(_ fare: FlightFare) -> some View {
        let selected = selectedFareID == fare.id
        return Button {
            if let onFareSelect = configuration.onFareSelect { onFareSelect(fare.id) } else { chosen = fare.id }
            configuration.onSelect?()
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(fare.name).textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
                if !fare.perks.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(fare.perks.prefix(3), id: \.self) { perk in
                            Icon(systemName: perk).size(.xs).accent(.neutral)
                        }
                    }
                }
                PriceTag(fare.price, currencyCode: configuration.currencyCode).size(.small)
            }
            .padding(Theme.SpacingKey.sm.value)
            .frame(minWidth: 96, alignment: .leading)
            .background(theme.background(selected ? .bgElevatorTertiary : .bgSecondaryLight),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                    .strokeBorder(selected ? configuration.accentBorder(theme) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 4. Deal — price-judgment header + sparkline

/// Hopper archetype: the price is a *judgment*, not a number — a semantic
/// header strip, strikethrough typical price, and a tiny history sparkline.
public struct DealFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        DealChrome(configuration: configuration)
    }
}

private struct DealChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let deal = configuration.dealText {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Icon(systemName: "chart.line.downtrend.xyaxis").size(.xs).accent(configuration.dealTone)
                    Text(deal).textStyle(.labelSm700).foregroundStyle(theme.resolve(configuration.dealTone).base)
                    Spacer()
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(theme.resolve(configuration.dealTone).soft)
            }
            HStack(spacing: Theme.SpacingKey.md.value) {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    SliceLine(configuration: configuration, leg: configuration.leg)
                    if !configuration.trend.isEmpty {
                        Sparkline(points: configuration.trend, tone: configuration.dealTone)
                            .frame(width: 72, height: 20)
                    }
                }
                Spacer(minLength: 0)
                FavoriteHeart(configuration: configuration)
                PriceBlock(configuration: configuration)
            }
            .padding(configuration.spacing(.md))
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .itemShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}

// MARK: - 5. Ticket — perforated boarding-ticket card

/// The boarding-pass archetype: big IATA codes with a dashed path, labeled
/// detail fields, and a perforated stub holding identity + price. The notches
/// are cut with a mask, so the list background shows through in any theme.
public struct TicketFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TicketChrome(configuration: configuration)
    }
}

private struct TicketChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        let leg = configuration.leg
        VStack(spacing: 0) {
            VStack(spacing: Theme.SpacingKey.md.value) {
                HStack(alignment: .center) {
                    bigCode(leg.origin, time: configuration.time(leg.departure), alignment: .leading)
                    VStack(spacing: 2) {
                        Icon(systemName: "airplane").size(.sm).accent(.primary)
                        Line().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                            .frame(height: 1)
                        Text(configuration.duration(of: leg)).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                    .frame(maxWidth: .infinity)
                    bigCode(leg.destination, time: configuration.time(leg.arrival), alignment: .trailing)
                }
                HStack {
                    field("Date", configuration.shortDate(leg.departure))
                    Spacer()
                    field("Cabin", configuration.cabin ?? "—")
                    Spacer()
                    field("Stops", configuration.stopsText(leg))
                }
            }
            .padding(configuration.spacing(.md))
            perforation
            HStack(spacing: Theme.SpacingKey.sm.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 22, height: 22)
                Text(configuration.flightNo ?? leg.airline)
                    .textStyle(.labelSm700).foregroundStyle(theme.text(.textSecondary))
                Spacer()
                FavoriteHeart(configuration: configuration)
                PriceBlock(configuration: configuration, size: .small)
            }
            .padding(configuration.spacing(.md))
        }
        .background(theme.background(configuration.surface(default: .bgBase)))
        .clipShape(TicketNotchShape(stubHeight: 58, radius: 7))
        .overlay(
            TicketNotchShape(stubHeight: 58, radius: 7)
                .stroke(configuration.isSelected ? configuration.accentBorder(theme) : theme.border(.borderPrimary),
                        lineWidth: configuration.isSelected ? 1.5 : 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }

    private var perforation: some View {
        Line().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
            .frame(height: 1)
            .padding(.horizontal, Theme.SpacingKey.md.value)
    }

    private func bigCode(_ code: String, time: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(code).textStyle(.headingLg).foregroundStyle(theme.text(.textPrimary))
            Text(time).textStyle(.labelSm600).foregroundStyle(configuration.accentForeground(theme))
        }
    }

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            Text(value).textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
        }
    }
}

/// A rounded-rect outline with two semicircular notches cut into the side
/// edges `stubHeight` up from the bottom — the tearable-ticket silhouette.
///
/// iOS 15.6-floor migration (ADR-0007 §D2 rule 1, plan §3e): the outline is
/// traced as one contour with real arc geometry — `Path.subtracting` is
/// iOS 17-only — so fill *and* stroke follow the notches on every supported
/// OS. Corner arcs are circular (the boolean-subtraction version rounded the
/// body with `.continuous` squircle corners — a subtle fidelity delta noted
/// for the Phase-4 snapshot re-record).
private struct TicketNotchShape: Shape {
    let stubHeight: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let corner = min(Theme.RadiusRole.box.value, min(rect.width, rect.height) / 2)
        let y = rect.maxY - stubHeight
        // Degenerate frames (notch would overlap a corner): plain rounded rect.
        guard y - radius > rect.minY + corner, y + radius < rect.maxY - corner else {
            return RoundedRectangle(cornerRadius: corner, style: .continuous).path(in: rect)
        }
        var p = Path()
        // Screen coords, y down; `clockwise: false` = increasing angle =
        // screen-clockwise (`DonutWedgeShape` convention). The two notch arcs
        // sweep *into* the rect (decreasing angle → `clockwise: true`).
        p.move(to: CGPoint(x: rect.minX + corner, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX - corner, y: rect.minY))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.minY + corner), radius: corner,
                 startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.maxX, y: y - radius))
        p.addArc(center: CGPoint(x: rect.maxX, y: y), radius: radius,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - corner))
        p.addArc(center: CGPoint(x: rect.maxX - corner, y: rect.maxY - corner), radius: corner,
                 startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + corner, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.maxY - corner), radius: corner,
                 startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX, y: y + radius))
        p.addArc(center: CGPoint(x: rect.minX, y: y), radius: radius,
                 startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: true)
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + corner))
        p.addArc(center: CGPoint(x: rect.minX + corner, y: rect.minY + corner), radius: corner,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.closeSubpath()
        return p
    }
}

/// A horizontal 1pt line path (dash-friendly).
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return p
    }
}

// MARK: - 6. Journey — expandable per-leg timeline

/// Kayak/Kiwi details archetype: a summary row that expands in place into a
/// vertical leg timeline with layover rows, amenities and a pinned CTA.
public struct JourneyFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        JourneyChrome(configuration: configuration)
    }
}

private struct JourneyChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // The heart sits OUTSIDE the disclosure Button (no nested buttons);
            // when no favourite is requested the wrapper collapses to the
            // original single-button header — layout-identical.
            HStack(spacing: 0) {
                Button(action: configuration.toggleExpand) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        SliceLine(configuration: configuration, leg: configuration.leg)
                        Spacer(minLength: Theme.SpacingKey.xs.value)
                        Icon(systemName: "chevron.down").size(.xs).accent(.neutral)
                            .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                    }
                    .padding(configuration.spacing(.md))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(configuration.isExpanded ? "Collapse flight details" : "Expand flight details")

                if configuration.isFavorite != nil {
                    FavoriteHeart(configuration: configuration)
                        .padding(.trailing, Theme.SpacingKey.sm.value)
                }
            }

            if configuration.isExpanded {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                    ForEach(Array(configuration.legs.enumerated()), id: \.element.id) { index, leg in
                        legTimeline(leg)
                        if let layover = leg.layover, index < configuration.legs.count - 1 || configuration.legs.count == 1 {
                            layoverRow(layover)
                        }
                    }
                    if !configuration.amenities.isEmpty {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            ForEach(configuration.amenities, id: \.self) { symbol in
                                Icon(systemName: symbol).size(.sm).accent(.neutral)
                            }
                        }
                    }
                    HStack {
                        PriceBlock(configuration: configuration)
                        Spacer()
                        if let action = configuration.onSelect {
                            ThemeButton(configuration.selectTitle, action: action).size(.small)
                        }
                    }
                }
                .padding([.horizontal, .bottom], configuration.spacing(.md))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .itemShell(configuration, theme: theme)
    }

    private func legTimeline(_ leg: FlightLeg) -> some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            VStack(spacing: 0) {
                Circle().stroke(configuration.accentBorder(theme), lineWidth: 1.5).frame(width: 7, height: 7)
                Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1.5).frame(maxHeight: .infinity)
                Circle().fill(configuration.accentBorder(theme)).frame(width: 7, height: 7)
            }
            .padding(.vertical, 5)
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                Text("\(configuration.time(leg.departure))  \(leg.origin)")
                    .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                Text("\(leg.airline)\(configuration.flightNo.map { " · \($0)" } ?? "") · \(configuration.duration(of: leg))")
                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                Text("\(configuration.time(leg.arrival))  \(leg.destination)")
                    .textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    private func layoverRow(_ text: String) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Icon(systemName: "clock").size(.xs).accent(.warning)
            Text(text).textStyle(.labelSm600).foregroundStyle(theme.foreground(.systemcolorsFgWarning))
        }
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .background(theme.background(.systemcolorsBgWarningLight),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
}

// MARK: - 7. Slices — stacked itinerary rows

/// Expedia round-trip archetype: one card per itinerary — a labeled slice
/// row per leg, and a footer price qualified as the itinerary total. Scales
/// from round trips to multi-city (one row per slice).
public struct SlicesFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        SlicesChrome(configuration: configuration)
    }
}

private struct SlicesChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            ForEach(Array(configuration.legs.enumerated()), id: \.element.id) { index, leg in
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    if index < configuration.sliceLabels.count {
                        Text(configuration.sliceLabels[index])
                            .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                    SliceLine(configuration: configuration, leg: leg)
                }
                if index < configuration.legs.count - 1 {
                    Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
                }
            }
            if configuration.priceAmount != nil || configuration.onSelect != nil || configuration.isFavorite != nil {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
                HStack {
                    if configuration.legs.map(\.airline).uniqued().count > 1 {
                        Text(String(themeKit: "Mixed airlines")).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                    }
                    Spacer()
                    FavoriteHeart(configuration: configuration)
                    PriceBlock(configuration: configuration)
                }
            }
        }
        .padding(configuration.spacing(.md))
        .itemShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}

// MARK: - 8. Timetable — carrier-grouped departure chips

/// Skyscanner widget archetype for high-frequency routes: one card per
/// carrier, its schedule as tappable departure-time chips.
public struct TimetableFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TimetableChrome(configuration: configuration)
    }
}

private struct TimetableChrome: View {
    @Environment(\.theme) private var theme
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection
    let configuration: FlightListItemConfiguration
    /// Uncontrolled fallback — see ``FareBoardChrome/chosen``.
    @State private var chosen: Date?

    private var selectedDeparture: Date? {
        configuration.onDepartureSelect != nil ? configuration.selectedDeparture : chosen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 24, height: 24)
                Text(configuration.leg.airline).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                if let accessory = configuration.accessory { accessory }
                FavoriteHeart(configuration: configuration)
                PriceBlock(configuration: configuration, size: .small)
            }
            if let note = configuration.scheduleNote {
                Text(note).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            }
            FlowLayout(spacing: Theme.SpacingKey.xs.value, lineSpacing: Theme.SpacingKey.xs.value, layoutDirection: layoutDirection) {
                ForEach(configuration.departures, id: \.self) { date in
                    timeChip(date)
                }
            }
            if let footer = configuration.footer { footer }
        }
        .padding(configuration.spacing(.md))
        .itemShell(configuration, theme: theme)
    }

    private func timeChip(_ date: Date) -> some View {
        let selected = selectedDeparture == date
        return Button {
            if let onDepartureSelect = configuration.onDepartureSelect { onDepartureSelect(date) } else { chosen = date }
            configuration.onSelect?()
        } label: {
            Text(configuration.time(date))
                .textStyle(.labelSm700)
                .foregroundStyle(selected ? configuration.accentOnFill(theme) : theme.text(.textPrimary))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(selected ? configuration.accentFill(theme) : theme.background(.bgSecondaryLight),
                            in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

// MARK: - 9. Tray — nested card with a CTA rail (design-system spec)

/// A soft "tray" surface holding a white flight card, with the actions on the
/// tray itself: a details text-link leading and a per-person price + circular
/// go button trailing. Composed entirely from library atoms/molecules —
/// ``FlightRoute``, ``PriceTag``, ``TextLink``, ``ThemeButton``,
/// ``DividerView``, ``Icon``, ``Badge``.
public struct TrayFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TrayChrome(configuration: configuration)
    }
}

private struct TrayChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    // Spec radii: outer tray 24 (rd-base), inner white card 20 (= outer − the
    // 4pt tray inset, the standard concentric-rounding relationship).
    private var trayRadius: CGFloat { Theme.RadiusKey.base.value }
    private var cardRadius: CGFloat { Theme.RadiusKey.base.concentric(inset: .xs) }

    /// The tinted card-surface (spec `bg-surface` ≈ #f4f8fc). Derived, not a new
    /// token: white blended halfway with the theme's tinted page surface
    /// (`bgElevatorPrimary`), so it re-skins with ocean/sunset/dark. An explicit
    /// `.surface(_:)` still wins.
    private var traySurface: Color {
        if let key = configuration.surfaceKey { return theme.background(key) }
        return theme.background(.bgWhite).blended(with: theme.background(.bgElevatorPrimary), by: 0.5)
    }

    var body: some View {
        let leg = configuration.leg
        VStack(spacing: Theme.SpacingKey.xs.value) {
            // Inner white flight card: identity, route, meta (spec: 16pt pad, 8pt gaps).
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                HStack(spacing: 4) {
                    (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.sm).accent(.primary)))
                        .frame(width: 20, height: 20)
                    Text(leg.airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                    if let badge = configuration.badge {
                        Badge(badge).badgeStyle(.info).size(.small)
                    }
                    if configuration.isFavorite != nil {
                        Spacer(minLength: 0)
                        FavoriteHeart(configuration: configuration)
                    }
                }
                FlightRoute(from: leg.origin, to: leg.destination,
                            departure: leg.departure, arrival: leg.arrival)
                    .stops(leg.stops)
                    .flightRouteStyle(.inline)
                if configuration.cabin != nil || configuration.baggage != nil {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        if let cabin = configuration.cabin {
                            Text(cabin).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                        }
                        if configuration.cabin != nil && configuration.baggage != nil {
                            DividerView().axis(.vertical).frame(height: 16)
                        }
                        if let carryOn = configuration.baggage {
                            HStack(spacing: 2) {
                                Icon(systemName: "suitcase.rolling").size(.xs).accent(.neutral)
                                Text(carryOn).textStyle(.bodySm400).foregroundStyle(theme.text(.textPrimary))
                            }
                            HStack(spacing: 2) {
                                Icon(systemName: "cart").size(.xs).accent(.neutral)
                                Text(configuration.checkedBaggage ?? "–")
                                    .textStyle(.bodySm400).foregroundStyle(theme.text(.textPrimary))
                            }
                        }
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(configuration.spacing(.md))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(.bgWhite),
                        in: RoundedRectangle(cornerRadius: cardRadius, style: .continuous))

            // CTA rail on the tray (spec: 12pt sides / 4pt vertical):
            // details link · caption · stacked price · circular go button.
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let onDetails = configuration.onDetails {
                    TextLink(configuration.detailsTitle, action: onDetails).underline(false)
                }
                Spacer(minLength: Theme.SpacingKey.xs.value)
                if let caption = configuration.priceCaption {
                    Text(caption)
                        .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 72, alignment: .trailing)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let amount = configuration.priceAmount {
                    PriceTag(amount, currencyCode: configuration.currencyCode)
                        .original(configuration.originalAmount)
                        .originalBelow()
                        .size(.medium)
                }
                if let onSelect = configuration.onSelect {
                    ThemeButton(action: onSelect)
                        .icon(leading: "arrow.right")
                        .shape(.circle)
                        .color(.neutral)
                        .size(.small)
                        .accessibilityLabel(configuration.selectTitle)
                }
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.bottom, 4)
        }
        .padding(Theme.SpacingKey.xs.value)
        .background(traySurface,
                    in: RoundedRectangle(cornerRadius: trayRadius, style: .continuous))
        .overlay {
            if configuration.isSelected {
                RoundedRectangle(cornerRadius: trayRadius, style: .continuous)
                    .strokeBorder(configuration.accentBorder(theme), lineWidth: 1.5)
            }
        }
    }
}

// MARK: - 10. Tile — vertical carousel card

/// A vertical card for horizontal carousels (destination-deal shelves, "more
/// dates" rails): identity on top, the route in the middle, price pinned at the
/// bottom. Width comes from the carousel (`.frame(width:)`); the tile fills
/// whatever it's given.
public struct TileFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TileChrome(configuration: configuration)
    }
}

private struct TileChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        let leg = configuration.leg
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 24, height: 24)
                if let badge = configuration.badge {
                    Badge(badge).badgeStyle(.info).size(.small)
                }
                Spacer(minLength: 0)
                if let accessory = configuration.accessory { accessory }
                FavoriteHeart(configuration: configuration)
            }
            Text(leg.airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Text(leg.origin).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                // `arrow.forward` mirrors under RTL (unlike `arrow.right`).
                Icon(systemName: "arrow.forward").size(.xs).accent(.neutral)
                Text(leg.destination).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            }
            Text("\(configuration.time(leg.departure)) – \(configuration.time(leg.arrival)) · \(configuration.duration(of: leg))")
                .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            Text(configuration.stopsText(leg))
                .textStyle(.labelSm600)
                .foregroundStyle(leg.stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.foreground(.systemcolorsFgWarning))
            MetaRow(items: configuration.metaItems)
            Spacer(minLength: Theme.SpacingKey.xs.value)
            PriceBlock(configuration: configuration)
            if let footer = configuration.footer { footer }
        }
        .padding(configuration.spacing(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
        .itemShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}

// MARK: - 11. Hero — featured tall card

/// The featured/promoted archetype: a deal strip on top, prominent route block,
/// amenities, an extra-large price and a pinned CTA — the card a "today's best
/// deal" section leads with.
public struct HeroFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        HeroChrome(configuration: configuration)
    }
}

private struct HeroChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        let leg = configuration.leg
        VStack(alignment: .leading, spacing: 0) {
            if let deal = configuration.dealText {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Icon(systemName: "flame.fill").size(.xs).accent(configuration.dealTone)
                    Text(deal).textStyle(.labelSm700).foregroundStyle(theme.resolve(configuration.dealTone).base)
                    Spacer()
                }
                .padding(.horizontal, configuration.spacing(.md))
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(theme.resolve(configuration.dealTone).soft)
            }
            VStack(alignment: .leading, spacing: configuration.spacing(.md)) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 0) {
                        Text(leg.airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                        if let no = configuration.flightNo {
                            Text(no).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                        }
                    }
                    Spacer()
                    if let badge = configuration.badge {
                        Badge(badge).badgeStyle(.info).size(.small)
                    }
                    if let accessory = configuration.accessory { accessory }
                    FavoriteHeart(configuration: configuration)
                }
                HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                    TimeColumn(time: configuration.time(leg.departure), code: leg.origin, alignment: .leading)
                    RouteTrack(leg: leg, duration: configuration.duration(of: leg), stops: configuration.stopsText(leg))
                        .frame(maxWidth: .infinity)
                    TimeColumn(time: configuration.time(leg.arrival), code: leg.destination, alignment: .trailing)
                }
                if !configuration.amenities.isEmpty {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ForEach(configuration.amenities, id: \.self) { symbol in
                            Icon(systemName: symbol).size(.sm).accent(.neutral)
                        }
                    }
                }
                MetaRow(items: configuration.metaItems)
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
                HStack(alignment: .bottom) {
                    PriceBlock(configuration: configuration, size: .xlarge)
                    Spacer()
                    if let action = configuration.onSelect {
                        ThemeButton(configuration.selectTitle, action: action).size(.small)
                    }
                }
                if let footer = configuration.footer { footer }
            }
            .padding(configuration.spacing(.md))
        }
        .clipShape(RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous))
        .itemShell(configuration, theme: theme)
        .contentShape(Rectangle())
        .onTapGesture { configuration.onSelect?() }
    }
}

// MARK: - 12. Receipt — checkout summary, labeled fields

/// The checkout-summary archetype: every slice as a labeled row, then fare,
/// baggage and meta as labeled fields, closed by the itinerary total. **No tap
/// affordance** — it's a read-back of what the user already chose, not a
/// selectable result (so `onSelect` is deliberately not wired).
public struct ReceiptFlightListItemStyle: FlightListItemStyle {
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        ReceiptChrome(configuration: configuration)
    }
}

private struct ReceiptChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            ForEach(Array(configuration.legs.enumerated()), id: \.element.id) { index, leg in
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    if index < configuration.sliceLabels.count {
                        Text(configuration.sliceLabels[index])
                            .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                    SliceLine(configuration: configuration, leg: leg)
                }
            }
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
            if let no = configuration.flightNo { fieldRow(String(themeKit: "Flight"), no) }
            if let cabin = configuration.cabin { fieldRow(String(themeKit: "Fare"), cabin) }
            if let carryOn = configuration.baggage {
                fieldRow(String(themeKit: "Carry-on"), carryOn)
                fieldRow(String(themeKit: "Checked bag"),
                         configuration.checkedBaggage ?? String(themeKit: "Not included"))
            }
            ForEach(Array(configuration.metaItems.enumerated()), id: \.offset) { _, item in
                fieldRow(item.text, icon: item.icon)
            }
            if let amount = configuration.priceAmount {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
                // The caption doubles as the total row's label, so the price
                // itself renders bare (no PriceBlock — that would repeat it).
                HStack(alignment: .firstTextBaseline) {
                    Text(configuration.priceCaption ?? String(themeKit: "Total"))
                        .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    Spacer()
                    PriceTag(amount, currencyCode: configuration.currencyCode)
                        .original(configuration.originalAmount)
                }
            }
            if let footer = configuration.footer { footer }
        }
        .padding(configuration.spacing(.md))
        .itemShell(configuration, theme: theme)
        // No contentShape/onTapGesture: a receipt is not a tappable result row.
    }

    private func fieldRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            Spacer(minLength: Theme.SpacingKey.sm.value)
            Text(value).textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
                .multilineTextAlignment(.trailing)
        }
    }

    /// A meta item rendered receipt-style: icon leading, text as the value.
    private func fieldRow(_ text: String, icon: String) -> some View {
        HStack(alignment: .center) {
            Icon(systemName: icon).size(.xs).accent(.neutral)
            Spacer(minLength: Theme.SpacingKey.sm.value)
            Text(text).textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
                .multilineTextAlignment(.trailing)
        }
    }
}

// MARK: - Static accessors

public extension FlightListItemStyle where Self == CompactFlightListItemStyle {
    /// One-line timetable row — dense schedule lists (Google Flights condensed).
    static var compact: CompactFlightListItemStyle { CompactFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == TimelineFlightListItemStyle {
    /// The de-facto standard route-track card (Kayak/Skyscanner). The default.
    static var timeline: TimelineFlightListItemStyle { TimelineFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == FareBoardFlightListItemStyle {
    /// Fare-family chips with per-fare prices (Delta/THY shopping).
    static var fareBoard: FareBoardFlightListItemStyle { FareBoardFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == DealFlightListItemStyle {
    /// Price-judgment header + strikethrough + sparkline (Hopper).
    static var deal: DealFlightListItemStyle { DealFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == TicketFlightListItemStyle {
    /// Perforated boarding-ticket card — featured/hero rows.
    static var ticket: TicketFlightListItemStyle { TicketFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == JourneyFlightListItemStyle {
    /// Expandable per-leg vertical timeline with layover rows (Kayak details).
    static var journey: JourneyFlightListItemStyle { JourneyFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == SlicesFlightListItemStyle {
    /// One card per itinerary: stacked labeled slice rows + total price (Expedia).
    static var slices: SlicesFlightListItemStyle { SlicesFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == TimetableFlightListItemStyle {
    /// Carrier-grouped departure-time chips (Skyscanner timetable widget).
    static var timetable: TimetableFlightListItemStyle { TimetableFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == TrayFlightListItemStyle {
    /// Nested white card on a soft tray with a details/price/go CTA rail
    /// (design-system spec) — built from FlightRoute, PriceTag, TextLink & co.
    static var tray: TrayFlightListItemStyle { TrayFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == TileFlightListItemStyle {
    /// Vertical card for horizontal carousels: logo top, route mid, price bottom.
    static var tile: TileFlightListItemStyle { TileFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == HeroFlightListItemStyle {
    /// Featured tall card: deal strip + big price + badge + amenities.
    static var hero: HeroFlightListItemStyle { HeroFlightListItemStyle() }
}
public extension FlightListItemStyle where Self == ReceiptFlightListItemStyle {
    /// Checkout summary — slices, fare and baggage as labeled fields, no tap affordance.
    static var receipt: ReceiptFlightListItemStyle { ReceiptFlightListItemStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightListItemStyle: FlightListItemStyle {
    private let _makeBody: @MainActor (FlightListItemConfiguration) -> AnyView
    init<S: FlightListItemStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightListItemConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightListItemStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightListItemStyle(TimelineFlightListItemStyle())
}

extension EnvironmentValues {
    var flightListItemStyle: AnyFlightListItemStyle {
        get { self[FlightListItemStyleKey.self] }
        set { self[FlightListItemStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightListItemStyle`` for `FlightListItem`s in this view and
    /// its descendants — one result list can mix archetypes per section.
    func flightListItemStyle<S: FlightListItemStyle>(_ style: sending S) -> some View {
        environment(\.flightListItemStyle, AnyFlightListItemStyle(style))
    }
}
