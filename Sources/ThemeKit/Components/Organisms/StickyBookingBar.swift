//
//  StickyBookingBar.swift
//  ThemeKit
//
//  Organism. The sticky bottom price + CTA bar for a detail / checkout screen —
//  a price block (note, struck-through original, discount badge, price) on the
//  left and a primary action on the right. Token-bound; pin it with
//  `.safeAreaInset(edge: .bottom) { StickyBookingBar(…) }`.
//
//  Chrome is style-driven: set a ``BarStyle`` with `.barStyle(_:)` and the bar
//  hands its price + CTA row to the style as a `.bottom`-edge
//  ``BarStyleConfiguration`` (`surface(_:)` / `showsShadow(_:)` still win over
//  the style's own fill/shadow). With no style set, the original chrome — flat
//  fill, top hairline overlay, tab-bar shadow — renders pixel-identically
//  (that shadowed chrome cannot be produced by the stock `DefaultBarStyle`,
//  so the untouched default keeps the legacy look).
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
    @Environment(\.barStyle) private var barStyle

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
    /// `nil` = the active `BarStyle` picks its own fill (both the legacy chrome
    /// and the default style use `.bgWhite`); set via `surface(_:)`.
    private var surfaceOverride: Theme.BackgroundColorKey?
    /// `nil` = unset — legacy chrome shows its tab-bar shadow, a custom style
    /// keeps its own shadow; set via `showsShadow(_:)`, which wins over both.
    private var showsShadowOverride: Bool?
    private var leadingSlot: AnyView?

    public init(_ ctaTitle: String, action: @escaping () -> Void) {   // R1
        self.ctaTitle = ctaTitle
        self.action = action
    }

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    public var body: some View {
        if barStyle.isDefault {
            // No `.barStyle(_:)` set — the original flat fill + top hairline
            // overlay + tab-bar shadow.
            row
                .background(theme.background(surfaceOverride ?? .bgWhite))
                .overlay(alignment: .top) { Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1) }
                .modifier(BarShadow(on: showsShadowOverride ?? true))
        } else {
            // The whole price + CTA row is the configuration's content — both
            // blocks are far wider than the 44pt accessory slots the built-in
            // styles overlay, so neither maps to leading/trailing.
            barStyle.makeBody(configuration: BarStyleConfiguration(leading: nil,
                                                                   content: AnyView(row),
                                                                   trailing: nil,
                                                                   edge: .bottom))
                .environment(\.barChromeOverrides,
                             BarChromeOverrides(surface: surfaceOverride,
                                                showsShadow: showsShadowOverride))
        }
    }

    private var row: some View {
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
    /// Surface fill (background token key). Wins over the fill the active
    /// `BarStyle` would draw; when unset, the style picks its own (`.bgWhite`
    /// for both the legacy chrome and the built-in styles).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceOverride = key } }
    /// Show the bar's shadow (default on). Wins over the shadow the active
    /// `BarStyle` would draw — `false` also suppresses a custom style's shadow.
    func showsShadow(_ on: Bool) -> Self { copy { $0.showsShadowOverride = on } }
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
        StickyBookingBar("Book now") { }
            .note("BarStyle demo").price(9_600)
            .barStyle(.floating)
            .padding(.top, 24)
    }
}
