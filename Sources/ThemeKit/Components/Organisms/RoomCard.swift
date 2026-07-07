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

import SwiftUI

public struct RoomCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let name: String
    // Content — mutated only through the modifiers below (R2).
    private var imageURL: URL?
    private var board: String?
    private var occupancy: String?
    private var occupancyIcon = "person.2.fill"
    private var features: [FareFeature] = []
    private var price: Decimal?
    private var currencyCode = "TRY"
    private var originalPrice: Decimal?
    private var unit: String?
    private var discountText: String?
    private var cornerBadge: String?
    private var selection: Binding<Bool>?
    private var selectTitle = "Select"
    private var onSelect: (() -> Void)?
    private var footerSlot: AnyView?
    // Styling — token-fed.
    private var accent: SemanticColor?
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .soft
    private var surfaceKey: Theme.BackgroundColorKey = .bgElevatorPrimary

    public init(name: String) { self.name = name }   // R1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }
    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    public var body: some View {
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
        .background(theme.background(surfaceKey), in: shape)
        .overlay(shape.stroke(isSelected ? accentSemantic.base : theme.border(.borderPrimary), lineWidth: isSelected ? 1.5 : 1))
        .modifier(RoomCardShadow(elevation: elevation))
        .contentShape(shape)
    }

    private var isSelected: Bool { selection?.wrappedValue ?? false }

    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: currencyCode).size(.medium)
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
                    .font(.system(size: 22)).foregroundStyle(selection.wrappedValue ? accentSemantic.base : theme.text(.textTertiary))
            }.buttonStyle(.plain).accessibilityLabel(name)
        } else if let onSelect {
            ThemeButton(selectTitle) { onSelect() }.color(accentSemantic).size(.small)
        }
    }
}

private struct RoomCardShadow: ViewModifier {
    let elevation: CardElevation
    @ViewBuilder func body(content: Content) -> some View {
        switch elevation {
        case .none: content
        case .soft: content.themeShadow(.soft)
        case .elevated: content.themeShadow(.elevated)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RoomCard {
    func image(_ url: URL?) -> Self { copy { $0.imageURL = url } }
    func board(_ text: String?) -> Self { copy { $0.board = text } }
    func occupancy(_ text: String?, icon: String = "person.2.fill") -> Self { copy { $0.occupancy = text; $0.occupancyIcon = icon } }
    func features(_ items: [FareFeature]) -> Self { copy { $0.features = items } }
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    func unit(_ text: String?) -> Self { copy { $0.unit = text } }
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text } }
    func badge(_ text: String?) -> Self { copy { $0.cornerBadge = text } }
    /// Radio selection binding (mutually exclusive with ``onSelect(_:action:)``).
    func selection(_ binding: Binding<Bool>) -> Self { copy { $0.selection = binding } }
    /// A trailing Select button.
    func onSelect(_ title: String = "Select", action: @escaping () -> Void) -> Self { copy { $0.selectTitle = title; $0.onSelect = action } }
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
    VStack(spacing: 12) {
        RoomCard(name: "Deluxe Room, Sea View")
            .board("All-inclusive").occupancy("2 adults, 1 child")
            .features([
                FareFeature("Free cancellation", systemImage: "checkmark.circle", status: .included),
                FareFeature("Breakfast included", systemImage: "cup.and.saucer", status: .included),
            ])
            .original(12_000).discountBadge("-20%").price(9_600).unit("/ night")
            .badge("Last 2").onSelect { }
    }
    .padding()
}
