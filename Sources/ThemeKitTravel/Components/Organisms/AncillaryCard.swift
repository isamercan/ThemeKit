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
//  The *arrangement* is owned by the active ``AncillaryCardStyle`` from the
//  environment (ADR-0004): the component gathers its typed data — plus the
//  quantity/added control as pre-wired state + closures — into an
//  ``AncillaryCardConfiguration`` and hands it to the style. `.row` (default) is
//  today's card verbatim; `.tile` and `.banner` swap the whole layout, and apps
//  can implement their own. Every built-in is card-shaped, so it keeps drawing
//  the outer shell (surface fill, corner clipping, border, elevation shadow)
//  through the active `CardStyle` — `.surface()/.cornerRadius()` and the
//  added/quantity "active" state (as `isSelected`) feed the
//  `CardStyleConfiguration`, so `.cardStyle(_:)` still swaps the chrome
//  independently of `.ancillaryCardStyle(_:)`.
//

import SwiftUI
import ThemeKit

public struct AncillaryCard: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.ancillaryCardStyle) private var style
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
    /// `nil` → the active ``AncillaryCardStyle``'s own default (`.row` uses `.bgBase`).
    private var surfaceKey: Theme.BackgroundColorKey?
    /// `nil` → the active style's own default (`.row`/`.tile` use `.bgSecondary`).
    private var controlSurfaceKey: Theme.BackgroundColorKey?
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .none
    private var leadingSlot: AnyView?
    private var trailingSlot: AnyView?

    public init(_ title: String) { self.title = title }   // R1

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The arrangement is owned by the active `AncillaryCardStyle`; the
        // quantity/added `@ControllableState` storage stays *here* (ADR-F4) —
        // styles only see the current value + a typed step/toggle closure, so
        // the interaction logic (clamping, toggling) is never re-implemented
        // per style.
        let configuration = AncillaryCardConfiguration(
            title: title,
            systemImage: systemImage,
            imageURL: imageURL,
            subtitle: subtitle,
            priceAmount: price,
            currencyCode: resolvedCurrency,
            priceSuffix: priceSuffix,
            badgeText: badgeText,
            badgeStyle: badgeStyle,
            showsQuantity: showsQuantity,
            quantity: quantityState,
            quantityRange: quantityRange,
            setQuantity: showsQuantity ? { quantityState = $0 } : nil,
            showsAdded: showsAdded,
            isAdded: addedState,
            toggleAdded: showsAdded ? { addedState.toggle() } : nil,
            addTitle: addTitle,
            addedTitle: addedTitle,
            leading: leadingSlot,
            trailing: trailingSlot,
            accent: accent,
            surfaceKey: surfaceKey,
            controlSurfaceKey: controlSurfaceKey,
            radiusRole: radiusRole,
            elevation: elevation,
            density: density,
            locale: locale)
        style.makeBody(configuration: configuration)
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
                AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg")
                    .price(450, suffix: "/ bag").quantity($bags, range: 0...4)
                AncillaryCard("Travel insurance").icon("cross.case.fill").subtitle("Full coverage")
                    .price(120).badge("Popular").added($insurance)
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
