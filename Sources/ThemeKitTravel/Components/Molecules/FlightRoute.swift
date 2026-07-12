//
//  FlightRoute.swift
//  ThemeKit
//
//  Molecule. A single flight leg's route: departure time+code → a duration/stops
//  path → arrival time+code. Extracted so it can be reused on its own, stacked for
//  round-trips inside ``FlightResultRow``, or dropped into any custom flight layout.
//  Presentation is style-driven (``FlightRouteStyle``, ADR-0004) — set once per
//  screen via `.flightRouteStyle(_:)`. Token-bound.
//
//  ```swift
//  FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: arr).stops(1)
//      .flightRouteStyle(.arc)      // .path (default) / .inline / .dots
//  ```
//

import SwiftUI
import ThemeKit

/// How ``FlightRoute`` draws the segment between the two time columns.
///
/// Superseded by ``FlightRouteStyle`` (each case maps 1:1 to a preset —
/// `.path`/`.inline`/`.arc`/`.dots`); kept for source compatibility until the
/// next major, together with the deprecated ``FlightRoute/track(_:)`` modifier.
public enum FlightRouteTrack {
    /// The stock look: duration over a short colored capsule, stops below.
    case path
    /// Design-system spec: full-width hairlines flanking the duration, the
    /// stops label centered beneath in tertiary — no capsule, no accent.
    case inline
    /// A dashed arc with a plane glyph at its apex (mirrors under RTL).
    case arc
    /// Endpoint dots on a hairline, with hollow mid-line dots per stop.
    case dots
}

/// Type ramp for ``FlightRoute`` — steps the time / code / duration text styles
/// together (default `.regular`, the stock mapping).
public enum FlightRouteSize: Sendable { case compact, regular, large }

