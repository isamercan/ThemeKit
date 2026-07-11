//
//  FareFamilyCard.swift
//  ThemeKit
//
//  Organism. A fare-family / branded-fare option — a coloured name badge, a list
//  of ``FareFeatureRow`` features & rules, and either a price CTA button or a
//  price + radio row (selectable set). Token-bound; the accent colour brands the
//  tier. Composes the FareFeatureRow atom, PriceTag, RadioButton and ThemeButton.
//
//  The outer shell (surface fill, hairline, selected hero frame) is drawn by the
//  active `CardStyle` from the environment: `.surface()` and the selection state
//  (`.selected()` / `.selection()`) feed the `CardStyleConfiguration`, so
//  `.cardStyle(_:)` can reskin the shell and restyle the selected frame in one
//  place. The card is flat (no shadow), so it reports `.none` elevation and the
//  default style draws the classic 1pt hairline.
//

import SwiftUI

/// A token-bound fare-family option card.
///
/// ```swift
/// FareFamilyCard("Super Eco", price: 1_871.99)
///     .accent(.success)
///     .features([FareFeature("Cabin bag", systemImage: "handbag", detail: "55×40×23"),
///                FareFeature("Non-refundable", systemImage: "nosign", status: .excluded)])
///     .onSelect { book() }
/// ```
public struct FareFamilyCard: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    // Required content (R1).
    private let name: String
    private let price: Decimal
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var currencyCode: String?
    private var accent: SemanticColor = .success
    private var features: [FareFeature] = []
    private var isSelected = false
    private var selection: Binding<Bool>?
    private var onSelect: (() -> Void)?
    private var footerSlot: AnyView?

    public init(_ name: String, price: Decimal) {   // R1
        self.name = name
        self.price = price
    }

    private var active: Bool { selection?.wrappedValue ?? isSelected }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The shell (fill, hairline, selected hero frame) is drawn by the active
        // `CardStyle`; selection flows through `Configuration.isSelected`, so a
        // custom style restyles the selected frame too. Flat card → `.none`
        // elevation keeps the classic hairline (no shadow), as in HotelResultCard.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: .none,
            isSelected: active,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: .box))
            .contentShape(Rectangle())
            .onTapGesture { if selection != nil { select() } }
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(active ? .isSelected : [])
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Text(name.uppercased())
                .textStyle(.labelSm700)
                .foregroundStyle(accent.onSolid)
                .padding(.horizontal, 10).padding(.vertical, 4)
                .background(accent.solid, in: RoundedRectangle(cornerRadius: 6, style: .continuous))

            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(features) { FareFeatureRow($0) }
                }
            }

            if let footerSlot {
                footerSlot
            } else {
                footer
            }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder private var footer: some View {
        if let selection {
            HStack {
                PriceTag(price, currencyCode: resolvedCurrency).emphasis(.hero)
                Spacer()
                RadioButton(isSelected: selection)
            }
            .padding(.top, 2)
        } else {
            ThemeButton(priceText) { select() }
                .color(accent).shape(.rounded).fullWidth()
                .padding(.top, 4)
        }
    }

    private var priceText: String {
        price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(2)))
    }
    private func select() { selection?.wrappedValue = true; onSelect?() }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareFamilyCard {
    /// Surface fill (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Currency code for the price. Unset, it resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// The tier accent colour — brands the name badge and CTA (green / orange / purple…).
    func accent(_ color: SemanticColor) -> Self { copy { $0.accent = color } }
    /// The feature & rule lines.
    func features(_ list: [FareFeature]) -> Self { copy { $0.features = list } }
    /// Selected state (for a CTA card without a binding).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }
    /// Bind selection — renders a price + radio row instead of a CTA button.
    func selection(_ binding: Binding<Bool>) -> Self { copy { $0.selection = binding } }
    /// Called when the card's CTA is tapped.
    func onSelect(_ action: (() -> Void)?) -> Self { copy { $0.onSelect = action } }
    /// Replace the price/CTA footer with custom content.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var picked = true
    return ScrollView {
        VStack(spacing: 12) {
            FareFamilyCard("Super Eco", price: 1_871.99).accent(.success).features([
                FareFeature("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm"),
                FareFeature("Carry-on", systemImage: "suitcase.rolling", detail: "55×40×23 cm"),
                FareFeature("Checked", systemImage: "suitcase.fill", detail: "1 × 15 kg"),
                FareFeature("Non-refundable", systemImage: "nosign", status: .excluded),
            ]).selection($picked)
            FareFamilyCard("Comfort Flex", price: 3_116.99).accent(.purple).features([
                FareFeature("Partial refund", systemImage: "arrow.uturn.backward", status: .included),
                FareFeature("Snack", systemImage: "takeoutbag.and.cup.and.straw.fill", status: .included),
            ]).onSelect { }
        }.padding()
    }
}

#Preview("Selected + outlined style") {
    @Previewable @State var picked = true
    return VStack(spacing: 12) {
        FareFamilyCard("Super Eco", price: 1_871.99).accent(.success).features([
            FareFeature("Cabin bag", systemImage: "handbag", detail: "40×30×15 cm"),
            FareFeature("Non-refundable", systemImage: "nosign", status: .excluded),
        ]).selection($picked)
        FareFamilyCard("Comfort Flex", price: 3_116.99).accent(.purple).features([
            FareFeature("Partial refund", systemImage: "arrow.uturn.backward", status: .included),
        ]).selected()
    }
    .cardStyle(.outlined)
    .padding()
}
