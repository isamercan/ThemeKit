//
//  RoomCard.swift
//  ThemeKit
//
//  Organism. A hotel room / cabin option — an optional thumbnail, name, board type,
//  occupancy, a feature list (reusing ``FareFeatureRow``), a price block and either a
//  radio (selectable) or a Select CTA. Token-bound; every part is a modifier.
//
//  ```swift
//  RoomCard(name: "Deluxe Room, Sea View")
//      .board("All-inclusive").occupancy("2 adults, 1 child")
//      .features([FareFeature("Free cancellation", systemImage: "checkmark", status: .included)])
//      .original(12_000).discountBadge("-20%").price(9_600).unit("/ night")
//      .onSelect { book() }
//  ```
//
//  The outer shell (surface fill, corner clipping, border, elevation shadow) is drawn
//  by the active `CardStyle` from the environment — `.surface()/.cornerRadius()/
//  .elevation()` and the `selection(_:)` state feed the `CardStyleConfiguration`, so
//  `.cardStyle(_:)` can swap in a completely different shell.
//

import SwiftUI

public struct RoomCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let name: String
    // Content — mutated only through the modifiers below (R2).
    private var imageURL: URL?
    private var board: String?
    private var occupancy: String?
    private var occupancyIcon = "person.2.fill"
    private var features: [FareFeature] = []
    private var price: Decimal?
    private var currencyCode: String?
    private var originalPrice: Decimal?
    private var unit: String?
    private var discountText: String?
    private var cornerBadge: String?
    private var selection: Binding<Bool>?
    private var selectTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var selectTitle: String { selectTitleOverride ?? String(themeKit: "Select") }
    private var onSelect: (() -> Void)?
    private var footerSlot: AnyView?
    // Styling — token-fed.
    private var accent: SemanticColor?
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .soft
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase

    public init(name: String) { self.name = name }   // R1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }
    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    /// Explicit `price(_:currencyCode:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate. The
        // radio `selection(_:)` state feeds `isSelected`, so the selected border is
        // the style's to draw (the default style uses the hero border token).
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: isSelected,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
            .contentShape(shape)
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            header
            if let occupancy {
                HStack(spacing: 6) {
                    Image(systemName: occupancyIcon).font(.system(size: 13)).foregroundStyle(theme.text(.textTertiary))
                    Text(occupancy).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(features) { FareFeatureRow($0) }
                }
            }
            if let footerSlot { footerSlot }
            if price != nil || selection != nil || onSelect != nil { Divider().overlay(theme.border(.borderPrimary)) }
            priceBlock
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    private var isSelected: Bool { selection?.wrappedValue ?? false }

    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: resolvedCurrency).size(.medium)
        if let unit { b = b.unit(unit) }
        if let originalPrice { b = b.original(originalPrice) }
        if let discountText { b = b.discountBadge(discountText) }
        return b
    }

    private var header: some View {
        HStack(alignment: .top, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let imageURL {
                RemoteImage(imageURL).contentMode(.fill).frame(width: 72, height: 72).clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text(name).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(2)
                if let board { Text(board).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)) }
            }
            Spacer(minLength: 4)
            if let cornerBadge { Badge(cornerBadge).badgeStyle(.warning).variant(.soft).size(.small) }
        }
    }

    @ViewBuilder private var priceBlock: some View {
        HStack(alignment: .bottom) {
            priceBreakdown
            Spacer()
            trailingControl
        }
    }

    @ViewBuilder private var trailingControl: some View {
        if let selection {
            Button { selection.wrappedValue.toggle() } label: {
                Image(systemName: selection.wrappedValue ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 22)).foregroundStyle(selection.wrappedValue ? theme.resolve(accentSemantic).base : theme.text(.textTertiary))
            }.buttonStyle(.plain).accessibilityLabel(name)
                .accessibilityAddTraits(selection.wrappedValue ? .isSelected : [])
        } else if let onSelect {
            ThemeButton(selectTitle) { onSelect() }.color(accentSemantic).size(.small)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RoomCard {
    func image(_ url: URL?) -> Self { copy { $0.imageURL = url } }
    func board(_ text: String?) -> Self { copy { $0.board = text } }
    func occupancy(_ text: String?, icon: String = "person.2.fill") -> Self { copy { $0.occupancy = text; $0.occupancyIcon = icon } }
    func features(_ items: [FareFeature]) -> Self { copy { $0.features = items } }
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    func unit(_ text: String?) -> Self { copy { $0.unit = text } }
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text } }
    func badge(_ text: String?) -> Self { copy { $0.cornerBadge = text } }
    /// Radio selection binding (mutually exclusive with ``onSelect(_:action:)``).
    func selection(_ binding: Binding<Bool>) -> Self { copy { $0.selection = binding } }
    /// A trailing Select button.
    func onSelect(_ title: String = String(themeKit: "Select"), action: @escaping () -> Void) -> Self {
        copy { $0.selectTitleOverride = title; $0.onSelect = action }
    }
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
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
        @State var selected = true
        var body: some View {
            PreviewMatrix("RoomCard") {
                PreviewCase("Full · features + discount + badge + CTA") {
                    RoomCard(name: "Deluxe Room, Sea View")
                        .board("All-inclusive").occupancy("2 adults, 1 child")
                        .features([
                            FareFeature("Free cancellation", systemImage: "checkmark.circle", status: .included),
                            FareFeature("Breakfast included", systemImage: "cup.and.saucer", status: .included),
                        ])
                        .original(12_000).discountBadge("-20%").price(9_600).unit("/ night")
                        .badge("Last 2").onSelect { }
                }
                PreviewCase("Radio selection · selected") {
                    RoomCard(name: "Standard Room, Garden View")
                        .board("Bed & breakfast").occupancy("2 adults")
                        .price(6_400).unit("/ night")
                        .selection($selected)
                }
                PreviewCase("Minimal · name only") {
                    RoomCard(name: "Family Suite")
                }
            }
        }
    }
    return Demo()
}

#Preview("Outlined style + selection") {
    struct Demo: View {
        @State var selected = true
        var body: some View {
            VStack(spacing: 12) {
                RoomCard(name: "Standard Room, Garden View")
                    .board("Bed & breakfast").occupancy("2 adults")
                    .price(6_400).unit("/ night")
                    .selection($selected)
                RoomCard(name: "Family Suite")
                    .board("Half board").occupancy("2 adults, 2 children")
                    .price(14_200).unit("/ night")
                    .selection(.constant(false))
            }
            .cardStyle(.outlined)
            .padding()
        }
    }
    return Demo()
}
