//
//  FlightRouteStyle.swift
//  ThemeKit
//
//  The styling hook for ``FlightRoute`` — promotes the former
//  ``FlightRouteTrack`` enum (ADR-0004) so the segment drawn between the two
//  time columns is a swappable style, settable once per screen via the
//  environment. Four built-ins map 1:1 to the old track cases:
//
//    .path    duration over a short colored capsule, stops below — default
//    .inline  full-width hairlines flanking the duration (design-system spec)
//    .arc     dashed arc with a plane glyph at the apex (mirrors under RTL)
//    .dots    endpoint dots on a hairline, hollow mid-line dots per stop
//
//      FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: arr)
//          .stops(1)
//          .flightRouteStyle(.arc)
//
//  Component style arranges content; token theme colors everything. A style
//  that draws absolute `Path` geometry must flip it for RTL
//  (`.flipsForRightToLeftLayoutDirection(true)`), as `.arc` does.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FlightRouteStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no cities → single-line columns, no override →
/// computed duration).
public struct FlightRouteConfiguration {
    /// Departure airport code ("IST").
    public let origin: String
    /// Arrival airport code ("JFK").
    public let destination: String
    public let departure: Date
    public let arrival: Date
    /// Number of stops (0 = direct).
    public let stops: Int
    /// Whether the arrival lands the next day — styles append a "+1" marker.
    public let nextDay: Bool
    /// Optional city names rendered under each airport code (`.cityNames(_:_:)`).
    public let originCity: String?
    public let destinationCity: String?
    /// Explicit duration label (`.durationText(_:)`); prefer ``durationText``,
    /// which falls back to the computed leg duration.
    public let durationOverride: String?
    /// Semantic tone for the 1+-stop label (`.stopsTone(_:)`); `nil` = tertiary
    /// text. Resolve via ``stopsLabelColor(_:)``.
    public let stopsTone: SemanticColor?
    /// Path/direct-label colour token (`.pathColor(_:)`, default success green).
    /// Resolve via ``pathAccent(_:)`` so the ``accent`` axis wins when set.
    public let pathColorKey: Theme.ForegroundColorKey
    /// Type ramp (`.size(_:)`) — steps the time / code / duration styles together.
    public let size: FlightRouteSize
    /// Semantic accent override (`.accent(_:)`); `nil` = the ``pathColorKey``
    /// token. Resolve via ``pathAccent(_:)``.
    public let accent: SemanticColor?
    /// The environment's component density, captured by the component — scale
    /// chrome gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// date/number string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// Density-scaled spacing — use for chrome gaps so `.componentDensity`
    /// compacts or airs out the route.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// Locale-captured short time ("09:41").
    public func time(_ date: Date) -> String {
        date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
    }

    /// The `.durationText(_:)` override, or the computed leg duration ("2h 30m").
    public var durationText: String {
        if let durationOverride { return durationOverride }
        let minutes = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? String(themeKit: "\(h)h \(m)m") : String(themeKit: "\(m)m")
    }

    /// "Direct" / "1 stop" / "n stops", resolved against ThemeKit's own catalog.
    public var stopsText: String {
        switch stops {
        case 0: return String(themeKit: "Direct")
        case 1: return String(themeKit: "1 stop")
        default: return String(themeKit: "\(stops) stops")
        }
    }

    // Accent resolution — the `accent(_:)` override, else the `pathColor(_:)`
    // token (the value the built-ins used before the accent axis existed).
    /// The route's accent colour — direct-flight track fill, plane glyph, dots.
    public func pathAccent(_ theme: Theme) -> Color { accent?.base ?? theme.foreground(pathColorKey) }
    /// Track-line fill: the accent when direct, a hairline border otherwise.
    public func trackLineColor(_ theme: Theme) -> Color {
        stops == 0 ? pathAccent(theme) : theme.border(.borderPrimary)
    }
    /// Stops-label colour: direct keeps the accent, 1+ stops uses ``stopsTone``
    /// (default tertiary).
    public func stopsLabelColor(_ theme: Theme) -> Color {
        stops == 0 ? pathAccent(theme) : (stopsTone?.base ?? theme.text(.textTertiary))
    }
}

