//
//  PriceTag.swift
//  ThemeKit
//
//  A formatted price — currency, optional struck-through original, per-unit suffix
//  and an auto-computed discount badge. Token-bound; the emphasis colour comes from
//  the theme so it re-skins with the brand. Reused by FlightCard / FareSummary / RoomCard.
//
//  Flexible: value semantics (.free / .soldOut / .from), a numeric-text animation on
//  change (reduce-motion aware), a trailing slot, density-aware spacing, and it honours
//  `.redacted(.placeholder)` for skeleton loading for free.
//

import SwiftUI

public enum PriceSize {
    case small, medium, large, xlarge

    var priceStyle: TextStyle {
        switch self {
        case .small: return .labelBase600
        case .medium: return .heading3xs
        case .large: return .headingXs
        case .xlarge: return .headingSm
        }
    }
    var originalStyle: TextStyle {
        switch self {
        case .small, .medium: return .bodySm400
        case .large, .xlarge: return .bodyBase400
        }
    }
    var unitStyle: TextStyle {
        switch self {
        case .small, .medium: return .bodySm400
        case .large, .xlarge: return .bodyBase400
        }
    }
}

public enum PriceEmphasis {
    /// Primary text colour — the default.
    case standard
    /// The brand accent — draws the eye to the headline price.
    case hero
    /// Success/green — a saving or a "free".
    case success
    /// Muted/secondary — a struck or secondary price.
    case muted

    func color(_ theme: Theme) -> Color {
        switch self {
        case .standard: return theme.text(.textPrimary)
        case .hero: return theme.foreground(.fgHero)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .muted: return theme.text(.textTertiary)
        }
    }
}

/// What the tag represents — a number, a free offer, or an unavailable fare.
public enum PriceState: Sendable { case priced, free, soldOut }

