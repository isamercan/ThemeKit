//
//  FareFamilyCard.swift
//  ThemeKit
//
//  Organism. A fare-family / branded-fare option — a coloured name badge, a list
//  of ``FareFeatureRow`` features & rules, and either a price CTA button or a
//  price + radio row (selectable set). Token-bound; the accent colour brands the
//  tier. Composes the FareFeatureRow atom, PriceTag, RadioButton and ThemeButton.
//
//  Presentation is style-driven (``FareFamilyCardStyle``, ADR-0004) — set once
//  per screen via `.fareFamilyCardStyle(_:)`. `.stacked` (default) is today's
//  card verbatim; `.column`/`.row`/`.accordion` swap the whole layout, and apps
//  can implement their own. Selection stays here in the component (ADR-F4):
//  every preset only ever *reads* `isSelected`/`showsSelector` and calls
//  `select()` — the `.selection(_:)` binding and the uncontrolled fallback both
//  live in this file.
//
//  The outer shell (surface fill, hairline, selected hero frame) is drawn by the
//  active `CardStyle` from the environment — card-shaped presets keep routing
//  their surface, elevation and selection state through `CardStyleConfiguration`,
//  so `.cardStyle(_:)` can reskin the shell and restyle the selected frame in one
//  place. The card is flat (no shadow), so it reports `.none` elevation and the
//  default style draws the classic 1pt hairline.
//

import SwiftUI
import ThemeKit

/// Layout archetype for ``FareFamilyCard``.
///
/// Superseded by ``FareFamilyCardStyle`` (each case maps 1:1 to a preset —
/// `.stacked`/`.column`); kept for source compatibility until the next major,
/// together with the deprecated ``FareFamilyCard/layout(_:)`` modifier.
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
///     .fareFamilyCardStyle(.row)      // .stacked (default) / .column / .accordion
/// ```
public struct FareFamilyCard: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.fareFamilyCardStyle) private var envStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Required content (R1).
    private let name: String
    private let price: Decimal
    // Appearance/state — mutated only through the modifiers below (R2).
    /// `nil` → the active style's own default (every built-in uses `.bgBase`).
    private var surfaceKey: Theme.BackgroundColorKey?
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
    /// Expansion state for `.accordion` — ignored by every other preset.
    /// Uncontrolled by default; `.expanded(_:)` swaps in the caller's binding
    /// (ADR-F4 via `ControllableState`, mirroring `FlightListItem`).
    @ControllableState private var expandedState = false
    /// Set by the deprecated ``layout(_:)`` modifier — an explicitly chosen
    /// per-instance style wins over an ancestor's `.fareFamilyCardStyle(_:)`
    /// (source-behavior stability during the enum's deprecation window).
    private var explicitStyle: AnyFareFamilyCardStyle?

    public init(_ name: String, price: Decimal) {   // R1
        self.name = name
        self.price = price
    }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    private var priceText: String {
        price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(2)))
    }

    /// Sets the `.selection(_:)` binding (when bound) and fires `.onSelect(_:)`
    /// (when set) — the one action every preset's selector/CTA calls.
    private func select() {
        selection?.wrappedValue = true
        onSelect?()
    }

    public var body: some View {
        // The arrangement is owned by the active `FareFamilyCardStyle`; motion
        // is resolved *here* (MicroMotion ∧ ¬Reduce Motion) so styles never
        // read the motion environment. `showsSelector` mirrors the pre-style
        // `selection != nil` check that used to pick the footer's look.
        let expandMotion: Animation? = (micro && !reduceMotion) ? Motion.base.spring : nil
        let configuration = FareFamilyCardConfiguration(
            name: name,
            priceAmount: price,
            currencyCode: resolvedCurrency,
            features: features,
            isSelected: selection?.wrappedValue ?? isSelected,
            showsSelector: selection != nil,
            select: { select() },
            ctaTitle: ctaTitleOverride ?? priceText,
            badgeVariant: chipVariant,
            header: headerSlot,
            footer: footerSlot,
            elevation: elevation,
            accent: accent,
            surfaceKey: surfaceKey,
            isExpanded: expandedState,
            toggleExpand: { withAnimation(expandMotion) { expandedState.toggle() } },
            isMotionEnabled: micro && !reduceMotion,
            density: density,
            locale: locale)
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FareFamilyCard {
    /// Surface fill (background token key). When unset, the active
    /// ``FareFamilyCardStyle`` picks its own default (every built-in uses
    /// `.bgBase`); card-shaped presets feed it through to the `CardStyle` shell.
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
    /// Bind selection — presets render a price + radio row instead of a CTA button.
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
    /// Drives `.accordion`'s expansion from outside — e.g. a fare-compare list
    /// where only one tier stays open at a time. Without it the card self-manages.
    func expanded(_ binding: Binding<Bool>) -> Self {
        copy { $0._expandedState = ControllableState(wrappedValue: false, external: binding) }
    }
    /// Layout archetype — superseded by the style axis: prefer
    /// `.fareFamilyCardStyle(.stacked/.column/.row/.accordion)`, settable once
    /// per screen via the environment. This modifier keeps working and, when
    /// called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .fareFamilyCardStyle(.stacked) or .fareFamilyCardStyle(.column) instead")
    func layout(_ v: FareFamilyLayout) -> Self {
        copy {
            switch v {
            case .stacked: $0.explicitStyle = AnyFareFamilyCardStyle(StandardFareFamilyCardStyle())
            case .column: $0.explicitStyle = AnyFareFamilyCardStyle(ColumnFareFamilyCardStyle())
            }
        }
    }

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
        FareFamilyCard("Eco", price: 1_871.99).accent(.success)
            .features([
                FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                FareFeature("Checked", systemImage: "suitcase.fill", status: .excluded),
            ])
            .selection(.constant(false))
            .fareFamilyCardStyle(.column)
        FareFamilyCard("Flex", price: 3_116.99).accent(.purple)
            .features([
                FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                FareFeature("Checked", systemImage: "suitcase.fill", status: .included),
            ])
            .selection(.constant(true))
            .fareFamilyCardStyle(.column)
        FareFamilyCard("Biz", price: 6_420).accent(.info)
            .badgeVariant(.soft).ctaTitle("Choose")
            .features([FareFeature("Lounge", systemImage: "sofa.fill", status: .included)])
            .onSelect { }
            .fareFamilyCardStyle(.column)
    }
    .frame(height: 260)
    .padding()
}

#Preview("Row + accordion presets") {
    ScrollView {
        VStack(spacing: 12) {
            FareFamilyCard("Super Eco", price: 1_871.99).accent(.success)
                .features([
                    FareFeature("Cabin bag", systemImage: "handbag", status: .included),
                    FareFeature("Non-refundable", systemImage: "nosign", status: .excluded),
                ])
                .onSelect { }
                .fareFamilyCardStyle(.row)
            FareFamilyCard("Comfort Flex", price: 3_116.99).accent(.purple)
                .features([
                    FareFeature("Partial refund", systemImage: "arrow.uturn.backward", status: .included),
                    FareFeature("Snack", systemImage: "takeoutbag.and.cup.and.straw.fill", status: .included),
                ])
                .onSelect { }
                .fareFamilyCardStyle(.accordion)
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
