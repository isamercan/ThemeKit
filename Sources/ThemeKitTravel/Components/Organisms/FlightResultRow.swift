//
//  FlightResultRow.swift
//  ThemeKit
//
//  Organism. A compact flight search-result row — airline (logo/name/flight no +
//  cabin), departure→arrival times & codes with a duration/stops path, an optional
//  baggage chip, a price and a Select action. The row counterpart to ``FlightCard``.
//  Token-bound; reuses PriceTag, Badge, Icon, ThemeButton.
//
//  Presentation is style-driven (ADR-0004): the component gathers its typed data
//  into a ``FlightResultRowConfiguration`` and hands it to the active
//  ``FlightResultRowStyle`` from the environment — `.row` (the default, the
//  classic look), `.stacked`, `.minimal`, or any custom conformance set via
//  `.flightResultRowStyle(_:)`.
//
//  The outer shell (surface fill, corner clipping, hairline border) is drawn by the
//  active `CardStyle` from the environment — `.surface()` feeds the
//  `CardStyleConfiguration`, so the default look is unchanged while `.cardStyle(_:)`
//  can swap in a completely different shell. The row is shadowless with an
//  always-on hairline, which is `DefaultCardStyle` at `.none` elevation exactly.
//

import SwiftUI
import ThemeKit

// Round-trip / multi-leg reuses the shared `FlightLeg` model (see FlightCard.swift).

