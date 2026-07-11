//
//  AgentPriceRow.swift
//  ThemeKit
//
//  Organism. A meta-search booking option — a provider (agent/airline) logo or
//  name, an optional rating and badge, an optional self-transfer / info warning,
//  a price (with struck-through original) and a "go to site" CTA. Token-bound; the
//  core row of a flight-details booking list. Every part is a modifier.
//
//  ```swift
//  AgentPriceRow("Trip.com") { open() }.logo(url).rating(4.2)
//      .badge("Cheapest").original(4_100).price(3_538).cta("Go to site")
//  ```
//

import SwiftUI

public struct AgentPriceRow: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let provider: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var logoURL: URL?
    private var systemImage = "building.2.fill"
    private var subtitle: String?
    private var rating: Double?
    private var badgeText: String?
    private var badgeStyle: BadgeStyle = .success
    private var warningText: String?
    private var price: Decimal?
    private var currencyCode: String?
    private var originalPrice: Decimal?
    private var ctaTitle = String(themeKit: "Select")
    private var recommended = false
    private var accent: SemanticColor?
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var radiusRole: Theme.RadiusRole = .box

    public init(_ provider: String, action: @escaping () -> Void = {}) {   // R1
        self.provider = provider
        self.action = action
    }

    @Environment(\.componentDefaults) private var defaults
    private var accentSemantic: SemanticColor { accent ?? defaults.accent ?? .primary }
    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }

    /// Explicit `price(_:currencyCode:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            HStack(alignment: .center, spacing: density.scale(Theme.SpacingKey.sm.value)) {
                logo
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(provider).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                        if let badgeText { Badge(badgeText).badgeStyle(badgeStyle).variant(.soft).size(.small).fixedSize() }
                    }
                    if let rating {
                        HStack(spacing: 3) {
                            Image(systemName: "star.fill").font(.system(size: 10)).foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                                .accessibilityHidden(true)   // decorative; the value carries the meaning
                            Text(rating.formatted(.number.precision(.fractionLength(1)).locale(locale)))
                                .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                        }
                    }
                    if let subtitle { Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1) }
                }
                .layoutPriority(1)
                Spacer(minLength: 8)
                priceColumn
            }
            if let warningText { warningView(warningText) }
            ThemeButton(ctaTitle) { action() }.color(accentSemantic).size(.medium).fullWidth()
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
        .background(theme.background(surfaceKey), in: shape)
        .overlay(shape.stroke(recommended ? accentSemantic.base : theme.border(.borderPrimary), lineWidth: recommended ? 1.5 : 1))
        .contentShape(shape)
    }

    @ViewBuilder private var logo: some View {
        if let logoURL {
            RemoteImage(logoURL).contentMode(.fit).frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        } else {
            IconTile(systemImage).size(44)
        }
    }

    @ViewBuilder private var priceColumn: some View {
        if let priceBreakdown { priceBreakdown.fixedSize() }
    }
    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: resolvedCurrency).size(.medium).emphasis(.hero).align(.trailing)
        if let originalPrice { b = b.original(originalPrice) }
        return b
    }

    private func warningView(_ text: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11)).foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                .accessibilityHidden(true)   // decorative; the warning text carries the meaning
            Text(text).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
            Spacer()
        }
        .padding(density.scale(Theme.SpacingKey.sm.value))
        .background(theme.background(.systemcolorsBgWarningLight), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AgentPriceRow {
    func logo(_ url: URL?) -> Self { copy { $0.logoURL = url } }
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }
    func badge(_ text: String?, style: BadgeStyle = .success) -> Self { copy { $0.badgeText = text; $0.badgeStyle = style } }
    func warning(_ text: String?) -> Self { copy { $0.warningText = text } }
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    func cta(_ title: String) -> Self { copy { $0.ctaTitle = title } }
    func recommended(_ on: Bool = true) -> Self { copy { $0.recommended = on } }
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
    PreviewMatrix("AgentPriceRow") {
        PreviewCase("Recommended + badge + original") {
            AgentPriceRow("Trip.com") { }.rating(4.2).badge("Cheapest").original(4_100).price(3_538).cta("Go to site").recommended()
        }
        PreviewCase("Warning") {
            AgentPriceRow("Kiwi.com") { }.rating(3.8).warning("Self-transfer — you handle the connection").price(3_612).cta("Go to site")
        }
        PreviewCase("Minimal") {
            AgentPriceRow("Provider") { }.price(2_990)
        }
    }
}
