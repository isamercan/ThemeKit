//
//  FlightResultRow.swift
//  ThemeKit
//
//  Organism. A compact flight search-result row — airline (logo/name/flight no +
//  cabin), departure→arrival times & codes with a duration/stops path, an optional
//  baggage chip, a price and a Select action. The row counterpart to ``FlightCard``.
//  Token-bound; reuses PriceTag, Badge, Icon, ThemeButton.
//
//  The outer shell (surface fill, corner clipping, hairline border) is drawn by the
//  active `CardStyle` from the environment — `.surface()` feeds the
//  `CardStyleConfiguration`, so the default look is unchanged while `.cardStyle(_:)`
//  can swap in a completely different shell. The row is shadowless with an
//  always-on hairline, which is `DefaultCardStyle` at `.none` elevation exactly.
//

import SwiftUI

// Round-trip / multi-leg reuses the shared `FlightLeg` model (see FlightCard.swift).

public struct FlightResultRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle

    // Required content (R1).
    private let airline: String
    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var flightNo: String?
    private var cabinClass: String?
    private var airlineSystemImage = "airplane.circle.fill"
    private var airlineLogoURL: URL?
    private var stops = 0
    private var extraLegs: [FlightLeg] = []
    private var price: Decimal?
    private var currencyCode = "TRY"
    private var baggage: String?
    private var badge: String?
    private var favorite: Binding<Bool>?
    private var bookmark: Binding<Bool>?
    private var totalAmount: Decimal?
    private var totalLabel: String?
    private var urgencyText: String?
    private var selectTitle = "Select"
    private var onSelect: (() -> Void)?
    private var onDetails: (() -> Void)?

    public init(airline: String, from origin: String, to destination: String, departure: Date, arrival: Date) {
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    public var body: some View {
        // The shell (fill, corner clipping, border) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        // `.none` matches today's chrome: no shadow, hairline border.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(rowContent),
            elevation: .none,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: .box))
    }

    /// The row's inner layout — everything inside the shell.
    private var rowContent: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            HStack(alignment: .center, spacing: density.scale(Theme.SpacingKey.sm.value)) {
                airlineBlock.frame(width: 92, alignment: .leading)
                VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                    FlightRoute(from: origin, to: destination, departure: departure, arrival: arrival)
                        .stops(stops).nextDay(crossesMidnight(departure, arrival))
                    ForEach(extraLegs) { leg in
                        FlightRoute(from: leg.origin, to: leg.destination, departure: leg.departure, arrival: leg.arrival)
                            .stops(leg.stops).nextDay(crossesMidnight(leg.departure, leg.arrival))
                    }
                }
                .frame(maxWidth: .infinity)
                priceBlock.frame(minWidth: 84, alignment: .trailing)
            }
            if badge != nil || baggage != nil || urgencyText != nil || onDetails != nil { metaRow }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    private var airlineBlock: some View {
        HStack(spacing: 6) {
            if let url = airlineLogoURL {
                RemoteImage(url).ratio(1).frame(width: 22, height: 22)
            } else {
                Image(systemName: airlineSystemImage).font(.title3).foregroundStyle(theme.foreground(.fgHero))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(airline).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let flightNo { Text(flightNo).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary)) }
                if let cabinClass { Text(cabinClass).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)) }
            }
        }
    }

    private var priceBlock: some View {
        VStack(alignment: .trailing, spacing: 4) {
            if favorite != nil || bookmark != nil {
                HStack(spacing: 6) {
                    if let bookmark {
                        Button { bookmark.wrappedValue.toggle() } label: {
                            Image(systemName: bookmark.wrappedValue ? "bookmark.fill" : "bookmark")
                                .font(.system(size: 14)).foregroundStyle(bookmark.wrappedValue ? theme.foreground(.fgHero) : theme.text(.textTertiary))
                                .frame(width: 40, height: 40).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Save")
                    }
                    if let favorite {
                        Button { favorite.wrappedValue.toggle() } label: {
                            Image(systemName: favorite.wrappedValue ? "heart.fill" : "heart")
                                .foregroundStyle(favorite.wrappedValue ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                                .frame(width: 40, height: 40).contentShape(Rectangle())
                        }.buttonStyle(.plain).accessibilityLabel("Favourite")
                    }
                }
            }
            if let price { PriceTag(price, currencyCode: currencyCode).emphasis(.hero).fractionDigits(2) }
            if let totalLabel, let totalAmount {
                Text("\(totalLabel): \(totalAmount.formatted(.currency(code: currencyCode).precision(.fractionLength(0))))")
                    .textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).fixedSize()
            }
            if let onSelect { ThemeButton(selectTitle) { onSelect() }.size(.small) }
        }
    }

    @ViewBuilder private var metaRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let badge { Badge(badge).badgeStyle(.success).variant(.soft).size(.small) }
            if let baggage {
                HStack(spacing: 3) {
                    Image(systemName: "suitcase.fill").font(.system(size: 11))
                    Text(baggage).textStyle(.overline500)
                }.foregroundStyle(theme.text(.textTertiary))
            }
            if let urgencyText {
                Text(urgencyText).textStyle(.overline500).foregroundStyle(theme.foreground(.systemcolorsFgError))
            }
            Spacer()
            if let onDetails { TextLink("Details") { onDetails() } }
        }
    }

    private func crossesMidnight(_ dep: Date, _ arr: Date) -> Bool {
        !Calendar.current.isDate(dep, inSameDayAs: arr)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightResultRow {
    /// Surface fill (background token key, default `.bgBase`) — feeds the
    /// active `CardStyle`'s configuration.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Flight number, e.g. "TK 2434".
    func flightNo(_ text: String?) -> Self { copy { $0.flightNo = text } }
    /// Cabin class caption, e.g. "Economy".
    func cabin(_ text: String?) -> Self { copy { $0.cabinClass = text } }
    /// Number of stops on the outbound leg (0 = direct, in green).
    func stops(_ count: Int) -> Self { copy { $0.stops = max(0, count) } }
    /// Adds a return leg (round-trip) — stacked under the outbound route.
    func returnLeg(from origin: String, to destination: String, departure: Date, arrival: Date, stops: Int = 0) -> Self {
        copy { $0.extraLegs.append(FlightLeg(airline: $0.airline, from: origin, to: destination, departure: departure, arrival: arrival, stops: stops)) }
    }
    /// Adds an arbitrary extra leg (multi-city) — stacked in order.
    func addLeg(_ leg: FlightLeg) -> Self { copy { $0.extraLegs.append(leg) } }
    /// The fare.
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// A leading airline SF Symbol (default `airplane.circle.fill`).
    func airlineIcon(_ systemName: String) -> Self { copy { $0.airlineSystemImage = systemName } }
    /// A remote airline logo (overrides the SF Symbol).
    func airlineLogo(_ url: URL?) -> Self { copy { $0.airlineLogoURL = url } }
    /// A baggage chip, e.g. "15 kg".
    func baggage(_ text: String?) -> Self { copy { $0.baggage = text } }
    /// A success badge, e.g. "Best".
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// A heart toggle bound to a favourite flag.
    func favorite(_ isFavorite: Binding<Bool>) -> Self { copy { $0.favorite = isFavorite } }
    /// A bookmark (save) toggle bound to a flag.
    func bookmark(_ isSaved: Binding<Bool>) -> Self { copy { $0.bookmark = isSaved } }
    /// A secondary total-price line under the fare, e.g. "3 travellers: 43.068 TL".
    func totalPrice(_ amount: Decimal?, label: String) -> Self { copy { $0.totalAmount = amount; $0.totalLabel = label } }
    /// An urgency note in the meta row, shown in error red (e.g. "5 seats left!").
    func urgency(_ text: String?) -> Self { copy { $0.urgencyText = text } }
    /// Adds a Select button (with an optional custom title).
    func onSelect(_ title: String = "Select", action: @escaping () -> Void) -> Self { copy { $0.selectTitle = title; $0.onSelect = action } }
    /// Adds a "Details" link in the meta row.
    func onDetails(_ action: @escaping () -> Void) -> Self { copy { $0.onDetails = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let dep = Date()
    return VStack(spacing: 12) {
        FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
            .flightNo("TK 2434").cabin("Economy").price(3_538.99).baggage("15 kg").badge("Cheapest")
            .onSelect("Select") { }.onDetails { }
    }
    .padding()
}

#Preview("Outlined card style") {
    let dep = Date()
    return FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(90 * 60))
        .flightNo("TK 2434").cabin("Economy").price(3_538.99).baggage("15 kg")
        .onSelect("Select") { }
        .cardStyle(.outlined)
        .padding()
}
