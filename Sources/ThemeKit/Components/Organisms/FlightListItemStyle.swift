//
//  FlightListItemStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightListItem`` — and the most data-rich style
//  protocol in the library: the configuration hands styles the *typed flight
//  data* (legs, fares, deal signals, schedule), not pre-laid content, so a
//  style owns the entire layout. Eight built-ins cover the industry's
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
//
//      FlightListItem(legs: [out, back]).price(438, caption: "total")
//          .flightListItemStyle(.slices)
//

import SwiftUI

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

    /// The itinerary's first leg — every style's primary subject.
    public var leg: FlightLeg { legs[0] }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

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
            .stroke(tone.base, style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round))
        }
        .flipsForRightToLeftLayoutDirection(true)
    }
}

/// The card shell every carded built-in shares: surface fill, continuous
/// corners, hairline border (accented when selected).
private extension View {
    func itemShell(_ configuration: FlightListItemConfiguration, theme: Theme) -> some View {
        self
            .background(theme.background(configuration.surface(default: .bgBase)),
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
                    .strokeBorder(configuration.isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
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
                PriceBlock(configuration: configuration, size: .small)
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
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
    public init() {}
    public func makeBody(configuration: FlightListItemConfiguration) -> some View {
        TimelineChrome(configuration: configuration)
    }
}

private struct TimelineChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightListItemConfiguration

    var body: some View {
        let leg = configuration.leg
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let badge = configuration.badge {
                Badge(badge).badgeStyle(.info).size(.small)
            }
            HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
                TimeColumn(time: configuration.time(leg.departure), code: leg.origin, alignment: .leading)
                RouteTrack(leg: leg, duration: configuration.duration(of: leg), stops: configuration.stopsText(leg))
                    .frame(maxWidth: .infinity)
                TimeColumn(time: configuration.time(leg.arrival), code: leg.destination, alignment: .trailing)
            }
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
                PriceBlock(configuration: configuration)
            }
        }
        .padding(Theme.SpacingKey.md.value)
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
    @State private var chosen: String?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            SliceLine(configuration: configuration, leg: configuration.leg)
            if !configuration.fares.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ForEach(configuration.fares) { fare in
                            fareChip(fare)
                        }
                    }
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .itemShell(configuration, theme: theme)
    }

    private func fareChip(_ fare: FlightFare) -> some View {
        let selected = chosen == fare.id
        return Button {
            chosen = fare.id
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
                    .strokeBorder(selected ? theme.border(.borderHero) : .clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
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
                    Text(deal).textStyle(.labelSm700).foregroundStyle(configuration.dealTone.base)
                    Spacer()
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(configuration.dealTone.soft)
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
                PriceBlock(configuration: configuration)
            }
            .padding(Theme.SpacingKey.md.value)
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
            .padding(Theme.SpacingKey.md.value)
            perforation
            HStack(spacing: Theme.SpacingKey.sm.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 22, height: 22)
                Text(configuration.flightNo ?? leg.airline)
                    .textStyle(.labelSm700).foregroundStyle(theme.text(.textSecondary))
                Spacer()
                PriceBlock(configuration: configuration, size: .small)
            }
            .padding(Theme.SpacingKey.md.value)
        }
        .background(theme.background(configuration.surface(default: .bgBase)))
        .clipShape(TicketNotchShape(stubHeight: 58, radius: 7))
        .overlay(
            TicketNotchShape(stubHeight: 58, radius: 7)
                .stroke(configuration.isSelected ? theme.border(.borderHero) : theme.border(.borderPrimary),
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
            Text(time).textStyle(.labelSm600).foregroundStyle(theme.foreground(.fgHero))
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
private struct TicketNotchShape: Shape {
    let stubHeight: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        let y = rect.height - stubHeight
        var p = RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).path(in: rect)
        var cut = Path()
        cut.addEllipse(in: CGRect(x: rect.minX - radius, y: y - radius, width: radius * 2, height: radius * 2))
        cut.addEllipse(in: CGRect(x: rect.maxX - radius, y: y - radius, width: radius * 2, height: radius * 2))
        p = p.subtracting(cut)
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
            Button(action: configuration.toggleExpand) {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    SliceLine(configuration: configuration, leg: configuration.leg)
                    Spacer(minLength: Theme.SpacingKey.xs.value)
                    Icon(systemName: "chevron.down").size(.xs).accent(.neutral)
                        .rotationEffect(.degrees(configuration.isExpanded ? 180 : 0))
                }
                .padding(Theme.SpacingKey.md.value)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.isExpanded ? "Collapse flight details" : "Expand flight details")

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
                .padding([.horizontal, .bottom], Theme.SpacingKey.md.value)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .itemShell(configuration, theme: theme)
    }

    private func legTimeline(_ leg: FlightLeg) -> some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            VStack(spacing: 0) {
                Circle().stroke(theme.border(.borderHero), lineWidth: 1.5).frame(width: 7, height: 7)
                Rectangle().fill(theme.border(.borderPrimary)).frame(width: 1.5).frame(maxHeight: .infinity)
                Circle().fill(theme.border(.borderHero)).frame(width: 7, height: 7)
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
            if configuration.priceAmount != nil || configuration.onSelect != nil {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 0.5)
                HStack {
                    if configuration.legs.map(\.airline).uniqued().count > 1 {
                        Text("Mixed airlines").textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
                    }
                    Spacer()
                    PriceBlock(configuration: configuration)
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
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
    let configuration: FlightListItemConfiguration
    @State private var chosen: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                (configuration.logo ?? AnyView(Icon(systemName: configuration.airlineSystemImage).size(.md).accent(.primary)))
                    .frame(width: 24, height: 24)
                Text(configuration.leg.airline).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                Spacer()
                PriceBlock(configuration: configuration, size: .small)
            }
            if let note = configuration.scheduleNote {
                Text(note).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            }
            FlowLayout(spacing: Theme.SpacingKey.xs.value, lineSpacing: Theme.SpacingKey.xs.value) {
                ForEach(configuration.departures, id: \.self) { date in
                    timeChip(date)
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .itemShell(configuration, theme: theme)
    }

    private func timeChip(_ date: Date) -> some View {
        let selected = chosen == date
        return Button {
            chosen = date
            configuration.onSelect?()
        } label: {
            Text(configuration.time(date))
                .textStyle(.labelSm700)
                .foregroundStyle(selected ? theme.foreground(.fgSecondary) : theme.text(.textPrimary))
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, Theme.SpacingKey.xs.value)
                .background(selected ? theme.background(.bgHero) : theme.background(.bgSecondaryLight),
                            in: Capsule(style: .continuous))
        }
        .buttonStyle(.plain)
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
                }
                FlightRoute(from: leg.origin, to: leg.destination,
                            departure: leg.departure, arrival: leg.arrival)
                    .stops(leg.stops)
                    .track(.inline)
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
            .padding(Theme.SpacingKey.md.value)
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
                    .strokeBorder(theme.border(.borderHero), lineWidth: 1.5)
            }
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
