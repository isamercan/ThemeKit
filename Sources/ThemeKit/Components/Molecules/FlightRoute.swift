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

/// How ``FlightRoute`` draws the segment between the two time columns.
public enum FlightRouteTrack {
    /// The stock look: duration over a short colored capsule, stops below.
    case path
    /// Design-system spec: full-width hairlines flanking the duration, the
    /// stops label centered beneath in tertiary — no capsule, no accent.
    case inline
}

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

    public init(from origin: String, to destination: String, departure: Date, arrival: Date) {   // R1
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    public var body: some View {
        HStack(spacing: density.scale(track == .inline ? Theme.SpacingKey.lg.value : Theme.SpacingKey.sm.value)) {
            timeColumn(departure, code: origin, alignment: track == .inline ? .trailing : .leading, marker: nil)
            switch track {
            case .path: path
            case .inline: inlineTrack
            }
            timeColumn(arrival, code: destination, alignment: track == .inline ? .leading : .trailing, marker: nextDay ? "+1" : nil)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilitySummary)
    }

    private var accessibilitySummary: String {
        let departs = departure.formatted(date: .omitted, time: .shortened)
        let arrives = arrival.formatted(date: .omitted, time: .shortened)
        return "\(origin) \(departs) to \(destination) \(arrives), \(durationText), \(stopsAccessibility)"
    }

    private func timeColumn(_ date: Date, code: String, alignment: HorizontalAlignment, marker: String?) -> some View {
        let time = date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale))
        return VStack(alignment: alignment, spacing: track == .inline ? 0 : 2) {
            HStack(alignment: .top, spacing: 2) {
                Text(time)
                    .textStyle(track == .inline ? .labelMd600 : .labelBase700)
                    .foregroundStyle(theme.text(.textPrimary))
                if let marker { Text(marker).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary)) }
            }
            Text(code)
                .textStyle(track == .inline ? .bodySm400 : .overline500)
                .foregroundStyle(theme.text(.textSecondary))
        }
        .fixedSize()
    }

    /// Design-system track: hairlines flanking the duration, stops beneath.
    private var inlineTrack: some View {
        VStack(spacing: 0) {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
                Text(durationText).textStyle(.bodySm400).foregroundStyle(theme.text(.textPrimary)).fixedSize()
                Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
            }
            Text(stopsText).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private var lineColor: Color { stops == 0 ? theme.foreground(accentKey) : theme.border(.borderPrimary) }

    private var path: some View {
        VStack(spacing: 3) {
            Text(durationText).textStyle(.overline400).foregroundStyle(theme.text(.textSecondary))
            ZStack {
                Capsule().fill(lineColor).frame(height: 2)
                if stops > 0 {
                    HStack(spacing: 10) {
                        ForEach(0..<min(stops, 3), id: \.self) { _ in
                            Circle().fill(theme.background(.bgBase)).frame(width: 6, height: 6)
                                .overlay(Circle().stroke(theme.text(.textTertiary), lineWidth: 1.5))
                        }
                    }
                }
            }
            .frame(width: 46)
            Text(stopsText).textStyle(.overline400)
                .foregroundStyle(stops == 0 ? theme.foreground(accentKey) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private var durationText: String {
        let minutes = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    private var stopsText: LocalizedStringKey {
        switch stops { case 0: return "Direct"; case 1: return "1 stop"; default: return "\(stops) stops" }
    }
    private var stopsAccessibility: String {
        switch stops { case 0: return "direct"; case 1: return "1 stop"; default: return "\(stops) stops" }
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
    /// Track presentation — the stock `.path` capsule or the design-system
    /// `.inline` hairline layout (see ``FlightRouteTrack``).
    func track(_ t: FlightRouteTrack) -> Self { copy { $0.track = t } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let dep = Date()
    return VStack(spacing: 16) {
        FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
        FlightRoute(from: "AYT", to: "IST", departure: dep, arrival: dep.addingTimeInterval(230 * 60)).stops(1).nextDay()
    }
    .padding()
}
