//
//  StickyBookingBar.swift
//  ThemeKit
//
//  Organism. The sticky bottom price + CTA bar for a detail / checkout screen —
//  a price block (note, struck-through original, discount badge, price) on the
//  left and a primary action on the right. Token-bound; pin it with
//  `.safeAreaInset(edge: .bottom) { StickyBookingBar(…) }`.
//
//  ```swift
//  StickyBookingBar("Book now") { checkout() }
//      .price(9_600).original(12_000).discountBadge("-20%").note("2 rooms · 4 nights")
//  ```
//

import SwiftUI

public struct StickyBookingBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let ctaTitle: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var price: Decimal?
    private var currencyCode = "TRY"
    private var originalPrice: Decimal?
    private var note: String?
    private var discountText: String?
    private var ctaIcon: String?
    private var isEnabled = true
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var showsShadow = true
    private var leadingSlot: AnyView?

    public init(_ ctaTitle: String, action: @escaping () -> Void) {   // R1
        self.ctaTitle = ctaTitle
        self.action = action
    }

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    public var body: some View {
        HStack(alignment: .center, spacing: density.scale(Theme.SpacingKey.md.value)) {
            if let leadingSlot {
                leadingSlot
            } else {
                priceBlock
            }
            Spacer(minLength: 8)
            button
        }
        .padding(.horizontal, density.scale(Theme.SpacingKey.md.value))
        .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
        .frame(maxWidth: .infinity)
        .background(theme.background(surfaceKey))
        .overlay(alignment: .top) { Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1) }
        .modifier(BarShadow(on: showsShadow))
    }

    @ViewBuilder private var priceBlock: some View {
        if let priceBreakdown { priceBreakdown }
    }
    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: currencyCode).size(.large).emphasis(.hero)
        if let note { b = b.note(note) }
        if let originalPrice { b = b.original(originalPrice) }
        if let discountText { b = b.discountBadge(discountText) }
        return b
    }

    private var button: some View {
        themeButton.disabled(!isEnabled)
    }
    private var themeButton: ThemeButton {
        var b = ThemeButton(ctaTitle) { action() }.color(accentSemantic).size(.large)
        if let ctaIcon { b = b.icon(trailing: ctaIcon) }
        return b
    }
}

private struct BarShadow: ViewModifier {
    let on: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if on { content.themeShadow(.tabBar) } else { content }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension StickyBookingBar {
    func price(_ amount: Decimal?, currencyCode: String = "TRY") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    func note(_ text: String?) -> Self { copy { $0.note = text } }
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text } }
    func ctaIcon(_ systemName: String?) -> Self { copy { $0.ctaIcon = systemName } }
    func enabled(_ on: Bool) -> Self { copy { $0.isEnabled = on } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func showsShadow(_ on: Bool) -> Self { copy { $0.showsShadow = on } }
    /// Replace the left price block with fully custom content.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.leadingSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack {
        Spacer()
        StickyBookingBar("Book now") { }
            .note("2 rooms · 4 nights").original(12_000).discountBadge("-20%").price(9_600).ctaIcon("arrow.right")
    }
}