// MARK: - Protocol

/// Defines a `FlightRoute`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's leg data. Set one with `.flightRouteStyle(_:)`; the
/// default is ``PathFlightRouteStyle``.
public protocol FlightRouteStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FlightRouteConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The (time, code, duration) text-style triple per ``FlightRouteSize`` step —
/// the standard family (`.path`/`.arc`/`.dots`) and the quieter inline family.
private struct RouteTypeRamp {
    let time: TextStyle
    let code: TextStyle
    let duration: TextStyle

    static func standard(_ size: FlightRouteSize) -> RouteTypeRamp {
        switch size {
        case .compact: RouteTypeRamp(time: .labelSm700, code: .overline400, duration: .overline400)
        case .regular: RouteTypeRamp(time: .labelBase700, code: .overline500, duration: .overline400)
        case .large: RouteTypeRamp(time: .labelMd700, code: .labelSm600, duration: .bodySm400)
        }
    }
    static func inline(_ size: FlightRouteSize) -> RouteTypeRamp {
        switch size {
        case .compact: RouteTypeRamp(time: .labelBase600, code: .overline500, duration: .overline400)
        case .regular: RouteTypeRamp(time: .labelMd600, code: .bodySm400, duration: .bodySm400)
        case .large: RouteTypeRamp(time: .labelLg600, code: .bodyBase400, duration: .bodyBase400)
        }
    }
}

/// One endpoint column: time (+ optional "+1" marker), airport code, optional city.
private struct RouteTimeColumn: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration
    let date: Date
    let code: String
    let city: String?
    let alignment: HorizontalAlignment
    let marker: String?
    let ramp: RouteTypeRamp
    let isInline: Bool

    var body: some View {
        VStack(alignment: alignment, spacing: isInline ? 0 : 2) {
            HStack(alignment: .top, spacing: 2) {
                Text(configuration.time(date))
                    .textStyle(ramp.time)
                    .foregroundStyle(theme.text(.textPrimary))
                if let marker { Text(marker).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary)) }
            }
            Text(code)
                .textStyle(ramp.code)
                .foregroundStyle(theme.text(.textSecondary))
            if let city {
                Text(city).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1)
            }
        }
        .fixedSize()
    }
}

/// A filled accent endpoint dot (`.dots` track ends).
private struct RouteEndpointDot: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration
    var body: some View {
        Circle().fill(configuration.pathAccent(theme)).frame(width: 6, height: 6)
    }
}

/// A hollow mid-line stop dot shared by `.path` and `.dots`.
private struct RouteStopDot: View {
    @Environment(\.theme) private var theme
    var body: some View {
        Circle().fill(theme.background(.bgBase)).frame(width: 6, height: 6)
            .overlay(Circle().stroke(theme.text(.textTertiary), lineWidth: 1.5))
    }
}

/// A shallow quad-curve arc from the leading to the trailing edge, apex at the top.
private struct RouteArcLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                           control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
        }
    }
}

// MARK: - 1. Path — capsule track (default)

/// The stock look: duration over a short colored capsule, stops below.
public struct PathFlightRouteStyle: FlightRouteStyle {
    public init() {}
    public func makeBody(configuration: FlightRouteConfiguration) -> some View {
        PathFlightRouteChrome(configuration: configuration)
    }
}

