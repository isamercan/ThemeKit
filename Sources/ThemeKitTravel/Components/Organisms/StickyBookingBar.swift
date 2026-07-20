//
//  StickyBookingBar.swift
//  ThemeKit
//
//  Organism. The sticky bottom price + CTA bar for a detail / checkout screen —
//  a price block (note, struck-through original, discount badge, price) on the
//  left and a primary action on the right. Token-bound; pin it with
//  `.safeAreaInset(edge: .bottom) { StickyBookingBar(…) }`.
//
//  Two independent style axes (ADR-0004 §6):
//  - **Content** — set a ``StickyBookingBarStyle`` with `.stickyBookingBarStyle(_:)`
//    to rearrange the price block / CTA / secondary-CTA units (`.standard`
//    default, `.stacked`, `.split`, or a custom style). The component still
//    owns every live control (the CTA's action/`.enabled`/`.loading`, the
//    price-tap disclosure, the secondary action) — styles arrange the
//    pre-wired units, never re-wire them (`StickyBookingBarStyle.swift`).
//  - **Chrome** — set a ``BarStyle`` with `.barStyle(_:)` and the bar hands its
//    arranged content to the style as a `.bottom`-edge ``BarStyleConfiguration``
//    (`surface(_:)` / `showsShadow(_:)` still win over the style's own
//    fill/shadow). With no `BarStyle` set, the original chrome — flat fill,
//    top hairline overlay, tab-bar shadow — renders pixel-identically (that
//    shadowed chrome cannot be produced by the stock `DefaultBarStyle`, so the
//    untouched default keeps the legacy look).
//
//  ```swift
//  StickyBookingBar("Book now") { checkout() }
//      .price(9_600).original(12_000).discountBadge("-20%").note("2 rooms · 4 nights")
//      .stickyBookingBarStyle(.stacked)
//  ```
//

import SwiftUI
import ThemeKit

