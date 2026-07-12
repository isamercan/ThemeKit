//
//  FlightTicketCard.swift
//  ThemeKit
//
//  Organism. A boarding-pass / ticket-style flight card — a route header
//  (from/to codes + cities + a centered duration), a dashed departure→arrival
//  timeline with a plane, a tear and a stub with the airline, price and a
//  favourite. Token-bound; every part is a modifier. The entire layout is
//  style-driven (ADR-0004): the component gathers the typed configuration and
//  the active ``FlightTicketCardStyle`` lays it out — `.classic` (default,
//  horizontal ``TicketStub`` tear), `.horizontal` (vertical tear, trailing
//  stub) or `.flat` (tearless dense-list card).
//
//  CardStyle note (per-preset, ADR-0004 §4): on the tear presets
//  (`.classic`/`.horizontal`) the perforated shell — fill, notches, perforation
//  and elevation shadow — is one inseparable unit owned by the preset, so
//  `.cardStyle(_:)` is a documented no-op there (a card style would paint the
//  notches shut). `.flat` composes the neutral `Card`, so `.cardStyle(_:)`
//  applies to it transitively.
//
//  ```swift
//  FlightTicketCard(from: "NYC", to: "SFO")
//      .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
//      .times(departure: "10:00 AM", arrival: "11:30 AM")
//      .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite($fav)
//      .flightTicketCardStyle(.classic)   // .horizontal / .flat / custom
//  ```
//

import SwiftUI
import ThemeKit

public struct FlightTicketCard: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.flightTicketCardStyle) private var style

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
    private var originalPrice: Decimal?
    private var currencyCode: String?
    /// Favourite state — dual-mode via `ControllableState` (ADR-F4); renamed
    /// from `favorite` so the nullary `func favorite()` overload isn't an
    /// invalid redeclaration. Hidden until `showsFavorite`.
    @ControllableState private var favoriteState = false
    private var showsFavorite = false
    private var accent: SemanticColor?
    private var elevation: CardElevation = .soft
    /// `nil` = the active style's default surface (`.bgBase` for the built-ins).
    private var surfaceKey: Theme.BackgroundColorKey?
    /// `nil` = the active style's default radius role (`.box` for the built-ins).
    private var radiusRole: Theme.RadiusRole?
    private var showsPerforation = true
    private var dashKey: Theme.BorderColorKey = .borderPrimary
    private var priceEmphasis: PriceEmphasis = .standard
    private var headerSlot: AnyView?
    private var customStub: AnyView?

    public init(from: String, to: String) {   // R1
        self.from = from
        self.to = to
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The accent's `.primary` fallback (deferred unification) lives in the
        // configuration's accent resolvers; the heart's motion gating lives in
        // the style file's shared heart building block.
        let configuration = FlightTicketCardConfiguration(
            from: from, to: to, fromCity: fromCity, toCity: toCity,
            departure: departure, arrival: arrival, duration: duration, stops: stops,
            airline: airline, airlineIcon: airlineIcon, airlineLogo: airlineLogo,
            priceAmount: price, originalAmount: originalPrice,
            currencyCode: resolvedCurrency, priceEmphasis: priceEmphasis,
            isFavorite: showsFavorite ? favoriteState : nil,
            toggleFavorite: showsFavorite ? { favoriteState.toggle() } : nil,
            accent: accent, surfaceKey: surfaceKey, elevation: elevation,
            radiusRole: radiusRole, showsPerforation: showsPerforation, dashKey: dashKey,
            header: headerSlot, stub: customStub,
            density: density, locale: locale
        )
        style.makeBody(configuration: configuration)
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
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    /// Pre-discount price shown struck through next to the price (via
    /// `PriceTag.original(_:)`); `nil` (the default) hides it.
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    /// A heart toggle in the stub bound to a favourite flag (controlled — the
    /// caller owns persistence).
    func favorite(_ binding: Binding<Bool>) -> Self {
        copy {
            $0.showsFavorite = true
            $0._favoriteState = ControllableState(wrappedValue: false, external: binding)
        }
    }
    /// A self-managed heart toggle in the stub (uncontrolled). Survives List
    /// *scrolling* (state-per-identity) but not identity churn — use
    /// ``favorite(_:)`` when the flag must persist.
    func favorite() -> Self { copy { $0.showsFavorite = true } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Replaces the built-in airline / price / favourite stub with custom
    /// content — the active style places it in its tear-off area.
    func stub<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.customStub = AnyView(content()) } }
    /// Replaces the built-in route header (codes / cities / timeline).
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// Outer corner radius (radius role token, default `.box`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Draw the dashed perforation across the tear line (default on) — tear presets only.
    func perforation(_ on: Bool = true) -> Self { copy { $0.showsPerforation = on } }
    /// Perforation dash colour (border token key, default `.borderPrimary`).
    func dashColor(_ key: Theme.BorderColorKey) -> Self { copy { $0.dashKey = key } }
    /// Emphasis of the stub's `PriceTag` (default `.standard`).
    func priceEmphasis(_ e: PriceEmphasis) -> Self { copy { $0.priceEmphasis = e } }

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
            ScrollView {
                VStack(spacing: 16) {
                    FlightTicketCard(from: "NYC", to: "SFO")
                        .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
                        .times(departure: "10:00 AM", arrival: "11:30 AM")
                        .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite($fav).accent(.info)
                    // Hero price emphasis + tighter corner + tinted dashes, no perforation variant.
                    FlightTicketCard(from: "IST", to: "LHR")
                        .cities(from: "Istanbul", to: "London").duration("3h 55m")
                        .times(departure: "09:20", arrival: "12:15")
                        .airline("Sunrise Air").price(220, currencyCode: "USD")
                        .priceEmphasis(.hero).cornerRadius(.field).dashColor(.borderHero)
                    FlightTicketCard(from: "IST", to: "AMS")
                        .duration("3h 30m").times(departure: "07:10", arrival: "09:40")
                        .airline("Blue Wings").price(180, currencyCode: "USD")
                        .perforation(false)
                    // Custom stub slot — placed in the active style's tear-off area.
                    FlightTicketCard(from: "SAW", to: "ESB")
                        .duration("1h 10m").times(departure: "18:00", arrival: "19:10")
                        .stub {
                            HStack {
                                Text("Booking").textStyle(.bodySm400)
                                Spacer()
                                Text("X7K2QF").textStyle(.labelSm700)
                            }
                        }
                }
                .frame(maxWidth: 320).padding()
            }
        }
    }
    return Demo()
}