private struct PathFlightRouteChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration

    var body: some View {
        let ramp = RouteTypeRamp.standard(configuration.size)
        HStack(spacing: configuration.spacing(.sm)) {
            RouteTimeColumn(configuration: configuration, date: configuration.departure,
                            code: configuration.origin, city: configuration.originCity,
                            alignment: .leading, marker: nil, ramp: ramp, isInline: false)
            VStack(spacing: 3) {
                Text(configuration.durationText).textStyle(ramp.duration).foregroundStyle(theme.text(.textSecondary))
                ZStack {
                    Capsule().fill(configuration.trackLineColor(theme)).frame(height: 2)
                    if configuration.stops > 0 {
                        HStack(spacing: 10) {
                            ForEach(0..<min(configuration.stops, 3), id: \.self) { _ in RouteStopDot() }
                        }
                    }
                }
                .frame(width: 46)
                Text(configuration.stopsText).textStyle(ramp.duration)
                    .foregroundStyle(configuration.stopsLabelColor(theme))
            }
            .frame(maxWidth: .infinity)
            RouteTimeColumn(configuration: configuration, date: configuration.arrival,
                            code: configuration.destination, city: configuration.destinationCity,
                            alignment: .trailing, marker: configuration.nextDay ? "+1" : nil,
                            ramp: ramp, isInline: false)
        }
    }
}

// MARK: - 2. Inline — hairline track (design-system spec)

/// Full-width hairlines flanking the duration, the stops label centered
/// beneath in tertiary — no capsule, no accent.
public struct InlineFlightRouteStyle: FlightRouteStyle {
    public init() {}
    public func makeBody(configuration: FlightRouteConfiguration) -> some View {
        InlineFlightRouteChrome(configuration: configuration)
    }
}

private struct InlineFlightRouteChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration

    var body: some View {
        let ramp = RouteTypeRamp.inline(configuration.size)
        HStack(spacing: configuration.spacing(.lg)) {
            RouteTimeColumn(configuration: configuration, date: configuration.departure,
                            code: configuration.origin, city: configuration.originCity,
                            alignment: .trailing, marker: nil, ramp: ramp, isInline: true)
            VStack(spacing: 0) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
                    Text(configuration.durationText)
                        .textStyle(ramp.duration)
                        .foregroundStyle(theme.text(.textPrimary))
                        .fixedSize()
                    Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
                }
                Text(configuration.stopsText).textStyle(ramp.duration)
                    .foregroundStyle(configuration.stops > 0
                        ? (configuration.stopsTone?.base ?? theme.text(.textTertiary))
                        : theme.text(.textTertiary))
            }
            .frame(maxWidth: .infinity)
            RouteTimeColumn(configuration: configuration, date: configuration.arrival,
                            code: configuration.destination, city: configuration.destinationCity,
                            alignment: .leading, marker: configuration.nextDay ? "+1" : nil,
                            ramp: ramp, isInline: true)
        }
    }
}

// MARK: - 3. Arc — dashed arc + plane glyph

/// A dashed arc with a plane glyph at its apex. The `Path` is absolute
/// geometry, so it's flipped explicitly for RTL and the plane glyph mirrors.
public struct ArcFlightRouteStyle: FlightRouteStyle {
    public init() {}
    public func makeBody(configuration: FlightRouteConfiguration) -> some View {
        ArcFlightRouteChrome(configuration: configuration)
    }
}

private struct ArcFlightRouteChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration

    var body: some View {
        let ramp = RouteTypeRamp.standard(configuration.size)
        HStack(spacing: configuration.spacing(.sm)) {
            RouteTimeColumn(configuration: configuration, date: configuration.departure,
                            code: configuration.origin, city: configuration.originCity,
                            alignment: .leading, marker: nil, ramp: ramp, isInline: false)
            VStack(spacing: 3) {
                Text(configuration.durationText).textStyle(ramp.duration).foregroundStyle(theme.text(.textSecondary))
                ZStack(alignment: .top) {
                    RouteArcLine()
                        .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                        .flipsForRightToLeftLayoutDirection(true)
                    Image(systemName: "airplane")
                        .textStyle(ramp.code)
                        .foregroundStyle(configuration.pathAccent(theme))
                        .mirrorsInRTL()
                        .offset(y: -2)
                }
                .frame(width: 56, height: 14)
                Text(configuration.stopsText).textStyle(ramp.duration)
                    .foregroundStyle(configuration.stopsLabelColor(theme))
            }
            .frame(maxWidth: .infinity)
            RouteTimeColumn(configuration: configuration, date: configuration.arrival,
                            code: configuration.destination, city: configuration.destinationCity,
                            alignment: .trailing, marker: configuration.nextDay ? "+1" : nil,
                            ramp: ramp, isInline: false)
        }
    }
}

