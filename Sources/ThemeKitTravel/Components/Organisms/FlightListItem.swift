//
//  FlightListItem.swift
//  ThemeKit
//
//  Organism. A flight search-result LIST ITEM whose entire layout is a
//  swappable ``FlightListItemStyle`` — the component owns the *data* (legs,
//  fares, price, deal signals, schedule) and the style owns the *presentation*.
//  Twelve built-in styles cover the industry's list-item archetypes (see
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
import ThemeKit

public struct FlightListItem: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.locale) private var locale
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.flightListItemStyle) private var style
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.componentDensity) private var density

    // Required content (R1).
    private let legs: [FlightLeg]
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var sliceLabels: [String] = []
    private var flightNo: String?
    private var cabin: String?
    private var airlineSystemImage = "airplane.circle.fill"
    private var logo: AnyView?
    private var priceAmount: Decimal?
    private var originalAmount: Decimal?
    private var currencyCode: String?
    private var priceCaption: String?
    private var fares: [FlightFare] = []
    private var departures: [Date] = []
    private var scheduleNote: String?
    private var dealText: String?
    private var dealTone: SemanticColor = .success
    private var trend: [Double] = []
    private var badge: String?
    private var amenities: [String] = []
    private var baggage: String?
    private var checkedBaggage: String?
    private var isSelected = false
    private var selectTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var selectTitle: String { selectTitleOverride ?? String(themeKit: "Select") }
    private var onSelect: (() -> Void)?
    private var detailsTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var detailsTitle: String { detailsTitleOverride ?? String(themeKit: "Details") }
    private var onDetails: (() -> Void)?
    /// Expansion state for `.journey`-class styles — uncontrolled by default;
    /// `.expanded(_:)` swaps in the caller's binding (ADR-F4 via
    /// `ControllableState`, mirroring the Accordion refactor).
    @ControllableState private var expandedState = false
    /// Favourite state — hidden until `.favorite()` / `.favorite(_:)` request
    /// the heart (the backing var is deliberately NOT named `favorite`: a
    /// stored `favorite` + a nullary `func favorite()` would be an invalid
    /// redeclaration).
    @ControllableState private var favoriteState = false
    private var showsFavorite = false
    private var accent: SemanticColor?
    private var radiusRole: Theme.RadiusRole?
    private var metaItems: [(icon: String, text: String)] = []
    private var accessory: AnyView?
    private var footer: AnyView?
    /// Fare-chip selection for `.fareBoard`-class styles — uncontrolled by
    /// default; `.selectedFare(_:)` swaps in the caller's binding.
    @ControllableState private var fareState: String?
    /// Departure-chip selection for `.timetable` — same controlled/uncontrolled
    /// split via `.selectedDeparture(_:)`.
    @ControllableState private var departureState: Date?

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

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        let heartMotion = MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)
        // Expansion springs the MicroMotion-gated way: `.base` duration as a
        // spring, `nil` (instant, no motion) when micro-animations are off or
        // Reduce Motion is on.
        let expandMotion: Animation? = (micro && !reduceMotion) ? Motion.base.spring : nil
        let configuration = FlightListItemConfiguration(
            legs: legs, sliceLabels: sliceLabels, flightNo: flightNo, cabin: cabin,
            airlineSystemImage: airlineSystemImage, logo: logo,
            priceAmount: priceAmount, originalAmount: originalAmount,
            currencyCode: resolvedCurrency, priceCaption: priceCaption,
            fares: fares, departures: departures, scheduleNote: scheduleNote,
            dealText: dealText, dealTone: dealTone, trend: trend,
            badge: badge, amenities: amenities,
            baggage: baggage, checkedBaggage: checkedBaggage,
            isExpanded: expandedState, isSelected: isSelected, isEnabled: isEnabled,
            selectTitle: selectTitle, onSelect: onSelect,
            detailsTitle: detailsTitle, onDetails: onDetails,
            surfaceKey: surfaceKey,
            locale: locale,
            toggleExpand: {
                withAnimation(expandMotion) { expandedState.toggle() }
            },
            isFavorite: showsFavorite ? favoriteState : nil,
            toggleFavorite: showsFavorite
                ? { withAnimation(heartMotion) { favoriteState.toggle() } }
                : nil,
            accent: accent, radiusRole: radiusRole, density: density,
            metaItems: metaItems, accessory: accessory, footer: footer,
            selectedFareID: fareState,
            onFareSelect: { fareState = $0 },
            selectedDeparture: departureState,
            onDepartureSelect: { departureState = $0 }
        )
        style.makeBody(configuration: configuration)
            .opacity(isEnabled ? 1 : 0.5)
    }
}