public struct FlightRoute: View {
    @Environment(\.flightRouteStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale

    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    private var stops = 0
    private var nextDay = false
    private var accentKey: Theme.ForegroundColorKey = .systemcolorsFgSuccess
    private var accentTone: SemanticColor?
    private var size: FlightRouteSize = .regular
    private var originCity: String?
    private var destinationCity: String?
    private var durationOverride: String?
    private var stopsTone: SemanticColor?
    /// Set by the deprecated ``track(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's `.flightRouteStyle(_:)`
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyFlightRouteStyle?

    public init(from origin: String, to destination: String, departure: Date, arrival: Date) {   // R1
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    public var body: some View {
        let configuration = FlightRouteConfiguration(
            origin: origin, destination: destination,
            departure: departure, arrival: arrival,
            stops: stops, nextDay: nextDay,
            originCity: originCity, destinationCity: destinationCity,
            durationOverride: durationOverride, stopsTone: stopsTone,
            pathColorKey: accentKey, size: size, accent: accentTone,
            density: density, locale: locale
        )
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilitySummary(configuration))
    }

    private func accessibilitySummary(_ configuration: FlightRouteConfiguration) -> String {
        let departs = configuration.time(departure)
        let arrives = configuration.time(arrival)
        return String(themeKit: "\(origin) \(departs) to \(destination) \(arrives), \(configuration.durationText), \(stopsAccessibility)")
    }

    private var stopsAccessibility: String {
        switch stops {
        case 0: return String(themeKit: "direct")
        case 1: return String(themeKit: "1 stop")
        default: return String(themeKit: "\(stops) stops")
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightRoute {
    /// Number of stops (0 = direct, shown in the accent colour).
    func stops(_ count: Int) -> Self { copy { $0.stops = max(0, count) } }
    /// Marks the arrival as landing the next day (adds a "+1").
    func nextDay(_ on: Bool = true) -> Self { copy { $0.nextDay = on } }
    /// Path/direct-label colour (foreground token key, default success green).
    func pathColor(_ key: Theme.ForegroundColorKey) -> Self { copy { $0.accentKey = key } }
    /// Semantic accent override for the track/glyph/direct label; `nil` (the
    /// default) keeps the ``pathColor(_:)`` token.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentTone = color } }
    /// Track presentation — superseded by the style axis: prefer
    /// `.flightRouteStyle(.path/.inline/.arc/.dots)`, settable once per screen
    /// via the environment. This modifier keeps working and, when called,
    /// wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .flightRouteStyle(.path/.inline/.arc/.dots) instead")
    func track(_ t: FlightRouteTrack) -> Self {
        copy {
            switch t {
            case .path: $0.explicitStyle = AnyFlightRouteStyle(PathFlightRouteStyle())
            case .inline: $0.explicitStyle = AnyFlightRouteStyle(InlineFlightRouteStyle())
            case .arc: $0.explicitStyle = AnyFlightRouteStyle(ArcFlightRouteStyle())
            case .dots: $0.explicitStyle = AnyFlightRouteStyle(DotsFlightRouteStyle())
            }
        }
    }
    /// Type ramp — steps the time / code / duration styles together
    /// (default `.regular`, the stock mapping).
    func size(_ s: FlightRouteSize) -> Self { copy { $0.size = s } }
    /// Optional city names rendered as a second line under each airport code.
    func cityNames(_ origin: String, _ destination: String) -> Self {
        copy { $0.originCity = origin; $0.destinationCity = destination }
    }
    /// Override the computed duration label ("2h 30m"); `nil` restores the
    /// computed text.
    func durationText(_ text: String?) -> Self { copy { $0.durationOverride = text } }
    /// Semantic tone for the 1+-stop label (default tertiary text). Direct
    /// flights keep the ``pathColor(_:)`` accent.
    func stopsTone(_ color: SemanticColor?) -> Self { copy { $0.stopsTone = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Previews

/// Proves external implementability: a one-line summary style built purely
/// from the public configuration + theme tokens.
private struct SummaryLineFlightRouteStyle: FlightRouteStyle {
    func makeBody(configuration: FlightRouteConfiguration) -> some View {
        SummaryLineChrome(configuration: configuration)
    }
}

private struct SummaryLineChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FlightRouteConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.xs)) {
            Text("\(configuration.origin) \(configuration.time(configuration.departure))")
                .textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
            Image(systemName: "arrow.right")
                .textStyle(.overline500)
                .foregroundStyle(configuration.pathAccent(theme))
                .mirrorsInRTL()
            Text("\(configuration.destination) \(configuration.time(configuration.arrival))")
                .textStyle(.labelSm700).foregroundStyle(theme.text(.textPrimary))
            Text(configuration.durationText)
                .textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
        }
    }
}

#Preview {
    let dep = Date()
    PreviewMatrix("FlightRoute") {
        PreviewCase("Path (default) · direct") {
            FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
        }
        PreviewCase("Path · 1 stop · next day") {
            FlightRoute(from: "AYT", to: "IST", departure: dep, arrival: dep.addingTimeInterval(230 * 60))
                .stops(1)
                .nextDay()
        }
        PreviewCase("Inline") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .stops(1)
                .flightRouteStyle(.inline)
        }
        PreviewCase("Arc + city names") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .cityNames("Istanbul", "New York")
                .flightRouteStyle(.arc)
        }
        PreviewCase("Dots · 2 stops · warning tone") {
            FlightRoute(from: "IST", to: "SYD", departure: dep, arrival: dep.addingTimeInterval(1_300 * 60))
                .stops(2)
                .stopsTone(.warning)
                .flightRouteStyle(.dots)
        }
        PreviewCase("Compact / regular / large") {
            VStack(spacing: 16) {
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60)).size(.compact)
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60)).size(.large)
            }
        }
        PreviewCase("Duration override · accent") {
            FlightRoute(from: "IST", to: "FRA", departure: dep, arrival: dep.addingTimeInterval(200 * 60))
                .durationText("3h+")
                .accent(.info)
        }
        PreviewCase("Custom style (SummaryLine)") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .flightRouteStyle(SummaryLineFlightRouteStyle())
        }
        PreviewCase("Arc · RTL") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .flightRouteStyle(.arc)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
