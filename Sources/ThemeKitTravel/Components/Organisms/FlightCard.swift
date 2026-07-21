//
//  FlightCard.swift
//  ThemeKit
//
//  A flight result / itinerary segment — airline, departure→arrival times + airport
//  codes, a flight-path line with duration and a stops label, and an optional price +
//  select action. Token-bound; the surface, accent and price all come from the theme.
//
//  The *arrangement* is owned by the active ``FlightCardStyle`` from the environment
//  (ADR-0004): the component gathers its typed data into a `FlightCardConfiguration`
//  and hands it to the style — `.standard` (default) is today's card verbatim,
//  `.condensed` and `.tile` swap the whole layout, and apps can implement their own.
//  Card-shaped styles keep drawing the outer shell (surface fill, corner clipping,
//  hairline border) through the active `CardStyle`, so `.cardStyle(_:)` still swaps
//  the chrome independently. The default card is shadowless with an always-on
//  hairline, which is `DefaultCardStyle` at `.none` elevation exactly.
//

import SwiftUI
import ThemeKit

/// A token-bound flight card — one segment, or a multi-leg itinerary.
///
/// ```swift
/// FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB",
///            departure: dep, arrival: arr)
///     .stops(1).price(1_299).badge("Cheapest") { book() }
///
/// FlightCard(legs: [outbound, ret]).price(7_178).scarcity(5).onSelect { }
/// ```
public struct FlightCard: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.flightCardStyle) private var style
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Required content (R1).
    private let airline: String
    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    private let legs: [FlightLeg]?
    // Appearance/state — mutated only through the modifiers below (R2).
    /// `nil` → the style's own default surface (`.standard` uses `.bgBase`).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var accent: SemanticColor?
    private var stops: Int = 0
    private var price: Decimal?
    private var currencyCode: String?
    private var airlineSystemImage: String = "airplane.circle.fill"
    private var airlineLogoURL: URL?
    private var badge: String?
    private var badgeStyle: BadgeStyle = .success
    private var selectTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var selectTitle: String { selectTitleOverride ?? String(themeKit: "Select") }
    private var onSelect: (() -> Void)?
    private var elevation: CardElevation = .none
    private var isSelected = false
    private var headerSlot: AnyView?
    /// Favourite state — dual-mode via `ControllableState` (ADR-F4); renamed
    /// from `favorite` so the nullary `func favorite()` overload isn't an
    /// invalid redeclaration. Hidden until `showsFavorite`.
    @ControllableState private var favoriteState = false
    private var showsFavorite = false
    private var scarcity: Int?
    private var fareBrand: String?
    private var footerSlot: AnyView?

    public init(airline: String, from origin: String, to destination: String, departure: Date, arrival: Date) {
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
        self.legs = nil
    }

    /// A multi-leg itinerary (outbound + return, connections…). The header uses the
    /// first leg's airline; each leg draws its own route and layover.
    public init(legs: [FlightLeg]) {
        let first = legs.first
        self.airline = first?.airline ?? ""
        self.origin = first?.origin ?? ""
        self.destination = first?.destination ?? ""
        self.departure = first?.departure ?? .distantPast
        self.arrival = first?.arrival ?? .distantPast
        self.legs = legs
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.themeKitCurrencyCode ?? "USD"
    }

    public var body: some View {
        // The arrangement is owned by the active `FlightCardStyle`; motion is
        // resolved *here* (MicroMotion ∧ ¬Reduce Motion) so styles never read
        // the motion environment. Single-segment cards synthesize one leg so
        // every style sees the same typed shape.
        let configuration = FlightCardConfiguration(
            airline: airline,
            legs: legs ?? [FlightLeg(airline: airline, from: origin, to: destination,
                                     departure: departure, arrival: arrival, stops: stops)],
            isMultiLeg: legs != nil,
            airlineSystemImage: airlineSystemImage,
            logo: airlineLogoURL.map { AnyView(RemoteImage($0).ratio(1)) },
            fareBrand: fareBrand,
            badge: badge,
            badgeStyle: badgeStyle,
            priceAmount: price,
            currencyCode: resolvedCurrency,
            scarcity: scarcity,
            stops: stops,
            isSelected: isSelected,
            selectTitle: selectTitle,
            onSelect: onSelect,
            accent: accent,
            surfaceKey: surfaceKey,
            elevation: elevation,
            header: headerSlot,
            footer: footerSlot,
            isFavorite: showsFavorite ? favoriteState : nil,
            toggleFavorite: showsFavorite ? { favoriteState.toggle() } : nil,
            isMotionEnabled: micro && !reduceMotion,
            density: density,
            locale: locale)
        style.makeBody(configuration: configuration)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightCard {
    /// Surface fill (background token key). When unset, the active
    /// ``FlightCardStyle`` picks its own default (`.standard` uses `.bgBase`);
    /// card-shaped styles feed it through to the `CardStyle` shell.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// A semantic accent for the brand chrome — the airline icon, the route-path
    /// planes and the Select button. `nil` (default) keeps the theme's hero
    /// styling. Semantic colours (favourite red, scarcity, nonstop green) are
    /// fixed and unaffected.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Number of stops (0 = nonstop, shown in green).
    func stops(_ count: Int) -> Self { copy { $0.stops = max(0, count) } }
    /// The fare, rendered as a hero `PriceTag` in the footer.
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    /// A leading airline SF Symbol (default `airplane.circle.fill`).
    func airlineIcon(_ systemName: String) -> Self { copy { $0.airlineSystemImage = systemName } }
    /// A success badge in the header, e.g. `"Cheapest"`.
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// A header badge with an explicit `BadgeStyle` (the one-argument form keeps
    /// the classic `.success` styling).
    func badge(_ text: String?, style: BadgeStyle) -> Self { copy { $0.badge = text; $0.badgeStyle = style } }
    /// A remote airline logo in the header (overrides the SF Symbol) — parity
    /// with ``FlightResultRow/airlineLogo(_:)``.
    func airlineLogo(_ url: URL?) -> Self { copy { $0.airlineLogoURL = url } }
    /// Shell elevation, fed to the active `CardStyle` (default `.none` — today's
    /// flat, hairline-only chrome).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Selected state, fed to the active `CardStyle` (the default style draws a
    /// hero border).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Adds a "Select" button to the footer.
    func onSelect(_ action: (() -> Void)?) -> Self { copy { $0.onSelect = action } }
    /// Adds a footer button with a custom title (default "Select").
    func onSelect(_ title: String = String(themeKit: "Select"), action: @escaping () -> Void) -> Self {
        copy { $0.selectTitleOverride = title; $0.onSelect = action }
    }
    /// Replaces the built-in airline / fare-brand / badge / heart header row.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// A heart toggle in the header bound to a favourite flag (controlled —
    /// the caller owns persistence).
    func favorite(_ isFavorite: Binding<Bool>) -> Self {
        copy {
            $0.showsFavorite = true
            $0._favoriteState = ControllableState(wrappedValue: false, external: isFavorite)
        }
    }
    /// A self-managed heart toggle in the header (uncontrolled). Survives List
    /// *scrolling* (state-per-identity) but not identity churn — use
    /// ``favorite(_:)`` when the flag must persist.
    func favorite() -> Self { copy { $0.showsFavorite = true } }
    /// Shows a "N seats left" scarcity line (urgent colour).
    func scarcity(_ seatsLeft: Int?) -> Self { copy { $0.scarcity = seatsLeft } }
    /// A fare-brand chip next to the airline, e.g. "Eco Flex".
    func fareBrand(_ name: String?) -> Self { copy { $0.fareBrand = name } }
    /// Replaces the default price+Select footer with custom content.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }

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
            .price(1_299).badge("Cheapest").favorite().onSelect { }
        FlightCard(airline: "Blue Wings", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))
            .stops(1).price(3_499).favorite(.constant(true))
        // Accented brand chrome — icon, route planes and Select follow the accent.
        FlightCard(airline: "Sunrise Air", from: "IST", to: "LHR", departure: dep, arrival: dep.addingTimeInterval(3 * 3_600))
            .accent(.success).price(2_199).onSelect { }
        // Styled badge + custom Select title + selected/elevated shell.
        FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr)
            .badge("Fastest", style: .info).price(1_499)
            .onSelect("Book now") { }
            .selected().elevation(.soft)
        // Custom header slot replaces the built-in airline row.
        FlightCard(airline: "Blue Wings", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))
            .header {
                HStack {
                    Badge("Round trip").badgeStyle(.info).size(.small)
                    Spacer()
                    Badge("Refundable").badgeStyle(.success).size(.small)
                }
            }
            .price(3_499)
    }
    .padding()
}

#Preview("Outlined card style") {
    let dep = Date()
    return FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB",
                      departure: dep, arrival: dep.addingTimeInterval(70 * 60))
        .price(1_299).badge("Cheapest").onSelect { }
        .cardStyle(.outlined)
        .padding()
}