/// A token-bound price label.
///
/// ```swift
/// PriceTag(1_299, currencyCode: "USD")
///     .original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()
/// PriceTag(0).free()                       // "Free"
/// PriceTag(2_499).from().animatesValue()   // "from ₺2.499", rolls on change
/// ```
public struct PriceTag: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let amount: Decimal
    private let currencyCode: String?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var original: Decimal?
    private var originalBelow = false
    private var unit: String?
    private var size: PriceSize = .medium
    private var emphasis: PriceEmphasis = .standard
    private var showsDiscountBadge: Bool = false
    private var fractionDigits: Int = 0
    private var state: PriceState = .priced
    private var prefixText: String?
    private var animatesValue: Bool = false
    private var trailingSlot: AnyView?

    public init(_ amount: Decimal, currencyCode: String = "USD") {   // R1 — content
        self.amount = amount
        self.currencyCode = currencyCode
    }

    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    public init(_ amount: Decimal) {   // R1 — content
        self.amount = amount
        self.currencyCode = nil
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if let prefixText {
                Text(prefixText).textStyle(size.unitStyle).foregroundStyle(theme.text(.textSecondary))
            }
            switch state {
            case .priced: pricedContent
            case .free:
                Text(String(themeKit: "Free")).textStyle(size.priceStyle).foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            case .soldOut:
                Text(String(themeKit: "Sold out")).textStyle(size.priceStyle).foregroundStyle(theme.text(.textTertiary))
            }
            if let trailingSlot { trailingSlot }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var pricedContent: some View {
        if originalBelow, let original, original > amount {
            // Design-system stacked form: amount over the struck compare-at price.
            VStack(alignment: .trailing, spacing: 0) {
                amountText
                Text(formatted(original))
                    .textStyle(size.originalStyle)
                    .strikethrough()
                    .foregroundStyle(theme.text(.textTertiary))
            }
        } else {
            if let original, original > amount {
                Text(formatted(original))
                    .textStyle(size.originalStyle)
                    .strikethrough()
                    .foregroundStyle(theme.text(.textTertiary))
            }
            amountText
        }
        if let unit {
            Text(unit)
                .textStyle(size.unitStyle)
                .foregroundStyle(theme.text(.textSecondary))
        }
        if showsDiscountBadge, let percent = discountPercent {
            Badge("-\(percent)%").badgeStyle(.error).size(.small)
        }
    }

    private var amountText: some View {
        Text(formatted(amount))
            .textStyle(size.priceStyle)
            .foregroundStyle(emphasis.color(theme))
            .numericTextTransitionCompat(animatesValue && !reduceMotion,
                                         value: (amount as NSDecimalNumber).doubleValue)
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(fractionDigits)).locale(locale))
    }

    private var discountPercent: Int? { Self.discountPercent(original: original, amount: amount) }

    /// Rounded discount percentage from an original vs current price (pure; unit-tested).
    static func discountPercent(original: Decimal?, amount: Decimal) -> Int? {
        guard let original, original > 0, original > amount else { return nil }
        let ratio = (original - amount) / original
        return Int((ratio as NSDecimalNumber).doubleValue * 100 + 0.5)
    }

    private var accessibilityText: String {
        switch state {
        case .free: return String(themeKit: "Free")
        case .soldOut: return String(themeKit: "Sold out")
        case .priced:
            var parts: [String] = []
            if let prefixText { parts.append(prefixText) }
            parts.append(formatted(amount))
            if let unit { parts.append(unit) }
            if let percent = discountPercent { parts.append(String(themeKit: "\(percent)% off")) }
            return parts.joined(separator: " ")
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceTag {
    /// A struck-through original price shown before the current one (enables the discount badge maths).
    func original(_ amount: Decimal?) -> Self { copy { $0.original = amount } }
    /// Stacks the struck compare-at price *below* the amount (design-system
    /// vertical form) instead of inline before it.
    func originalBelow(_ on: Bool = true) -> Self { copy { $0.originalBelow = on } }
    /// A per-unit suffix, e.g. `"/ night"` or `"/ person"`.
    func unit(_ text: String?) -> Self { copy { $0.unit = text } }
    /// Size tier: small / medium / large / xlarge.
    func size(_ s: PriceSize) -> Self { copy { $0.size = s } }
    /// Colour emphasis of the headline price.
    func emphasis(_ e: PriceEmphasis) -> Self { copy { $0.emphasis = e } }
    /// Shows a `-NN%` badge computed from the original vs current price.
    func discountBadge(_ show: Bool = true) -> Self { copy { $0.showsDiscountBadge = show } }
    /// Decimal places to render (default 0 — travel prices are usually whole).
    func fractionDigits(_ n: Int) -> Self { copy { $0.fractionDigits = max(0, n) } }
    /// Renders "Free" instead of the amount.
    func free() -> Self { copy { $0.state = .free } }
    /// Renders "Sold out" instead of the amount.
    func soldOut() -> Self { copy { $0.state = .soldOut } }
    /// Prefixes the price, e.g. "from ₺1.299".
    func prefix(_ text: String) -> Self { copy { $0.prefixText = text } }
    /// Shorthand for `.prefix("from")` — a "lead-in" price.
    func from() -> Self { copy { $0.prefixText = String(themeKit: "from") } }
    /// Animates digit changes (numeric-text transition); no-op under Reduce Motion.
    /// Wrap the value change in `withAnimation` at the call site to drive it.
    func animatesValue(_ on: Bool = true) -> Self { copy { $0.animatesValue = on } }
    /// A trailing slot after the price (a badge, a chevron, a note).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("PriceTag") {
        PreviewCase("Small") { PriceTag(1_299).size(.small) }
        PreviewCase("Discount") { PriceTag(1_299).original(1_899).unit("/ night").emphasis(.hero).discountBadge() }
        PreviewCase("From") { PriceTag(2_499, currencyCode: "EUR").size(.large).emphasis(.hero).from() }
        PreviewCase("Free") { PriceTag(0).free() }
        PreviewCase("Sold out") { PriceTag(1_299).soldOut() }
        PreviewCase("Trailing badge") { PriceTag(3_499).trailing { Badge("Refundable").badgeStyle(.success).size(.small) } }
    }
}
