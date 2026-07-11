//
//  FlightCard.swift
//  ThemeKit
//
//  A flight result / itinerary segment — airline, departure→arrival times + airport
//  codes, a flight-path line with duration and a stops label, and an optional price +
//  select action. Token-bound; the surface, accent and price all come from the theme.
//
//  The outer shell (surface fill, corner clipping, hairline border) is drawn by the
//  active `CardStyle` from the environment — `.surface()` feeds the
//  `CardStyleConfiguration`, so the default look is unchanged while `.cardStyle(_:)`
//  can swap in a completely different shell. The card is shadowless with an
//  always-on hairline, which is `DefaultCardStyle` at `.none` elevation exactly.
//

import SwiftUI

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
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    // Required content (R1).
    private let airline: String
    private let origin: String
    private let destination: String
    private let departure: Date
    private let arrival: Date
    private let legs: [FlightLeg]?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var stops: Int = 0
    private var price: Decimal?
    private var currencyCode: String?
    private var airlineSystemImage: String = "airplane.circle.fill"
    private var badge: String?
    private var onSelect: (() -> Void)?
    private var favorite: Binding<Bool>?
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

    public var body: some View {
        // The shell (fill, corner clipping, border) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        // `.none` matches today's chrome: no shadow, hairline border.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: .none,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: .box))
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            header
            routeContent
            if let scarcity { scarcityRow(scarcity) }
            if footerSlot != nil || price != nil || onSelect != nil { footer }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    private var header: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Image(systemName: airlineSystemImage)
                .font(.title3)
                .foregroundStyle(theme.foreground(.fgHero))
            Text(airline).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
            if let fareBrand {
                Text(fareBrand).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(theme.background(.bgSecondaryLight), in: Capsule())
            }
            Spacer()
            if let badge { Badge(badge).badgeStyle(.success).size(.small) }
            if let favorite { favoriteButton(favorite) }
        }
    }

    private func favoriteButton(_ fav: Binding<Bool>) -> some View {
        Button { fav.wrappedValue.toggle() } label: {
            Image(systemName: fav.wrappedValue ? "heart.fill" : "heart")
                .font(.body)
                .foregroundStyle(fav.wrappedValue ? theme.foreground(.systemcolorsFgError) : theme.text(.textTertiary))
                .symbolEffect(.bounce, value: fav.wrappedValue)
                .frame(minWidth: 44, minHeight: 44)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fav.wrappedValue ? "Remove from favourites" : "Add to favourites")
    }

    private func scarcityRow(_ count: Int) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Image(systemName: "flame.fill").font(.caption2)
            Text("\(count) seat\(count == 1 ? "" : "s") left").textStyle(.bodySm400)
        }
        .foregroundStyle(theme.foreground(.systemcolorsFgError))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var routeContent: some View {
        if let legs {
            VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                ForEach(Array(legs.enumerated()), id: \.offset) { index, leg in
                    if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                    legRow(leg)
                }
            }
        } else {
            route
        }
    }

    private func legRow(_ leg: FlightLeg) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            // Per-leg airline only when it differs from the header airline (avoids
            // repeating "Anadolu Air" on the first leg when the header already shows it).
            if (legs?.count ?? 0) > 1, leg.airline != airline {
                Text(leg.airline).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            }
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                timeColumn(leg.departure, code: leg.origin, alignment: .leading)
                legPath(leg)
                timeColumn(leg.arrival, code: leg.destination, alignment: .trailing)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func legPath(_ leg: FlightLeg) -> some View {
        VStack(spacing: 4) {
            Text(duration(from: leg.departure, to: leg.arrival)).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            HStack(spacing: 4) {
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
                line
                Image(systemName: "airplane").font(.system(size: 12)).foregroundStyle(theme.foreground(.fgHero))
                line
                Circle().fill(theme.text(.textTertiary)).frame(width: 5, height: 5)
            }
            Group {
                if let layover = leg.layover { Text(layover) } else { Text(stopsLabel(leg.stops)) }
            }
            .textStyle(.overline400)
            .foregroundStyle(leg.stops == 0 ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
    }

    private func duration(from: Date, to: Date) -> String {
        let minutes = max(0, Int(to.timeIntervalSince(from) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }
    private func stopsLabel(_ stops: Int) -> LocalizedStringKey {
        switch stops {
        case 0: return "Nonstop"
        case 1: return "1 stop"
        default: return "\(stops) stops"
        }
    }

    private var route: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            timeColumn(departure, code: origin, alignment: .leading)
            pathView
            timeColumn(arrival, code: destination, alignment: .trailing)
        }
        .accessibilityElement(children: .combine)
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    private func timeColumn(_ date: Date, code: String, alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 2) {
            // Captured-locale fix (§10): schedule times honour the injected \.locale.
            Text(date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(locale)))
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

    @ViewBuilder private var footer: some View {
        if let footerSlot {
            footerSlot
        } else {
            HStack {
                if let price { PriceTag(price, currencyCode: resolvedCurrency).size(.large).emphasis(.hero) }
                Spacer()
                if let onSelect { PrimaryButton("Select") { onSelect() }.size(.small) }
            }
        }
    }

    private var durationText: String {
        let minutes = max(0, Int(arrival.timeIntervalSince(departure) / 60))
        let h = minutes / 60, m = minutes % 60
        return h > 0 ? "\(h)h \(m)m" : "\(m)m"
    }

    private var stopsText: LocalizedStringKey {
        switch stops {
        case 0: return "Nonstop"
        case 1: return "1 stop"
        default: return "\(stops) stops"
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FlightCard {
    /// Surface fill (background token key, default `.bgBase`) — feeds the
    /// active `CardStyle`'s configuration.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
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
    /// Adds a "Select" button to the footer.
    func onSelect(_ action: (() -> Void)?) -> Self { copy { $0.onSelect = action } }
    /// A heart toggle in the header bound to a favourite flag.
    func favorite(_ isFavorite: Binding<Bool>) -> Self { copy { $0.favorite = isFavorite } }
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
            .price(1_299).badge("Cheapest").onSelect { }
        FlightCard(airline: "Blue Wings", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))
            .stops(1).price(3_499)
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
