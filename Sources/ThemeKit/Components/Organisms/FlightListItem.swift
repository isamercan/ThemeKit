//
//  FlightListItem.swift
//  ThemeKit
//
//  Organism. A flight search-result LIST ITEM whose entire layout is a
//  swappable ``FlightListItemStyle`` — the component owns the *data* (legs,
//  fares, price, deal signals, schedule) and the style owns the *presentation*.
//  Eight built-in styles cover the industry's list-item archetypes (see
//  FlightListItemStyle.swift); custom styles get the same typed configuration.
//
//      FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR",
//                     departure: dep, arrival: arr)
//          .price(214, currencyCode: "USD").badge("Best")
//          .onSelect { }
//          .flightListItemStyle(.timeline)      // .compact / .deal / .ticket / …
//
//  Unlike ``FlightResultRow`` (a fixed row layout), this component is a data
//  container: every visual decision is delegated to the active style, so one
//  result list can mix archetypes the way Skyscanner mixes plain rows with
//  timetable widgets. Token-bound; reuses FlightLeg, PriceTag, Badge, Icon.
//

import SwiftUI

/// One purchasable fare option on a flight (fare-family shopping — Delta/THY
/// style "Basic / Classic / Flex" columns). Rendered by ``FlightListItemStyle``s
/// that surface multiple prices per flight (e.g. `.fareBoard`).
public struct FlightFare: Identifiable, Sendable, Equatable {
    /// Stable, content-derived identity (no per-init `UUID()` churn in `ForEach`).
    public var id: String { name }
    public let name: String
    public let price: Decimal
    /// SF Symbol names for 1–2 headline perks (e.g. `"suitcase.fill"`).
    public var perks: [String]

    public init(_ name: String, price: Decimal, perks: [String] = []) {
        self.name = name
        self.price = price
        self.perks = perks
    }
}