public struct FlightResultRow: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.flightResultRowStyle) private var style
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isReadOnly) private var isReadOnly

    // Required content (R1).
    private let airline: String
    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    // Appearance/state — mutated only through the modifiers below (R2).
    /// `nil` lets the style pick its default surface (`.bgBase` for the built-ins).
    private var surfaceKey: Theme.BackgroundColorKey?
    private var accent: SemanticColor?
    private var flightNo: String?
    private var cabinClass: String?
    private var airlineSystemImage = "airplane.circle.fill"
    private var airlineLogoURL: URL?
    private var stops = 0
    private var extraLegs: [FlightLeg] = []
    private var price: Decimal?
    private var currencyCode: String?
    private var baggage: String?
    private var badge: String?
    private var badgeStyle: BadgeStyle = .success
    private var isSelected = false
    private var elevation: CardElevation = .none
    private var priceFractionDigits = 2
    private var footerSlot: AnyView?
    private var trailingSlot: AnyView?
    private var detailsTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var detailsTitle: String { detailsTitleOverride ?? String(themeKit: "Details") }
    /// Favourite/bookmark state — dual-mode via `ControllableState` (ADR-F4);
    /// renamed from `favorite`/`bookmark` so the nullary overloads aren't
    /// invalid redeclarations. Hidden until the `shows…` flags flip.
    @ControllableState private var favoriteState = false
    @ControllableState private var bookmarkState = false
    private var showsFavorite = false
    private var showsBookmark = false
    private var totalAmount: Decimal?
    private var totalLabel: String?
    private var urgencyText: String?
    private var selectTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var selectTitle: String { selectTitleOverride ?? String(themeKit: "Select") }
    private var onSelect: (() -> Void)?
    private var onDetails: (() -> Void)?

    public init(airline: String, from origin: String, to destination: String, departure: Date, arrival: Date) {
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.themeKitCurrencyCode ?? "USD"
    }

    public var body: some View {
        // The active `FlightResultRowStyle` owns the entire presentation —
        // built-ins and custom styles go through the same gate. The default
        // `.row` reproduces the classic three-column layout verbatim.
        style.makeBody(configuration: configuration)
    }

    /// The typed snapshot handed to the style — rebuilt every body pass, so
    /// render-time defaults (localized titles, environment currency) stay live.
    /// Motion is resolved *here* (ADR-0004 §4): styles receive the pre-gated
    /// `favoriteBounceValue` and never read the motion environment themselves.
    @MainActor
    private var configuration: FlightResultRowConfiguration {
        FlightResultRowConfiguration(
            airline: airline,
            legs: [FlightLeg(airline: airline, from: origin, to: destination,
                             departure: departure, arrival: arrival, stops: stops)] + extraLegs,
            flightNo: flightNo,
            cabin: cabinClass,
            airlineSystemImage: airlineSystemImage,
            airlineLogoURL: airlineLogoURL,
            priceAmount: price,
            currencyCode: resolvedCurrency,
            priceFractionDigits: priceFractionDigits,
            totalAmount: totalAmount,
            totalLabel: totalLabel,
            baggage: baggage,
            badge: badge,
            badgeStyle: badgeStyle,
            urgencyText: urgencyText,
            isSelected: isSelected,
            isReadOnly: isReadOnly,
            elevation: elevation,
            isFavorite: showsFavorite ? favoriteState : nil,
            toggleFavorite: showsFavorite ? { favoriteState.toggle() } : nil,
            isBookmarked: showsBookmark ? bookmarkState : nil,
            toggleBookmark: showsBookmark ? { bookmarkState.toggle() } : nil,
            favoriteBounceValue: (micro && !reduceMotion) ? favoriteState : false,
            selectTitle: selectTitle,
            onSelect: onSelect,
            detailsTitle: detailsTitle,
            onDetails: onDetails,
            footer: footerSlot,
            trailing: trailingSlot,
            accent: accent,
            surfaceKey: surfaceKey,
            density: density,
            locale: locale)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightResultRow {
    /// Surface fill (background token key) — feeds the active style's shell.
    /// When unset, the style picks its default (`.bgBase` for the built-ins,
    /// so the classic look is unchanged).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// A semantic accent for the brand chrome — the airline fallback glyph, the
    /// active bookmark and the Select button. `nil` (default) keeps the theme's
    /// hero styling. Semantic colours (favourite red, urgency red, nonstop
    /// green) are fixed and unaffected.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
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
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    /// A leading airline SF Symbol (default `airplane.circle.fill`).
    func airlineIcon(_ systemName: String) -> Self { copy { $0.airlineSystemImage = systemName } }
    /// A remote airline logo (overrides the SF Symbol).
    func airlineLogo(_ url: URL?) -> Self { copy { $0.airlineLogoURL = url } }
    /// A baggage chip, e.g. "15 kg".
    func baggage(_ text: String?) -> Self { copy { $0.baggage = text } }
    /// A success badge, e.g. "Best".
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// A meta-row badge with an explicit `BadgeStyle` (the one-argument form
    /// keeps the classic `.success` styling).
    func badge(_ text: String?, style: BadgeStyle) -> Self { copy { $0.badge = text; $0.badgeStyle = style } }
    /// Selected state, fed to the active `CardStyle` (the default style draws a
    /// hero border).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Shell elevation, fed to the active `CardStyle` (default `.none` — today's
    /// flat, hairline-only chrome).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Fraction digits for the fare `PriceTag` (default 2).
    func priceFractionDigits(_ n: Int) -> Self { copy { $0.priceFractionDigits = max(0, n) } }
    /// Replaces the built-in meta row (badge / baggage / urgency / Details).
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }
    /// Replaces the built-in trailing price / favourite / Select area.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    /// A heart toggle bound to a favourite flag (controlled — the caller owns
    /// persistence).
    func favorite(_ isFavorite: Binding<Bool>) -> Self {
        copy {
            $0.showsFavorite = true
            $0._favoriteState = ControllableState(wrappedValue: false, external: isFavorite)
        }
    }
    /// A self-managed heart toggle (uncontrolled). Survives List *scrolling*
    /// (state-per-identity) but not identity churn — use ``favorite(_:)`` when
    /// the flag must persist.
    func favorite() -> Self { copy { $0.showsFavorite = true } }
    /// A bookmark (save) toggle bound to a flag (controlled).
    func bookmark(_ isSaved: Binding<Bool>) -> Self {
        copy {
            $0.showsBookmark = true
            $0._bookmarkState = ControllableState(wrappedValue: false, external: isSaved)
        }
    }
    /// A self-managed bookmark toggle (uncontrolled) — same identity caveat as
    /// ``favorite()``.
    func bookmark() -> Self { copy { $0.showsBookmark = true } }
    /// A secondary total-price line under the fare, e.g. "3 travellers: 43.068 TL".
    func totalPrice(_ amount: Decimal?, label: String) -> Self { copy { $0.totalAmount = amount; $0.totalLabel = label } }
    /// An urgency note in the meta row, shown in error red (e.g. "5 seats left!").
    func urgency(_ text: String?) -> Self { copy { $0.urgencyText = text } }
    /// Adds a Select button (with an optional custom title).
    func onSelect(_ title: String = String(themeKit: "Select"), action: @escaping () -> Void) -> Self {
        copy { $0.selectTitleOverride = title; $0.onSelect = action }
    }
    /// Adds a "Details" link in the meta row.
    func onDetails(_ action: @escaping () -> Void) -> Self { copy { $0.onDetails = action } }
    /// Adds a meta-row link with a custom title (default "Details").
    func onDetails(_ title: String = String(themeKit: "Details"), action: @escaping () -> Void) -> Self {
        copy { $0.detailsTitleOverride = title; $0.onDetails = action }
    }

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
        // Uncontrolled heart + bookmark (off) vs controlled heart (on).
        FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB", departure: dep, arrival: dep.addingTimeInterval(70 * 60))
            .flightNo("BW 810").price(2_899).favorite().bookmark()
        FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB", departure: dep, arrival: dep.addingTimeInterval(70 * 60))
            .flightNo("BW 812").price(2_499).favorite(.constant(true))
        // Accented brand chrome — glyph, active bookmark and Select follow the accent.
        FlightResultRow(airline: "Sunrise Air", from: "IST", to: "LHR", departure: dep, arrival: dep.addingTimeInterval(3 * 3_600))
            .accent(.success).flightNo("SA 101").price(4_120).bookmark(.constant(true))
            .onSelect("Select") { }
        // Styled badge · whole-number fare · selected/elevated shell · custom Details title.
        FlightResultRow(airline: "Anadolu Air", from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(95 * 60))
            .flightNo("TK 2436").price(3_950).priceFractionDigits(0)
            .badge("Fastest", style: .info)
            .onDetails("Fare rules") { }
            .selected().elevation(.soft)
        // Footer + trailing slots replace the meta row and the price area.
        FlightResultRow(airline: "Blue Wings", from: "IST", to: "ADB", departure: dep, arrival: dep.addingTimeInterval(70 * 60))
            .footer {
                HStack {
                    Badge("Charter").badgeStyle(.warning).variant(.soft).size(.small)
                    Spacer()
                    Text("Operated by partner").textStyle(.overline400)
                }
            }
            .trailing {
                VStack(alignment: .trailing, spacing: 4) {
                    Badge("Sold out").badgeStyle(.error).size(.small)
                    Text("Join waitlist").textStyle(.labelSm600)
                }
            }
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
