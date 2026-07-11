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
import ThemeKit

/// Layout archetype for ``FareFamilyCard``.
public enum FareFamilyLayout: String, CaseIterable, Sendable {
    /// The classic full-width card — leading chip, feature list, price footer.
    case stacked
    /// A narrow comparison-matrix column — centered chip, condensed features,
    /// price pinned at the bottom. Place several side by side in an `HStack`.
    case column
}

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
    private var headerSlot: AnyView?
    private var ctaTitleOverride: String?
    private var chipVariant: FillVariant = .solid
    private var elevation: CardElevation = .none
    private var layout: FareFamilyLayout = .stacked

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
            elevation: elevation,
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
    @ViewBuilder private var cardContent: some View {
        switch layout {
        case .stacked: stackedContent
        case .column: columnContent
        }
    }

    private var stackedContent: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if let headerSlot { headerSlot } else { tierChip }

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

    /// The narrow comparison-matrix column: centered chip, condensed features,
    /// price at the bottom. Designed to sit side by side in an `HStack`.
    private var columnContent: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Group {
                if let headerSlot { headerSlot } else { tierChip }
            }
            .frame(maxWidth: .infinity, alignment: .center)

            if !features.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(features) { FareFeatureRow($0) }
                }
            }

            Spacer(minLength: 0)

            if let footerSlot {
                footerSlot
            } else {
                columnFooter
            }
        }
        .padding(density.scale(Theme.SpacingKey.sm.value))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The tier name chip, rendered per ``FillVariant`` on the accent's ladder.
    private var tierChip: some View {
        Text(name.uppercased())
            .textStyle(.labelSm700)
            .foregroundStyle(chipForeground)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(chipBackground,
                        in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
            .overlay {
                if chipVariant == .outline {
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .strokeBorder(accent.border, lineWidth: 1)
                }
            }
    }

    private var chipForeground: Color {
        switch chipVariant {
        case .solid: return accent.onSolid
        case .soft, .outline, .ghost: return accent.accent
        }
    }
    private var chipBackground: Color {
        switch chipVariant {
        case .solid: return accent.solid
        case .soft: return accent.soft
        case .outline, .ghost: return .clear
        }
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
            ThemeButton(ctaText) { select() }
                .color(accent).shape(.rounded).fullWidth()
                .padding(.top, 4)
        }
    }

    /// Column-mode footer — price and control stacked, centered, pinned at the bottom.
    @ViewBuilder private var columnFooter: some View {
        if let selection {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                PriceTag(price, currencyCode: resolvedCurrency).emphasis(.hero)
                RadioButton(isSelected: selection)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        } else {
            ThemeButton(ctaText) { select() }
                .color(accent).shape(.rounded).size(.small).fullWidth()
                .padding(.top, 4)
        }
    }

    private var ctaText: String { ctaTitleOverride ?? priceText }
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
    /// Replace the tier name chip with custom header content.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }
    /// A custom CTA title (e.g. "Choose Super Eco"); `nil` (default) keeps the
    /// formatted price as the button label.
    func ctaTitle(_ text: String?) -> Self { copy { $0.ctaTitleOverride = text } }
    /// Fill treatment of the tier name chip (default `.solid`).
    func badgeVariant(_ v: FillVariant) -> Self { copy { $0.chipVariant = v } }
    /// Shell elevation, fed to the active `CardStyle` (default `.none` — today's
    /// flat, hairline-only chrome).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Layout archetype: `.stacked` (default) or a narrow comparison `.column`.
    func layout(_ v: FareFamilyLayout) -> Self { copy { $0.layout = v } }

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
            // Soft chip variant + custom CTA title + soft elevation.
            FareFamilyCard("Business", price: 6_420).accent(.info)
                .badgeVariant(.soft).ctaTitle("Choose Business").elevation(.soft)
                .features([FareFeature("Lounge access", systemImage: "sofa.fill", status: .included)])
                .onSelect { }
            // Outline chip + custom header slot.
            FareFamilyCard("Promo", price: 999).accent(.orange)
                .badgeVariant(.outline)
                .header { HStack { Text("PROMO").textStyle(.labelSm700); Spacer(); Badge("−20%").badgeStyle(.error).size(.small) } }
                .onSelect { }
        }.padding()
    }
}

#Preview("Comparison columns") {
    HStack(alignment: .top, spacing: 10) {
        FareFamilyCard("Eco", price: 1_871.99).accent(.success).layout(.column)
            .features([
                FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                FareFeature("Checked", systemImage: "suitcase.fill", status: .excluded),
            ])
            .selection(.constant(false))
        FareFamilyCard("Flex", price: 3_116.99).accent(.purple).layout(.column)
            .features([
                FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                FareFeature("Checked", systemImage: "suitcase.fill", status: .included),
            ])
            .selection(.constant(true))
        FareFamilyCard("Biz", price: 6_420).accent(.info).layout(.column)
            .badgeVariant(.soft).ctaTitle("Choose")
            .features([FareFeature("Lounge", systemImage: "sofa.fill", status: .included)])
            .onSelect { }
    }
    .frame(height: 260)
    .padding()
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
