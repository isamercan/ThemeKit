//
//  PriceAlertCard.swift
//  ThemeKit
//
//  Organism. A "get price alerts" card — a bell icon, a title + subtitle, an optional
//  current price with a trend indicator, and a toggle bound to the caller. Token-bound.
//
//  The outer shell (surface fill, corner clipping, hairline border) is drawn by the
//  active `CardStyle` from the environment — `.surface()/.cornerRadius()/.elevation()`
//  feed the `CardStyleConfiguration`. The default `.none` elevation reproduces the
//  original shadow-free, hairline-bordered look, while `.cardStyle(_:)` can swap in
//  a completely different shell. The Toggle stays the card's single VoiceOver element.
//
//  ```swift
//  PriceAlertCard("Get price alerts", isOn: $alerts)
//      .subtitle("We'll email you when the price changes").price(3_538).trend(.down, "-8%")
//  ```
//

import SwiftUI

/// Direction of a ``PriceAlertCard`` trend indicator.
public enum PriceTrend: Sendable { case up, down, flat }

public struct PriceAlertCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let title: String
    @Binding private var isOn: Bool
    // Content/appearance — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var systemImage = "bell.fill"
    private var price: Decimal?
    private var currencyCode: String?
    private var trend: PriceTrend?
    private var trendText: String?
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .none

    public init(_ title: String, isOn: Binding<Bool>) {   // R1
        self.title = title
        self._isOn = isOn
    }

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }

    /// Explicit `price(_:currencyCode:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private var trendColor: Color {
        switch trend { case .down: theme.foreground(.systemcolorsFgSuccess); case .up: theme.foreground(.systemcolorsFgError); default: theme.text(.textSecondary) }
    }
    private var trendIcon: String {
        switch trend { case .down: "arrow.down.right"; case .up: "arrow.up.right"; default: "arrow.right" }
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — the default `.none` elevation yields the original hairline.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
    }

    /// The card's inner layout — everything inside the shell. The IconTile/text
    /// block stays `accessibilityHidden`; the labelled Toggle remains the card's
    /// one VoiceOver element.
    private var cardContent: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            IconTile(systemImage).size(44).accent(accentSemantic)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(2) }
                if price != nil || trend != nil { priceTrend }
            }
            .accessibilityHidden(true)
            Spacer(minLength: 6)
            // The Toggle is the card's one VoiceOver element (label = card texts) — a
            // `.combine` on the container would flatten it into a static element.
            Toggle("", isOn: $isOn).labelsHidden().tint(accentSemantic.base)
                .accessibilityLabel([title, subtitle].compactMap { $0 }.joined(separator: ", "))
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    private var priceTrend: some View {
        HStack(spacing: 6) {
            if let price { PriceTag(price, currencyCode: resolvedCurrency).size(.small).fractionDigits(0) }
            if trend != nil {
                HStack(spacing: 2) {
                    Image(systemName: trendIcon).font(.system(size: 10, weight: .bold))
                    if let trendText { Text(trendText).textStyle(.overline500) }
                }
                .foregroundStyle(trendColor)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceAlertCard {
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    func trend(_ direction: PriceTrend?, _ text: String? = nil) -> Self { copy { $0.trend = direction; $0.trendText = text } }
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Surface elevation (default `.none` — the original hairline-bordered look).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var on = true
        var body: some View {
            PriceAlertCard("Get price alerts", isOn: $on)
                .subtitle("We'll notify you when this route's price changes").price(3_538).trend(.down, "-8%").padding()
        }
    }
    return Demo()
}

#Preview("Outlined style") {
    struct Demo: View {
        @State private var on = false
        var body: some View {
            PriceAlertCard("Get price alerts", isOn: $on)
                .subtitle("We'll email you when the price changes")
                .cardStyle(.outlined)
                .padding()
        }
    }
    return Demo()
}