// Every built-in preset — light + dark via PreviewMatrix — plus a custom
// in-preview style proving external implementability (token-fed, soft accent
// banner with the route line and the price).
#Preview("Styles × light/dark") {
    struct BannerTicketStyle: FlightTicketCardStyle {
        func makeBody(configuration: FlightTicketCardConfiguration) -> some View {
            BannerBody(configuration: configuration)
        }
        struct BannerBody: View {
            @Environment(\.theme) private var theme
            let configuration: FlightTicketCardConfiguration
            var body: some View {
                HStack(spacing: configuration.spacing(.sm)) {
                    Text(configuration.from).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                    Icon(systemName: "arrow.forward").size(.xs).color(theme.text(.textTertiary))
                    Text(configuration.to).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                    if let duration = configuration.duration {
                        Text(duration).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                    Spacer(minLength: configuration.spacing(.sm))
                    if let price = configuration.priceAmount {
                        PriceTag(price, currencyCode: configuration.currencyCode).size(.small).fractionDigits(0)
                    }
                }
                .padding(configuration.spacing(.md))
                .background(
                    RoundedRectangle(cornerRadius: configuration.cornerRadius, style: .continuous)
                        .fill((configuration.accent ?? .primary).soft)
                )
            }
        }
    }

    func ticket() -> FlightTicketCard {
        FlightTicketCard(from: "NYC", to: "SFO")
            .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
            .times(departure: "10:00 AM", arrival: "11:30 AM")
            .airline("Garuda Indonesia").price(140, currencyCode: "USD").favorite().accent(.info)
    }

    return PreviewMatrix("FlightTicketCard styles") {
        PreviewCase("classic (default)") { ticket().frame(width: 300) }
        PreviewCase("horizontal") { ticket().flightTicketCardStyle(.horizontal).frame(width: 300) }
        PreviewCase("flat") { ticket().flightTicketCardStyle(.flat).frame(width: 300) }
        PreviewCase("custom (BannerTicketStyle)") {
            ticket().flightTicketCardStyle(BannerTicketStyle()).frame(width: 300)
        }
    }
}

// The perforated tear shell is per-preset chrome (see header note): on the
// `.classic` default, `.cardStyle(.outlined)` renders identically to the
// default — the no-op is deliberate. Swap to `.flat` and it applies.
#Preview("Card-style no-op on tear presets") {
    FlightTicketCard(from: "NYC", to: "SFO")
        .cities(from: "New York City", to: "San Francisco").duration("1h 45m")
        .times(departure: "10:00 AM", arrival: "11:30 AM")
        .airline("Garuda Indonesia").price(140, currencyCode: "USD")
        .favorite()   // uncontrolled heart, off until tapped
        .cardStyle(.outlined)
        .frame(maxWidth: 320).padding()
}
