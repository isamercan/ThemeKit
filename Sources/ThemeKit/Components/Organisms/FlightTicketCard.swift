//
//  FlightTicketCard.swift
//  ThemeKit
//
//  Organism. A boarding-pass / ticket-style flight card — a route header
//  (from/to codes + cities + a centered duration), a dashed departure→arrival
//  timeline with a plane, a perforated tear (reusing ``TicketStub``) and a stub
//  with the airline, price and a favourite. Token-bound; every part is a modifier.
//
//  ```swift
//  FlightTicketCard(from: "NYC", to: "SFO")
//      .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
//      .times(departure: "10:00 AM", arrival: "11:30 AM")
//      .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite($fav)
//  ```
//

import SwiftUI

public struct FlightTicketCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let from: String
    private let to: String
    // Content/appearance — mutated only through the modifiers below (R2).
    private var fromCity: String?
    private var toCity: String?
    private var departure: String?
    private var arrival: String?
    private var duration: String?
    private var stops = 0
    private var airline: String?
    private var airlineIcon = "airplane"
    private var airlineLogo: URL?
    private var price: Decimal?
    private var currencyCode = "TRY"
    private var favorite: Binding<Bool>?
    private var accent: SemanticColor?
    private var elevation: CardElevation = .soft
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase

    public init(from: String, to: String) {   // R1
        self.from = from
        self.to = to
    }

    private var accentBase: Color { (accent ?? .primary).base }

    public var body: some View {
        TicketStub {
            routeHeader
        }
        .stub { stub }
        .elevation(elevation)
        .surface(surfaceKey)
    }

    private var routeHeader: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(from).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    if let fromCity { Text(fromCity).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
                }
                Spacer(minLength: 8)
                if let duration { Text(duration).textStyle(.labelSm700).foregroundStyle(accentBase) }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 1) {
                    Text(to).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                    if let toCity { Text(toCity).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
                }
            }
            timeline
        }
    }

    private var timeline: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let departure { Text(departure).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).fixedSize() }
            ZStack {
                DashedLine().stroke(theme.border(.borderPrimary), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4])).frame(height: 1)
                HStack {
                    dot; Spacer(); dot
                }
                Image(systemName: stops == 0 ? "airplane" : "airplane.circle.fill")
                    .font(.system(size: 14)).foregroundStyle(accentBase)
                    .padding(.horizontal, 4).background(theme.background(surfaceKey))
                    .mirrorsInRTL()
            }
            .frame(maxWidth: .infinity)
            .frame(height: 18)
            if let arrival { Text(arrival).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).fixedSize() }
        }
    }

    private var dot: some View {
        Circle().fill(accentBase).frame(width: 7, height: 7)
            .overlay(Circle().fill(theme.background(surfaceKey)).frame(width: 3, height: 3))
    }

    private var stub: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let airlineLogo {
                RemoteImage(airlineLogo).contentMode(.fit).frame(width: 22, height: 22)
            } else {
                Image(systemName: airlineIcon).font(.system(size: 15)).foregroundStyle(theme.text(.textSecondary))
            }
            if let airline { Text(airline).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary)).lineLimit(1) }
            Spacer(minLength: 6)
            if let price { PriceTag(price, currencyCode: currencyCode).size(.medium).emphasis(.standard).fractionDigits(0) }
            if let favorite {
                Button { favorite.wrappedValue.toggle() } label: {
                    Image(systemName: favorite.wrappedValue ? "heart.fill" : "heart")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle((accent ?? .primary).onSolid)
                        .frame(width: 30, height: 30)
                        .background(favorite.wrappedValue ? accentBase : theme.text(.textTertiary), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Favourite")
            }
        }
    }
}

private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: 0, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.width, y: rect.midY))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightTicketCard {
    func cities(from: String?, to: String?) -> Self { copy { $0.fromCity = from; $0.toCity = to } }
    func times(departure: String?, arrival: String?) -> Self { copy { $0.departure = departure; $0.arrival = arrival } }
    func duration(_ text: String?) -> Self { copy { $0.duration = text } }
    func stops(_ count: Int) -> Self { copy { $0.stops = max(0, count) } }
    func airline(_ name: String?, icon: String = "airplane") -> Self { copy { $0.airline = name; $0.airlineIcon = icon } }
    func airlineLogo(_ url: URL?) -> Self { copy { $0.airlineLogo = url } }
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    func favorite(_ binding: Binding<Bool>) -> Self { copy { $0.favorite = binding } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var fav = true
        var body: some View {
            FlightTicketCard(from: "NYC", to: "SFO")
                .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
                .times(departure: "10:00 AM", arrival: "11:30 AM")
                .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite($fav).accent(.info)
                .frame(maxWidth: 320).padding()
        }
    }
    return Demo()
}