public struct FlightListItem: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale
    @Environment(\.flightListItemStyle) private var style

    // Required content (R1).
    private let legs: [FlightLeg]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var sliceLabels: [String] = []
    private var flightNo: String?
    private var cabin: String?
    private var airlineSystemImage = "airplane.circle.fill"
    private var logo: AnyView?
    private var priceAmount: Decimal?
    private var originalAmount: Decimal?
    private var currencyCode = "USD"
    private var priceCaption: String?
    private var fares: [FlightFare] = []
    private var departures: [Date] = []
    private var scheduleNote: String?
    private var dealText: String?
    private var dealTone: SemanticColor = .success
    private var trend: [Double] = []
    private var badge: String?
    private var amenities: [String] = []
    private var isSelected = false
    private var selectTitle = "Select"
    private var onSelect: (() -> Void)?
    private var expandedBinding: Binding<Bool>?
    @State private var internalExpanded = false

    /// A multi-leg itinerary (round trip / multi-city). One entry per slice.
    public init(legs: [FlightLeg]) {   // R1 — content
        self.legs = legs
    }

    /// A single one-way flight.
    public init(airline: String, from origin: String, to destination: String,
                departure: Date, arrival: Date) {
        self.legs = [FlightLeg(airline: airline, from: origin, to: destination,
                               departure: departure, arrival: arrival)]
    }

    public var body: some View {
        let expanded = expandedBinding?.wrappedValue ?? internalExpanded
        let configuration = FlightListItemConfiguration(
            legs: legs, sliceLabels: sliceLabels, flightNo: flightNo, cabin: cabin,
            airlineSystemImage: airlineSystemImage, logo: logo,
            priceAmount: priceAmount, originalAmount: originalAmount,
            currencyCode: currencyCode, priceCaption: priceCaption,
            fares: fares, departures: departures, scheduleNote: scheduleNote,
            dealText: dealText, dealTone: dealTone, trend: trend,
            badge: badge, amenities: amenities,
            isExpanded: expanded, isSelected: isSelected, isEnabled: isEnabled,
            selectTitle: selectTitle, onSelect: onSelect,
            surfaceKey: surfaceKey,
            locale: locale,
            toggleExpand: {
                withAnimation(.spring(duration: 0.35)) {
                    if let binding = expandedBinding { binding.wrappedValue.toggle() } else { internalExpanded.toggle() }
                }
            }
        )
        style.makeBody(configuration: configuration)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Modifiers (R2 — copy-on-write)

public extension FlightListItem {
    /// Surface fill the style draws behind the item (defaults to base-100).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Per-slice captions for multi-leg styles, e.g. `["Outbound · Fri, Aug 14", "Return · Sun, Aug 23"]`.
    func sliceLabels(_ labels: [String]) -> Self { copy { $0.sliceLabels = labels } }
    func flightNo(_ number: String?) -> Self { copy { $0.flightNo = number } }
    func cabin(_ name: String?) -> Self { copy { $0.cabin = name } }
    /// SF Symbol used when no custom logo slot is provided.
    func airlineIcon(_ systemImage: String) -> Self { copy { $0.airlineSystemImage = systemImage } }
    /// Custom airline logo slot (e.g. a `RemoteImage`), shown where the style places identity.
    func logo<L: View>(@ViewBuilder _ content: () -> L) -> Self { copy { $0.logo = AnyView(content()) } }
    /// The headline price. `caption` qualifies it ("from", "total · round trip").
    func price(_ amount: Decimal?, currencyCode: String = "USD", caption: String? = nil) -> Self {
        copy { $0.priceAmount = amount; $0.currencyCode = currencyCode; $0.priceCaption = caption }
    }
    /// A compare-at price (typical/undiscounted) — deal-aware styles strike it through.
    func original(_ amount: Decimal?) -> Self { copy { $0.originalAmount = amount } }
    /// Fare-family options (`.fareBoard` renders one chip per fare).
    func fares(_ options: [FlightFare]) -> Self { copy { $0.fares = options } }
    /// Departure times for schedule-grouping styles (`.timetable`), plus an
    /// optional cadence note like "Nonstop · 1h 05m · every ~2h".
    func departures(_ times: [Date], note: String? = nil) -> Self {
        copy { $0.departures = times; $0.scheduleNote = note }
    }
    /// A price-judgment signal ("23% below typical") with its semantic tone.
    /// Deal-aware styles render it as the header strip / price tint.
    func deal(_ text: String?, tone: SemanticColor = .success) -> Self {
        copy { $0.dealText = text; $0.dealTone = tone }
    }
    /// Recent price history (normalized or raw) — styles may draw it as a sparkline.
    func trend(_ points: [Double]) -> Self { copy { $0.trend = points } }
    /// Ranking badge ("Best", "Cheapest").
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// SF Symbols for onboard amenities (Wi-Fi, power, …) — rich styles show them.
    func amenities(_ symbols: [String]) -> Self { copy { $0.amenities = symbols } }
    /// Marks the item as the current selection (styles accent it).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Primary action; expandable styles pin it in the expanded footer.
    func onSelect(_ title: String = "Select", perform action: @escaping () -> Void) -> Self {
        copy { $0.selectTitle = title; $0.onSelect = action }
    }
    /// Drives expandable styles (`.journey`) from outside — e.g. an accordion
    /// list where only one item is open. Without it the item self-manages.
    func expanded(_ binding: Binding<Bool>) -> Self { copy { $0.expandedBinding = binding } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var next = self
        mutate(&next)
        return next
    }
}

#Preview("FlightListItem styles", traits: .sizeThatFitsLayout) {
    let dep = Date(timeIntervalSince1970: 1_781_000_000)
    let arr = dep.addingTimeInterval(3.5 * 3600)
    ScrollView {
        VStack(spacing: 16) {
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .flightNo("SK 1123").price(214, currencyCode: "USD", caption: "from").badge("Best")
                .onSelect { }
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .price(189, currencyCode: "USD")
                .flightListItemStyle(.compact)
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .price(164, currencyCode: "USD").original(214)
                .deal("23% below typical", tone: .success)
                .trend([0.8, 0.75, 0.9, 0.6, 0.5, 0.42])
                .flightListItemStyle(.deal)
        }
        .padding()
    }
    .background(Theme.shared.background(.bgElevatorPrimary))
}