public struct StickyBookingBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.barStyle) private var barStyle
    @Environment(\.stickyBookingBarStyle) private var style
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.controlSize) private var controlSize   // R3 — native size axis

    private let ctaTitle: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var price: Decimal?
    private var currencyCode: String?
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
    private var trailingSlot: AnyView?
    private var secondaryTitle: String?
    private var onSecondary: (() -> Void)?
    private var onPriceTapAction: (() -> Void)?
    private var isLoading = false

    public init(_ ctaTitle: String, action: @escaping () -> Void) {   // R1
        self.ctaTitle = ctaTitle
        self.action = action
    }

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.themeKitCurrencyCode ?? "USD"
    }

    public var body: some View {
        let arranged = style.makeBody(configuration: configuration)
        if barStyle.isDefault {
            // No `.barStyle(_:)` set — the original flat fill + top hairline
            // overlay + tab-bar shadow.
            arranged
                .background(theme.background(surfaceOverride ?? .bgWhite))
                .overlay(alignment: .top) { Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1) }
                .modifier(BarShadow(on: showsShadowOverride ?? true))
        } else {
            // The active `StickyBookingBarStyle`'s arranged content is the
            // configuration's content — both blocks are far wider than the
            // 44pt accessory slots the built-in `BarStyle`s overlay, so
            // neither maps to leading/trailing.
            barStyle.makeBody(configuration: BarStyleConfiguration(leading: nil,
                                                                   content: arranged,
                                                                   trailing: nil,
                                                                   edge: .bottom))
                .environment(\.barChromeOverrides,
                             BarChromeOverrides(surface: surfaceOverride,
                                                showsShadow: showsShadowOverride))
        }
    }

    /// The pre-wired units + typed signals handed to the active
    /// ``StickyBookingBarStyle`` (ADR-0004, Class B) — this component keeps
    /// every live control (action, `.enabled`, `.loading`, price-tap); styles
    /// only arrange the units below, never re-wire them.
    private var configuration: StickyBookingBarConfiguration {
        StickyBookingBarConfiguration(
            // `priceBlockContent` also renders a chevron-only tap target when
            // `.onPriceTap(_:)` is set without a price — nil out only when
            // there is truly nothing to show (matches the pre-style render).
            priceBlock: (price == nil && onPriceTapAction == nil) ? nil : AnyView(priceBlockContent),
            cta: AnyView(ctaButton),
            secondaryCta: secondaryCtaUnit,
            leading: leadingSlot,
            trailing: trailingSlot,
            hasPrice: price != nil,
            discountBadge: discountText,
            isEnabled: isEnabled,
            isLoading: isLoading,
            accent: accent,
            surfaceKey: surfaceOverride,
            density: density,
            locale: locale)
    }

    @ViewBuilder private var priceBlockContent: some View {
        if let onPriceTapAction {
            Button { onPriceTapAction() } label: {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let priceBreakdown { priceBreakdown }
                    Image(systemName: "chevron.up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(theme.text(.textSecondary))
                        .accessibilityHidden(true)   // decorative disclosure glyph
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Price details"))
        } else if let priceBreakdown {
            priceBreakdown
        }
    }
    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: resolvedCurrency).size(.large).emphasis(.hero)
        if let note { b = b.note(note) }
        if let originalPrice { b = b.original(originalPrice) }
        if let discountText { b = b.discountBadge(discountText) }
        return b
    }

    /// The outline secondary action beside the CTA (`.secondaryAction(_:action:)`),
    /// or `nil` when unset. `.fullWidth()`-capable so `.stacked`/`.split`
    /// styles can stretch it; `.standard` restores its intrinsic footprint
    /// with `.fixedSize(horizontal:vertical:)` (see `StickyBookingBarStyle`).
    private var secondaryCtaUnit: AnyView? {
        guard let secondaryTitle, let onSecondary else { return nil }
        return AnyView(
            ThemeButton(secondaryTitle) { onSecondary() }
                .color(accentSemantic).variant(.outline).size(ctaSize).fullWidth()
                .disabled(!isEnabled)
        )
    }

    /// The primary CTA, `.fullWidth()`-capable for the same reason as
    /// ``secondaryCtaUnit``.
    private var ctaButton: some View {
        themeButton.fullWidth().disabled(!isEnabled)
    }
    private var themeButton: ThemeButton {
        var b = ThemeButton(ctaTitle) { action() }.color(accentSemantic).size(ctaSize).loading(isLoading)
        if let ctaIcon { b = b.icon(trailing: ctaIcon) }
        return b
    }

    /// Native `.controlSize(_:)` → the CTA's `ButtonSize`. The environment
    /// default (`.regular`) keeps the bar's classic `.large` footprint; set
    /// `.controlSize(.small)` / `.mini` on the bar to compact both buttons.
    private var ctaSize: ButtonSize {
        switch controlSize {
        case .mini: return .xxsmall
        case .small: return .small
        case .regular, .large, .extraLarge: return .large
        @unknown default: return .large
        }
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
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
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
    /// Replace the CTA area with fully custom content (partner to ``leading(_:)``).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }
    /// An outline secondary action beside the primary CTA (e.g. "Hold fare").
    func secondaryAction(_ title: String, action: @escaping () -> Void) -> Self {
        copy { $0.secondaryTitle = title; $0.onSecondary = action }
    }
    /// Makes the price block tappable (adds a disclosure chevron) — open a
    /// fare-breakdown sheet from the bar.
    func onPriceTap(_ action: @escaping () -> Void) -> Self { copy { $0.onPriceTapAction = action } }
    /// Show the CTA's loading spinner and block taps while `on` (forwarded to
    /// `ThemeButton.loading(_:)`).
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 20) {
            StickyBookingBar("Book now") { }
                .note("2 rooms · 4 nights").original(12_000).discountBadge("-20%").price(9_600).ctaIcon("arrow.right")
            StickyBookingBar("Book now") { }
                .note("BarStyle demo").price(9_600)
                .barStyle(.floating)
            // Tappable price (chevron) + outline secondary action.
            StickyBookingBar("Continue") { }
                .price(4_320).note("2 travellers")
                .onPriceTap { }
                .secondaryAction("Hold fare") { }
            // Loading CTA blocks taps; spinner replaces the label.
            StickyBookingBar("Booking…") { }
                .price(9_600).loading()
            // Native controlSize compacts both buttons.
            StickyBookingBar("Book") { }
                .price(9_600).secondaryAction("Hold") { }
                .controlSize(.small)
            // Trailing slot replaces the CTA area entirely.
            StickyBookingBar("Unused") { }
                .price(2_150)
                .trailing {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ThemeButton { }.icon(leading: "heart").variant(.soft).shape(.circle)
                        ThemeButton("Reserve") { }.size(.small)
                    }
                }
        }
        .padding(.vertical, 24)
    }
}
