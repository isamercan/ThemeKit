//
//  FlightCard.swift
//  ThemeKit
//
//  A flight result / itinerary segment — airline, departure→arrival times + airport
//  codes, a flight-path line with duration and a stops label, and an optional price +
//  select action. Token-bound; the surface, accent and price all come from the theme.
//

import SwiftUI

/// A token-bound flight segment card.
///
/// ```swift
/// FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB",
///            departure: dep, arrival: arr)
///     .stops(1).price(1_299).badge("Cheapest") { book() }
/// ```
public struct FlightCard: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let airline: String
    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    private var stops: Int = 0
    private var price: Decimal?
    private var currencyCode: String = "TRY"
    private var airlineSystemImage: String = "airplane.circle.fill"
    private var badge: String?
    private var onSelect: (() -> Void)?

    public init(airline: String, from origin: String, to destination: String, departure: Date, arrival: Date) {
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            header
            route
            if price != nil || onSelect != nil { footer }
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgElevatorPrimary), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    private var header: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Image(systemName: airlineSystemImage)
                .font(.system(size: 20))
                .foregroundStyle(theme.foreground(.fgHero))
            Text(airline).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            Spacer()
            if let badge { Badge(badge).badgeStyle(.success).size(.small) }
        }
    }

    private var route: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            timeColumn(departure, code: origin, alignment: .leading)
            pathView
            timeColumn(arrival, code: destination, alignment: .trailing)
        }
    }

    private func timeColumn(_ date: Date, code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            Text(date.formatted(date: .omitted, time: .shortened))
                .textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
            Text(code)
                .textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
        }
    }

    private var pathView: some View {
        VStack(spacing: 4) {
            Text(durationText).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            HStack(spacing: 4) {
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
                line
                Image(systemName: "airplane").font(.system(size: 12)).foregroundStyle(theme.foreground(.fgHero))
                line
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
            }
            Text(stopsText)
                .textStyle(.overline400)
                .foregroundStyle(stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private var line: some View {
        Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
    }

    private var footer: some View {
        HStack {
            if let price { PriceTag(price, currencyCode: currencyCode).size(.large).emphasis(.hero) }
            Spacer()
            if let onSelect { PrimaryButton("Select") { onSelect() }.size(.small) }
        }
    }

    private var durationText: String {
        let minutes = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var stopsText: String {
        switch stops {
        case 0: return "Nonstop"
        case 1: return "1 stop"
        default: return "\(stops) stops"
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightCard {
    /// Number of stops (0 = nonstop, shown in green).
    func stops(_ count: Int) -> Self { copy { $0.stops = max(0, count) } }
    /// The fare, rendered as a hero `PriceTag` in the footer.
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// A leading airline SF Symbol (default `airplane.circle.fill`).
    func airlineIcon(_ systemName: String) -> Self { copy { $0.airlineSystemImage = systemName } }
    /// A success badge in the header, e.g. `"Cheapest"`.
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// Adds a "Select" button to the footer.
    func onSelect(_ action: (() -> Void)?) -> Self { copy { $0.onSelect = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let dep = Date()
    let arr = dep.addingTimeInterval(2 * 3_600 + 20 * 60)
    return VStack(spacing: 16) {
        FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr)
            .price(1_299).badge("Cheapest").onSelect { }
        FlightCard(airline: "Blue Wings", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))
            .stops(1).price(3_499)
    }
    .padding()
}
