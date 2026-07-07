//
//  FareFamilyCard.swift
//  ThemeKit
//
//  Organism. A fare-family / branded-fare option — a coloured name badge, a list
//  of ``FareFeatureRow`` features & rules, and either a price CTA button or a
//  price + radio row (selectable set). Token-bound; the accent colour brands the
//  tier. Composes the FareFeatureRow atom, PriceTag, RadioButton and ThemeButton.
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
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    // Required content (R1).
    private let name: String
    private let price: Decimal
    // Appearance/state — mutated only through the modifiers below (R2).
    private var currencyCode = "TRY"
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
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous) }

    public var body: some View {
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
        .background(theme.background(.bgBase), in: shape)
        .overlay(shape.stroke(active ? theme.foreground(.fgHero) : theme.border(.borderPrimary), lineWidth: active ? 2 : 1))
        .contentShape(Rectangle())
        .onTapGesture { if selection != nil { select() } }
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    @ViewBuilder private var footer: some View {
        if let selection {
            HStack {
                PriceTag(price, currencyCode: currencyCode).emphasis(.hero)
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
        price.formatted(.currency(code: currencyCode).precision(.fractionLength(2)))
    }
    private func select() { selection?.wrappedValue = true; onSelect?() }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareFamilyCard {
    /// Currency code for the price (default "TRY").
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
