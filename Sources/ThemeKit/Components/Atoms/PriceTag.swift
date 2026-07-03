//
//  PriceTag.swift
//  ThemeKit
//
//  A formatted price — currency, optional struck-through original, per-unit suffix
//  and an auto-computed discount badge. Token-bound; the emphasis colour comes from
//  the theme so it re-skins with the brand. Reused by FlightCard / FareSummary / RoomCard.
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

/// A token-bound price label.
///
/// ```swift
/// PriceTag(1_299, currencyCode: "TRY")
///     .original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()
/// ```
public struct PriceTag: View {
    @Environment(\.theme) private var theme

    private let amount: Decimal
    private let currencyCode: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var original: Decimal?
    private var unit: String?
    private var size: PriceSize = .medium
    private var emphasis: PriceEmphasis = .standard
    private var showsDiscountBadge: Bool = false
    private var fractionDigits: Int = 0

    public init(_ amount: Decimal, currencyCode: String = "TRY") {   // R1 — content
        self.amount = amount
        self.currencyCode = currencyCode
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            if let original, original > amount {
                Text(formatted(original))
                    .textStyle(size.originalStyle)
                    .strikethrough()
                    .foregroundStyle(theme.text(.textTertiary))
            }
            Text(formatted(amount))
                .textStyle(size.priceStyle)
                .foregroundStyle(emphasis.color(theme))
            if let unit {
                Text(unit)
                    .textStyle(size.unitStyle)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            if showsDiscountBadge, let percent = discountPercent {
                Badge("-\(percent)%").badgeStyle(.error).size(.small)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: currencyCode).precision(.fractionLength(fractionDigits)))
    }

    private var discountPercent: Int? {
        guard let original, original > 0, original > amount else { return nil }
        let ratio = (original - amount) / original
        return Int((ratio as NSDecimalNumber).doubleValue * 100 + 0.5)
    }

    private var accessibilityText: String {
        var parts = [formatted(amount)]
        if let unit { parts.append(unit) }
        if let percent = discountPercent { parts.append("\(percent)% off") }
        return parts.joined(separator: " ")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceTag {
    /// A struck-through original price shown before the current one (enables the discount badge maths).
    func original(_ amount: Decimal?) -> Self { copy { $0.original = amount } }
    /// A per-unit suffix, e.g. `"/ night"` or `"/ kişi"`.
    func unit(_ text: String?) -> Self { copy { $0.unit = text } }
    /// Size tier: small / medium / large / xlarge.
    func size(_ s: PriceSize) -> Self { copy { $0.size = s } }
    /// Colour emphasis of the headline price.
    func emphasis(_ e: PriceEmphasis) -> Self { copy { $0.emphasis = e } }
    /// Shows a `-%NN` badge computed from the original vs current price.
    func discountBadge(_ show: Bool = true) -> Self { copy { $0.showsDiscountBadge = show } }
    /// Decimal places to render (default 0 — travel prices are usually whole).
    func fractionDigits(_ n: Int) -> Self { copy { $0.fractionDigits = max(0, n) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        PriceTag(1_299).size(.small)
        PriceTag(1_299).original(1_899).unit("/ night").emphasis(.hero).discountBadge()
        PriceTag(2_499, currencyCode: "EUR").size(.large).emphasis(.hero)
        PriceTag(0).emphasis(.success)
    }
    .padding()
}
