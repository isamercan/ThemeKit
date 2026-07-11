//
//  PriceBreakdown.swift
//  ThemeKit
//
//  Molecule. The reusable "discount price" block — an optional note, a discount
//  badge + struck-through original, the price (with unit), and an optional
//  extra-discount line. Composed from ``PriceTag`` + ``Badge``. Shared by the hotel /
//  room / booking-bar / agent cards so a developer can drop the same block into any
//  layout. Token-bound.
//
//  ```swift
//  PriceBreakdown(190_960).note("2 rooms · 4 nights")
//      .original(248_000).discountBadge("-23%").extra("Extra 8%", 175_683)
//  ```
//

import SwiftUI

public struct PriceBreakdown: View {
    @Environment(\.theme) private var theme
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let amount: Decimal
    private let currencyCode: String?
    // Appearance/content — mutated only through the modifiers below (R2).
    private var originalPrice: Decimal?
    private var discountText: String?
    private var unit: String?
    private var note: String?
    private var extraLabel: String?
    private var extraAmount: Decimal?
    private var size: PriceSize = .large
    private var emphasis: PriceEmphasis = .standard
    private var align: HorizontalAlignment = .leading

    public init(_ amount: Decimal, currencyCode: String = "TRY") {   // R1
        self.amount = amount
        self.currencyCode = currencyCode
    }

    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD" (§10).
    public init(_ amount: Decimal) {   // R1
        self.amount = amount
        self.currencyCode = nil
    }

    /// Explicit `currencyCode:` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private func money(_ d: Decimal) -> String { d.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0))) }
    private var priceTag: PriceTag {
        var t = PriceTag(amount, currencyCode: resolvedCurrency).size(size).emphasis(emphasis).fractionDigits(0)
        if let unit { t = t.unit(unit) }
        return t
    }

    public var body: some View {
        VStack(alignment: align, spacing: 2) {
            if let note { Text(note).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)) }
            if discountText != nil || originalPrice != nil {
                HStack(spacing: 6) {
                    if let discountText { Badge(discountText).badgeStyle(.success).variant(.soft).size(.small) }
                    if let originalPrice { Text(money(originalPrice)).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)).strikethrough() }
                }
            }
            priceTag
            if let extraLabel, let extraAmount {
                HStack(spacing: 6) {
                    Text(extraLabel).textStyle(.overline500).foregroundStyle(theme.text(.textSecondary))
                    Text(money(extraAmount)).textStyle(.labelBase700).foregroundStyle(theme.foreground(.systemcolorsFgError))
                }
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceBreakdown {
    /// A struck-through original price (shown next to the discount badge).
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    /// A discount badge, e.g. "-23%".
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text } }
    /// A price unit, e.g. "/ night".
    func unit(_ text: String?) -> Self { copy { $0.unit = text } }
    /// A note above the price, e.g. "2 rooms · 4 nights".
    func note(_ text: String?) -> Self { copy { $0.note = text } }
    /// An extra-discount line under the price (shown in error colour).
    func extra(_ label: String, _ amount: Decimal) -> Self { copy { $0.extraLabel = label; $0.extraAmount = amount } }
    /// Size of the main price (default `.large`).
    func size(_ size: PriceSize) -> Self { copy { $0.size = size } }
    /// Emphasis of the main price (default `.standard`).
    func emphasis(_ e: PriceEmphasis) -> Self { copy { $0.emphasis = e } }
    /// Horizontal alignment of the stack (default `.leading`).
    func align(_ alignment: HorizontalAlignment) -> Self { copy { $0.align = alignment } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PriceBreakdown(190_960).note("2 rooms · 4 nights").original(248_000).discountBadge("-23%").extra("Extra 8%", 175_683)
        PriceBreakdown(9_600).unit("/ night").size(.medium).original(12_000).discountBadge("-20%")
        PriceBreakdown(3_538).size(.medium).emphasis(.hero).align(.trailing).original(4_100)
    }
    .padding()
}
