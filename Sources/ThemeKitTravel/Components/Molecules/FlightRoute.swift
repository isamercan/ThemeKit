//
//  FlightRoute.swift
//  ThemeKit
//
//  Molecule. A single flight leg's route: departure time+code → a duration/stops
//  path → arrival time+code. Extracted so it can be reused on its own, stacked for
//  round-trips inside ``FlightResultRow``, or dropped into any custom flight layout.
//  Token-bound.
//
//  ```swift
//  FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: arr).stops(1)
//  ```
//

import SwiftUI
import ThemeKit

/// How ``FlightRoute`` draws the segment between the two time columns.
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
    @Environment(\.theme) private var theme
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
    private var track: FlightRouteTrack = .path
    private var size: FlightRouteSize = .regular
    private var originCity: String?
    private var destinationCity: String?
    private var durationOverride: String?
    private var stopsTone: SemanticColor?

    public init(from origin: String, to destination: String, departure: Date, arrival: Date) {   // R1
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    public var body: some View {
        HStack(spacing: density.scale(track == .inline ? Theme.SpacingKey.lg.value : Theme.SpacingKey.sm.value)) {
            timeColumn(departure, code: origin, city: originCity,
                       alignment: track == .inline ? .trailing : .leading, marker: nil)
            switch track {
            case .path: path
            case .inline: inlineTrack
            case .arc: arcTrack
            case .dots: dotsTrack
            }
            timeColumn(arrival, code: destination, city: destinationCity,
                       alignment: track == .inline ? .leading : .trailing, marker: nextDay ? "+1" : nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    // MARK: Size ramp — steps the three text roles together, per track family.

    private var timeStyle: TextStyle {
        switch (track, size) {
        case (.inline, .compact): .labelBase600
        case (.inline, .regular): .labelMd600
        case (.inline, .large): .labelLg600
        case (_, .compact): .labelSm700
        case (_, .regular): .labelBase700
        case (_, .large): .labelMd700
        }
    }
    private var codeStyle: TextStyle {
        switch (track, size) {
        case (.inline, .compact): .overline500
        case (.inline, .regular): .bodySm400
        case (.inline, .large): .bodyBase400
        case (_, .compact): .overline400
        case (_, .regular): .overline500
        case (_, .large): .labelSm600
        }
    }
    private var durationStyle: TextStyle {
        switch (track, size) {
        case (.inline, .compact): .overline400
        case (.inline, .regular): .bodySm400
        case (.inline, .large): .bodyBase400
        case (_, .compact): .overline400
        case (_, .regular): .overline400
        case (_, .large): .bodySm400
        }
    }

    /// Stops label colour: direct keeps the path accent, 1+ stops uses the
    /// ``stopsTone(_:)`` (default tertiary).
    private var stopsLabelColor: Color {
        stops == 0 ? theme.foreground(accentKey) : (stopsTone?.base ?? theme.text(.textTertiary))
    }

    private var accessibilitySummary: String {
        let departs = departure.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        let arrives = arrival.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return String(themeKit: "\(origin) \(departs) to \(destination) \(arrives), \(durationText), \(stopsAccessibility)")
    }

    private func timeColumn(_ date: Date, code: String, city: String?, alignment: HorizontalAlignment, marker: String?) -> some View {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return VStack(alignment: alignment, spacing: track == .inline ? 0 : 2) {
            HStack(alignment: .top, spacing: 2) {
                Text(time)
                    .textStyle(timeStyle)
                    .foregroundStyle(theme.text(.textPrimary))
                if let marker { Text(marker).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary)) }
            }
            Text(code)
                .textStyle(codeStyle)
                .foregroundStyle(theme.text(.textSecondary))
            if let city {
                Text(city).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1)
            }
        }
        .fixedSize()
    }

    /// Design-system track: hairlines flanking the duration, stops beneath.
    private var inlineTrack: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
                Text(durationText).textStyle(durationStyle).foregroundStyle(theme.text(.textPrimary)).fixedSize()
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
            }
            Text(stopsText).textStyle(durationStyle)
                .foregroundStyle(stops > 0 ? (stopsTone?.base ?? theme.text(.textTertiary)) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private var lineColor: Color { stops == 0 ? theme.foreground(accentKey) : theme.border(.borderPrimary) }

    private var path: some View {
        VStack(spacing: 3) {
            Text(durationText).textStyle(durationStyle).foregroundStyle(theme.text(.textSecondary))
            ZStack {
                Capsule().fill(lineColor).frame(height: 2)
                if stops > 0 {
                    HStack(spacing: 10) {
                        ForEach(0..<min(stops, 3), id: \.self) { _ in stopDot }
                    }
                }
            }
            .frame(width: 46)
            Text(stopsText).textStyle(durationStyle)
                .foregroundStyle(stopsLabelColor)
        }
        .frame(maxWidth: .infinity)
    }

    /// Dashed arc with a plane glyph at the apex. The `Path` is absolute
    /// geometry, so it's flipped explicitly for RTL and the plane glyph mirrors.
    private var arcTrack: some View {
        VStack(spacing: 3) {
            Text(durationText).textStyle(durationStyle).foregroundStyle(theme.text(.textSecondary))
            ZStack(alignment: .top) {
                ArcLine()
                    .stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    .flipsForRightToLeftLayoutDirection(true)
                Image(systemName: "airplane")
                    .textStyle(codeStyle)
                    .foregroundStyle(theme.foreground(accentKey))
                    .mirrorsInRTL()
                    .offset(y: -2)
            }
            .frame(width: 56, height: 14)
            Text(stopsText).textStyle(durationStyle)
                .foregroundStyle(stopsLabelColor)
        }
        .frame(maxWidth: .infinity)
    }

    /// Endpoint dots on a hairline, hollow mid-line dots per stop.
    private var dotsTrack: some View {
        VStack(spacing: 3) {
            Text(durationText).textStyle(durationStyle).foregroundStyle(theme.text(.textSecondary))
            ZStack {
                Capsule().fill(theme.border(.borderPrimary)).frame(height: 2)
                HStack(spacing: 0) {
                    endpointDot
                    Spacer(minLength: 0)
                    if stops > 0 {
                        HStack(spacing: 8) {
                            ForEach(0..<min(stops, 3), id: \.self) { _ in stopDot }
                        }
                        Spacer(minLength: 0)
                    }
                    endpointDot
                }
            }
            .frame(width: 56)
            Text(stopsText).textStyle(durationStyle)
                .foregroundStyle(stopsLabelColor)
        }
        .frame(maxWidth: .infinity)
    }

    private var endpointDot: some View {
        Circle().fill(theme.foreground(accentKey)).frame(width: 6, height: 6)
    }
    private var stopDot: some View {
        Circle().fill(theme.background(.bgBase)).frame(width: 6, height: 6)
            .overlay(Circle().stroke(theme.text(.textTertiary), lineWidth: 1.5))
    }

    /// A shallow quad-curve arc from the leading to the trailing edge, apex at the top.
    private struct ArcLine: Shape {
        func path(in rect: CGRect) -> Path {
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.maxY),
                               control: CGPoint(x: rect.midX, y: rect.minY - rect.height))
            }
        }
    }

    private var durationText: String {
        if let durationOverride { return durationOverride }
        let minutes = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? String(themeKit: "\(h)h \(m)m") : String(themeKit: "\(m)m")
    }
    // Resolved via String(themeKit:) so the lookup hits ThemeKit's own catalog
    // (a bare LocalizedStringKey would resolve against the consumer's main bundle).
    private var stopsText: String {
        switch stops {
        case 0: return String(themeKit: "Direct")
        case 1: return String(themeKit: "1 stop")
        default: return String(themeKit: "\(stops) stops")
        }
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
    /// Track presentation — the stock `.path` capsule, the design-system
    /// `.inline` hairline layout, a dashed `.arc` with a plane glyph, or
    /// endpoint-`.dots` on a hairline (see ``FlightRouteTrack``).
    func track(_ t: FlightRouteTrack) -> Self { copy { $0.track = t } }
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

#Preview {
    let dep = Date()
    PreviewMatrix("FlightRoute") {
        PreviewCase("Direct") {
            FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
        }
        PreviewCase("1 stop · next day") {
            FlightRoute(from: "AYT", to: "IST", departure: dep, arrival: dep.addingTimeInterval(230 * 60)).stops(1).nextDay()
        }
        PreviewCase("Inline track") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60)).stops(1).track(.inline)
        }
        PreviewCase("Arc track + city names") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .track(.arc)
                .cityNames("Istanbul", "New York")
        }
        PreviewCase("Dots track · 2 stops · warning tone") {
            FlightRoute(from: "IST", to: "SYD", departure: dep, arrival: dep.addingTimeInterval(1_300 * 60))
                .track(.dots)
                .stops(2)
                .stopsTone(.warning)
        }
        PreviewCase("Compact / regular / large") {
            VStack(spacing: 16) {
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60)).size(.compact)
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
                FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60)).size(.large)
            }
        }
        PreviewCase("Duration override") {
            FlightRoute(from: "IST", to: "FRA", departure: dep, arrival: dep.addingTimeInterval(200 * 60))
                .durationText("3h+")
        }
        PreviewCase("Arc · RTL") {
            FlightRoute(from: "IST", to: "JFK", departure: dep, arrival: dep.addingTimeInterval(690 * 60))
                .track(.arc)
                .environment(\.layoutDirection, .rightToLeft)
        }
    }
}
