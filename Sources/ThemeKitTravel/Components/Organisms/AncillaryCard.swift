//
//  AncillaryCard.swift
//  ThemeKit
//
//  Organism. A booking add-on / extra — an icon or thumbnail, a title (+ optional
//  badge) and subtitle, a price, and either a quantity stepper or an add/remove
//  toggle. Baggage, meals, insurance, seats… Token-bound; every part is a modifier.
//
//  ```swift
//  AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg")
//      .price(450).quantity($bags, range: 0...4)
//  ```
//
//  The outer shell (surface fill, corner clipping, border, elevation shadow) is drawn
//  by the active `CardStyle` from the environment — `.surface()/.cornerRadius()` and
//  the added/quantity "active" state (as `isSelected`) feed the
//  `CardStyleConfiguration`, so `.cardStyle(_:)` can swap in a different shell.
//

import SwiftUI
import ThemeKit

public struct AncillaryCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let title: String
    // Content/appearance — mutated only through the modifiers below (R2).
    private var systemImage = "plus.circle.fill"
    private var imageURL: URL?
    private var subtitle: String?
    private var price: Decimal?
    private var currencyCode: String?
    private var priceSuffix: String?
    private var badgeText: String?
    private var badgeStyle: BadgeStyle = .info
    /// Quantity / added state — dual-mode via `ControllableState` (ADR-F4);
    /// renamed from `quantity`/`added` so the binding-less overloads aren't
    /// invalid redeclarations. Hidden until the `shows…` flags flip.
    @ControllableState private var quantityState = 0
    private var showsQuantity = false
    private var quantityRange: ClosedRange<Int> = 0...9
    @ControllableState private var addedState = false
    private var showsAdded = false
    private var addTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var addTitle: String { addTitleOverride ?? String(themeKit: "Add") }
    private var addedTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var addedTitle: String { addedTitleOverride ?? String(themeKit: "Added") }
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var controlSurfaceKey: Theme.BackgroundColorKey = .bgSecondary
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .none
    private var leadingSlot: AnyView?
    private var trailingSlot: AnyView?

    public init(_ title: String) { self.title = title }   // R1

    @Environment(\.componentDefaults) private var defaults
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — set by `.readOnly(_:)`
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }
    @MainActor
    private var isActive: Bool { (showsAdded && addedState) || (showsQuantity && quantityState > 0) }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate. The
        // added/quantity "active" state feeds `isSelected`, so the selected border is
        // the style's to draw (the default style uses the hero border token). `.none`
        // elevation reproduces today's flat look: a 1pt hairline border, no shadow.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: isActive,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
            .contentShape(shape)
    }

    /// The card's inner layout — everything inside the shell.
    @MainActor
    private var cardContent: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let badgeText { Badge(badgeText).badgeStyle(badgeStyle).variant(.soft).size(.small).fixedSize() }
                }
                if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                if let price { priceLine(price) }
            }
            Spacer(minLength: 6)
            control
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    @ViewBuilder private var leading: some View {
        if let leadingSlot {
            leadingSlot
        } else if let imageURL {
            RemoteImage(imageURL).contentMode(.fill).frame(width: 46, height: 46)
                .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        } else {
            IconTile(systemImage).accent(accentSemantic)
        }
    }

    private func priceLine(_ amount: Decimal) -> some View {
        HStack(spacing: 2) {
            Text(amount.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0))))
                .textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
            if let priceSuffix { Text(priceSuffix).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
        }
    }

    @MainActor
    @ViewBuilder private var control: some View {
        if let trailingSlot {
            trailingSlot
        } else if showsQuantity {
            stepper($quantityState)
        } else if showsAdded {
            addButton($addedState)
        }
    }

    private func stepper(_ qty: Binding<Int>) -> some View {
        HStack(spacing: 0) {
            stepButton("minus", label: String(themeKit: "Decrease"), value: qty.wrappedValue, enabled: qty.wrappedValue > quantityRange.lowerBound) {
                qty.wrappedValue = max(quantityRange.lowerBound, qty.wrappedValue - 1)
            }
            Text("\(qty.wrappedValue)").textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 28).monospacedDigit()
            stepButton("plus", label: String(themeKit: "Increase"), value: qty.wrappedValue, enabled: qty.wrappedValue < quantityRange.upperBound) {
                qty.wrappedValue = min(quantityRange.upperBound, qty.wrappedValue + 1)
            }
        }
        .padding(.horizontal, 4)
        .background(theme.background(controlSurfaceKey), in: Capsule())
        .disabled(isReadOnly)   // E1 — read-only surfaces render but don't mutate
    }

    private func stepButton(_ icon: String, label: String, value: Int, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? accentSemantic.base : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityValue("\(value)")
    }

    private func addButton(_ added: Binding<Bool>) -> some View {
        let on = added.wrappedValue
        return Button { added.wrappedValue.toggle() } label: {
            HStack(spacing: 4) {
                Image(systemName: on ? "checkmark" : "plus").font(.system(size: 12, weight: .bold))
                Text(on ? addedTitle : addTitle).textStyle(.labelSm700)
            }
            .foregroundStyle(on ? accentSemantic.onSolid : accentSemantic.base)
            .padding(.horizontal, density.scale(Theme.SpacingKey.md.value))
            .frame(height: 36)
            .background(on ? accentSemantic.solid : accentSemantic.bg, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)   // E1 — read-only surfaces render but don't mutate
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AncillaryCard {
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    func image(_ url: URL?) -> Self { copy { $0.imageURL = url } }
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func price(_ amount: Decimal?, currencyCode: String = "USD", suffix: String? = nil) -> Self {
        copy { $0.price = amount; $0.currencyCode = currencyCode; $0.priceSuffix = suffix }
    }
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    /// Replicates every parameter except `currencyCode` so
    /// `price(450, suffix: "/ bag")` binds here, not the hardcoded default.
    func price(_ amount: Decimal?, suffix: String? = nil) -> Self {
        copy { $0.price = amount; $0.priceSuffix = suffix }
    }
    func badge(_ text: String?) -> Self { copy { $0.badgeText = text } }
    /// A title badge with an explicit `BadgeStyle` (the one-argument form keeps
    /// the classic `.info` styling).
    func badge(_ text: String?, style: BadgeStyle) -> Self { copy { $0.badgeText = text; $0.badgeStyle = style } }
    /// A quantity stepper bound to `binding` (controlled — mutually exclusive
    /// with ``added(_:title:addedTitle:)``).
    func quantity(_ binding: Binding<Int>, range: ClosedRange<Int> = 0...9) -> Self {
        copy {
            $0.showsQuantity = true
            $0._quantityState = ControllableState(wrappedValue: 0, external: binding)
            $0.quantityRange = range
        }
    }
    /// A self-managed quantity stepper (uncontrolled). Survives List *scrolling*
    /// (state-per-identity) but not identity churn — use ``quantity(_:range:)``
    /// when the count must persist.
    func quantity(range: ClosedRange<Int> = 0...9) -> Self {
        copy { $0.showsQuantity = true; $0.quantityRange = range }
    }
    /// An add/remove toggle bound to `binding` (controlled; English defaults, overridable).
    func added(_ binding: Binding<Bool>, title: String = String(themeKit: "Add"), addedTitle: String = String(themeKit: "Added")) -> Self {
        copy {
            $0.showsAdded = true
            $0._addedState = ControllableState(wrappedValue: false, external: binding)
            $0.addTitleOverride = title
            $0.addedTitleOverride = addedTitle
        }
    }
    /// A self-managed add/remove toggle (uncontrolled) — same identity caveat
    /// as ``quantity(range:)``.
    func added(title: String = String(themeKit: "Add"), addedTitle: String = String(themeKit: "Added")) -> Self {
        copy { $0.showsAdded = true; $0.addTitleOverride = title; $0.addedTitleOverride = addedTitle }
    }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Shell elevation, fed to the active `CardStyle` (default `.none` — today's
    /// flat, hairline-only chrome).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// Replaces the built-in icon tile / thumbnail.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.leadingSlot = AnyView(content()) } }
    /// Replaces the built-in stepper / add-button control area.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Surface token for the quantity stepper's capsule track (default
    /// `.bgSecondary`) — distinct from ``surface(_:)``, which fills the card shell.
    func controlSurface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.controlSurfaceKey = key } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var bags = 1
        @State private var insurance = false
        var body: some View {
            VStack(spacing: 10) {
                AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg").price(450, suffix: "/ bag").quantity($bags, range: 0...4)
                AncillaryCard("Travel insurance").icon("cross.case.fill").subtitle("Full coverage").price(120).badge("Popular").added($insurance)
                AncillaryCard("Extra legroom").icon("figure.seated.side").subtitle("Row 12").price(75).quantity($bags, range: 0...4)
                    .surface(.bgSecondaryLight)
                    .controlSurface(.bgWhite)
                // Uncontrolled stepper + toggle, styled badge, soft elevation.
                AncillaryCard("Sports equipment").icon("figure.skiing.downhill").price(300, suffix: "/ item")
                    .quantity(range: 0...2).badge("New", style: .warning).elevation(.soft)
                AncillaryCard("Fast track").icon("hare.fill").price(60)
                    .added(title: "Add", addedTitle: "In basket")
                // Leading + trailing slots replace the tile and the control.
                AncillaryCard("Lounge access").subtitle("3h stay")
                    .leading { Badge("VIP").badgeStyle(.purple).size(.small) }
                    .trailing { TextLink("View") { } }
                // Read-only: the stepper and toggle render but don't mutate.
                AncillaryCard("Checked baggage").icon("suitcase.fill").price(450).quantity($bags, range: 0...4)
                    .readOnly()
            }
            .padding()
        }
    }
    return Demo()
}

#Preview("Outlined style") {
    @Previewable @State var seat = true
    VStack(spacing: 10) {
        AncillaryCard("Seat selection").icon("carseat.left.fill").subtitle("Extra legroom").price(350).added($seat)
        AncillaryCard("Priority boarding").icon("figure.walk").price(90).added(.constant(false))
    }
    .cardStyle(.outlined)
    .padding()
}