// MARK: - Modifiers (R2 — copy-on-write)

public extension FlightListItem {
    /// Surface fill the style draws behind the item. When unset, each style
    /// picks its own natural default (cards use base-100; `.tray` uses the
    /// tinted card-surface).
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
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    /// Replicates every parameter except `currencyCode` so
    /// `price(214, caption: "from")` binds here, not the hardcoded default.
    func price(_ amount: Decimal?, caption: String? = nil) -> Self {
        copy { $0.priceAmount = amount; $0.priceCaption = caption }
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
    /// Baggage allowances shown in meta rows — carry-on ("8kg") and checked bag.
    func baggage(_ carryOn: String?, checked: String? = nil) -> Self {
        copy { $0.baggage = carryOn; $0.checkedBaggage = checked }
    }
    /// Secondary "open details" action; styles with a details affordance show it.
    func onDetails(_ title: String = String(themeKit: "Details"), perform action: @escaping () -> Void) -> Self {
        copy { $0.detailsTitleOverride = title; $0.onDetails = action }
    }
    /// Marks the item as the current selection (styles accent it).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Primary action; expandable styles pin it in the expanded footer.
    func onSelect(_ title: String = String(themeKit: "Select"), perform action: @escaping () -> Void) -> Self {
        copy { $0.selectTitleOverride = title; $0.onSelect = action }
    }
    /// Drives expandable styles (`.journey`) from outside — e.g. an accordion
    /// list where only one item is open. Without it the item self-manages.
    func expanded(_ binding: Binding<Bool>) -> Self {
        copy { $0._expandedState = ControllableState(wrappedValue: false, external: binding) }
    }
    /// Self-managed favourite heart (uncontrolled): every built-in style renders
    /// the heart in its identity/price corner and the item owns the flag.
    /// Per-identity `@State` means the heart survives List *scrolling*, but not
    /// identity churn (a row re-created under a new identity — e.g. re-fetched
    /// results — resets to unfavourited). Use ``favorite(_:)`` when the flag
    /// must persist.
    func favorite() -> Self { copy { $0.showsFavorite = true } }
    /// Controlled favourite heart — the caller owns persistence.
    func favorite(_ isFavorite: Binding<Bool>) -> Self {
        copy {
            $0.showsFavorite = true
            $0._favoriteState = ControllableState(wrappedValue: false, external: isFavorite)
        }
    }
    /// Selection accent — tints the selected border, fare/time chips and other
    /// emphasis colours the styles otherwise take from the theme's hero tokens.
    /// Pass `nil` to restore the hero default.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Corner-radius role of the card shell (default `.box`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Generic icon + text meta pairs, e.g. `[("wifi", "Wi-Fi"), ("suitcase", "8kg")]` —
    /// styles with a meta row render them in order.
    func meta(_ items: [(icon: String, text: String)]) -> Self { copy { $0.metaItems = items } }
    /// Trailing accessory in the identity row (a co-brand badge, an emissions
    /// chip…). Styles that place identity honour it; others ignore it.
    func accessory<A: View>(@ViewBuilder _ content: () -> A) -> Self {
        copy { $0.accessory = AnyView(content()) }
    }
    /// Footer slot below the style's content — fine print, a promo line, links.
    func footer<F: View>(@ViewBuilder _ content: () -> F) -> Self {
        copy { $0.footer = AnyView(content()) }
    }
    /// Drives fare-chip selection (`.fareBoard`) from outside — e.g. persisting
    /// the chosen fare family. Without it the item self-manages (ADR-F4 via
    /// `ControllableState`, like ``expanded(_:)``).
    func selectedFare(_ binding: Binding<String?>) -> Self {
        copy { $0._fareState = ControllableState(wrappedValue: nil, external: binding) }
    }
    /// Drives departure-chip selection (`.timetable`) from outside — mirrors
    /// ``selectedFare(_:)``.
    func selectedDeparture(_ binding: Binding<Date?>) -> Self {
        copy { $0._departureState = ControllableState(wrappedValue: nil, external: binding) }
    }

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
            // Uncontrolled heart (off until tapped) — the item owns the flag.
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .flightNo("SK 1123").price(214, currencyCode: "USD", caption: "from").badge("Best")
                .favorite()
                .onSelect { }
            // Controlled heart, shown favourited.
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .price(189, currencyCode: "USD")
                .favorite(.constant(true))
                .flightListItemStyle(.compact)
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .price(164, currencyCode: "USD").original(214)
                .deal("23% below typical", tone: .success)
                .trend([0.8, 0.75, 0.9, 0.6, 0.5, 0.42])
                .flightListItemStyle(.deal)

            // NEW archetypes + full-flex axes -----------------------------

            // Hero: deal strip, amenities, xl price — with a purple accent,
            // selector radius, meta row, accessory + footer slots.
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .flightNo("SK 1123").cabin("Economy")
                .price(164, currencyCode: "USD", caption: "from").original(214)
                .deal("Today's best deal", tone: .warning)
                .badge("Featured")
                .amenities(["wifi", "powerplug", "cup.and.saucer"])
                .meta([(icon: "suitcase.rolling", text: "8kg"), (icon: "leaf", text: "-12% CO₂")])
                .accent(.purple)
                .radius(.field)
                .selected()
                .accessory { Badge("Partner").badgeStyle(.neutral).size(.small) }
                .footer {
                    Text("Free cancellation within 24h")
                        .textStyle(.overline400)
                        .foregroundStyle(Theme.shared.text(.textTertiary))
                }
                .onSelect { }
                .flightListItemStyle(.hero)

            // Tile: vertical carousel cards.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(0..<3, id: \.self) { i in
                        FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR",
                                       departure: dep.addingTimeInterval(Double(i) * 86_400), arrival: arr)
                            .price(Decimal(189 + i * 12), currencyCode: "USD", caption: "from")
                            .badge(i == 0 ? "Best" : nil)
                            .onSelect { }
                            .flightListItemStyle(.tile)
                            .frame(width: 190)
                    }
                }
            }

            // Receipt: checkout read-back — labeled fields, no tap affordance.
            FlightListItem(legs: [
                FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr),
                FlightLeg(airline: "Skyline Air", from: "LHR", to: "IST",
                          departure: dep.addingTimeInterval(7 * 86_400),
                          arrival: arr.addingTimeInterval(7 * 86_400))
            ])
                .sliceLabels(["Outbound", "Return"])
                .flightNo("SK 1123").cabin("Economy Flex")
                .baggage("8kg", checked: "23kg")
                .price(438, currencyCode: "USD", caption: "Total · 2 travellers")
                .flightListItemStyle(.receipt)

            // Controlled fare selection through the caller's binding.
            FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
                .fares([FlightFare("Light", price: 164), FlightFare("Standard", price: 214),
                        FlightFare("Flex", price: 289)])
                .selectedFare(.constant("Standard"))
                .accent(.accent)
                .flightListItemStyle(.fareBoard)
        }
        .padding()
    }
    .background(Theme.shared.background(.bgElevatorPrimary))
}

#Preview("FlightListItem dark + density", traits: .sizeThatFitsLayout) {
    let dep = Date(timeIntervalSince1970: 1_781_000_000)
    let arr = dep.addingTimeInterval(3.5 * 3600)
    VStack(spacing: 16) {
        FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
            .price(214, currencyCode: "USD").badge("Best")
            .meta([(icon: "suitcase.rolling", text: "8kg")])
            .accent(.success).selected()
            .componentDensity(.compact)
        FlightListItem(airline: "Skyline Air", from: "IST", to: "LHR", departure: dep, arrival: arr)
            .price(214, currencyCode: "USD")
            .flightListItemStyle(TimelineFlightListItemStyle(showsRouteTrack: false))
    }
    .padding()
    .background(Theme.shared.background(.bgElevatorPrimary))
    .environment(\.colorScheme, .dark)
}