// MARK: - 4. Dots — endpoint dots on a hairline

/// Endpoint dots on a hairline, with hollow mid-line dots per stop.
public struct DotsFlightRouteStyle: FlightRouteStyle {
    public init() {}
    public func makeBody(configuration: FlightRouteConfiguration) -> some View {
        DotsFlightRouteChrome(configuration: configuration)
    }
}

private struct DotsFlightRouteChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration

    var body: some View {
        let ramp = RouteTypeRamp.standard(configuration.size)
        HStack(spacing: configuration.spacing(.sm)) {
            RouteTimeColumn(configuration: configuration, date: configuration.departure,
                            code: configuration.origin, city: configuration.originCity,
                            alignment: .leading, marker: nil, ramp: ramp, isInline: false)
            VStack(spacing: 3) {
                Text(configuration.durationText).textStyle(ramp.duration).foregroundStyle(theme.text(.textSecondary))
                ZStack {
                    Capsule().fill(theme.border(.borderPrimary)).frame(height: 2)
                    HStack(spacing: 0) {
                        RouteEndpointDot(configuration: configuration)
                        Spacer(minLength: 0)
                        if configuration.stops > 0 {
                            HStack(spacing: 8) {
                                ForEach(0..<min(configuration.stops, 3), id: \.self) { _ in RouteStopDot() }
                            }
                            Spacer(minLength: 0)
                        }
                        RouteEndpointDot(configuration: configuration)
                    }
                }
                .frame(width: 56)
                Text(configuration.stopsText).textStyle(ramp.duration)
                    .foregroundStyle(configuration.stopsLabelColor(theme))
            }
            .frame(maxWidth: .infinity)
            RouteTimeColumn(configuration: configuration, date: configuration.arrival,
                            code: configuration.destination, city: configuration.destinationCity,
                            alignment: .trailing, marker: configuration.nextDay ? "+1" : nil,
                            ramp: ramp, isInline: false)
        }
    }
}

// MARK: - Static accessors

public extension FlightRouteStyle where Self == PathFlightRouteStyle {
    /// Duration over a short colored capsule, stops below. The default.
    static var path: PathFlightRouteStyle { PathFlightRouteStyle() }
}
public extension FlightRouteStyle where Self == InlineFlightRouteStyle {
    /// Full-width hairlines flanking the duration (design-system spec).
    static var inline: InlineFlightRouteStyle { InlineFlightRouteStyle() }
}
public extension FlightRouteStyle where Self == ArcFlightRouteStyle {
    /// A dashed arc with a plane glyph at its apex (mirrors under RTL).
    static var arc: ArcFlightRouteStyle { ArcFlightRouteStyle() }
}
public extension FlightRouteStyle where Self == DotsFlightRouteStyle {
    /// Endpoint dots on a hairline, hollow mid-line dots per stop.
    static var dots: DotsFlightRouteStyle { DotsFlightRouteStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFlightRouteStyle: FlightRouteStyle {
    private let _makeBody: @MainActor (FlightRouteConfiguration) -> AnyView
    init<S: FlightRouteStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FlightRouteConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FlightRouteStyleKey: EnvironmentKey {
    static let defaultValue = AnyFlightRouteStyle(PathFlightRouteStyle())
}

extension EnvironmentValues {
    var flightRouteStyle: AnyFlightRouteStyle {
        get { self[FlightRouteStyleKey.self] }
        set { self[FlightRouteStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FlightRouteStyle`` for `FlightRoute`s in this view and its
    /// descendants — one result list can restyle every route at once.
    func flightRouteStyle<S: FlightRouteStyle>(_ style: sending S) -> some View {
        environment(\.flightRouteStyle, AnyFlightRouteStyle(style))
    }
}
