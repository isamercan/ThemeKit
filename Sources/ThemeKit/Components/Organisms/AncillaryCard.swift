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
    private var quantity: Binding<Int>?
    private var quantityRange: ClosedRange<Int> = 0...9
    private var added: Binding<Bool>?
    private var addTitle = "Add"
    private var addedTitle = "Added"
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var radiusRole: Theme.RadiusRole = .box

    public init(_ title: String) { self.title = title }   // R1

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }
    private var isActive: Bool { (added?.wrappedValue ?? false) || ((quantity?.wrappedValue ?? 0) > 0) }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate. The
        // added/quantity "active" state feeds `isSelected`, so the selected border is
        // the style's to draw (the default style uses the hero border token). `.none`
        // elevation reproduces today's flat look: a 1pt hairline border, no shadow.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: .none,
            isSelected: isActive,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
            .contentShape(shape)
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            leading
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let badgeText { Badge(badgeText).badgeStyle(.info).variant(.soft).size(.small).fixedSize() }
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
        if let imageURL {
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

    @ViewBuilder private var control: some View {
        if let quantity {
            stepper(quantity)
        } else if let added {
            addButton(added)
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
        .background(theme.background(.bgSecondary), in: Capsule())
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
        .accessibilityLabel(title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AncillaryCard {
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    func image(_ url: URL?) -> Self { copy { $0.imageURL = url } }
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func price(_ amount: Decimal?, currencyCode: String = "TRY", suffix: String? = nil) -> Self {
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
    /// A quantity stepper bound to `binding` (mutually exclusive with ``added(_:)``).
    func quantity(_ binding: Binding<Int>, range: ClosedRange<Int> = 0...9) -> Self { copy { $0.quantity = binding; $0.quantityRange = range } }
    /// An add/remove toggle bound to `binding` (English defaults, overridable).
    func added(_ binding: Binding<Bool>, title: String = "Add", addedTitle: String = "Added") -> Self { copy { $0.added = binding; $0.addTitle = title; $0.addedTitle = addedTitle } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
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
