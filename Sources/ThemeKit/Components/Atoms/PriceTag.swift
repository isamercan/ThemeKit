//
//  PriceTag.swift
//  ThemeKit
//
//  A formatted price — currency, optional struck-through original, per-unit suffix
//  and an auto-computed discount badge. Token-bound; the emphasis colour comes from
//  the theme so it re-skins with the brand. Reused by FlightCard / FareSummary / RoomCard.
//
//  Flexible: value semantics (.free / .soldOut / .from), a numeric-text animation on
//  change (reduce-motion aware), leading/trailing slots, density-aware spacing, and it
//  honours `.redacted(.placeholder)` for skeleton loading for free.
//
//  Host-owned text: `PriceTag(verbatim:)` shows a price the host already formatted,
//  `original(verbatim:)` and `discountBadge(_: String?)` take the struck price and the
//  offer as host strings. The chrome is a `PriceTagStyle` (`PriceTagStyle.swift`) —
//  with no style set, the tag draws its own body below.
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
/// PriceTag(verbatim: "EUR 1.299")          // the host's own formatting, shown as-is
///     .original(verbatim: "EUR 1.899").discountBadge("-15%")
/// ```
///
/// Its chrome is a ``PriceTagStyle``: set one with `.priceTagStyle(_:)` to draw
/// the same content your own way. With none set, the tag draws the body below.
public struct PriceTag: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.priceTagStyle) private var style

    private let amount: Decimal
    private let currencyCode: String?
    /// The host's own price text (`init(verbatim:)`); non-nil switches every
    /// bit of formatting and discount maths off.
    private var verbatimPrice: String?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var original: Decimal?
    private var originalText: String?
    private var originalBelow = false
    private var unit: String?
    private var size: PriceSize = .medium
    private var emphasis: PriceEmphasis = .standard
    private var showsDiscountBadge: Bool = false
    private var discountText: String?
    private var fractionDigits: Int = 0
    private var state: PriceState = .priced
    private var prefixText: String?
    private var animatesValue: Bool = false
    private var leadingSlot: AnyView?
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

    /// A price the host already formatted, shown exactly as given — e.g.
    /// `"EUR 1.299"`. The tag never formats it and does no discount maths: pass
    /// the struck price with `original(verbatim:)` and the offer with
    /// `discountBadge(_: String?)` (a numeric `original(_:)` is ignored here).
    /// `animatesValue()` rolls the text without a numeric direction.
    public init(verbatim price: String) {   // R1 — content
        self.amount = 0
        self.currencyCode = nil
        self.verbatimPrice = price
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.themeKitCurrencyCode ?? "USD"
    }

    public var body: some View {
        if style.isDefault {
            HStack(alignment: .firstTextBaseline, spacing: density.scale(Theme.SpacingKey.xs.value)) {
                if let leadingSlot { leadingSlot }
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
        } else {
            // A style draws; the tag keeps the single VoiceOver element + label.
            let configuration = styleConfiguration
            style.makeBody(configuration: configuration)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(configuration.accessibilityLabel)
        }
    }

    @ViewBuilder private var pricedContent: some View {
        if originalBelow, let shownOriginal {
            // Design-system stacked form: amount over the struck compare-at price.
            VStack(alignment: .trailing, spacing: 0) {
                amountText
                Text(shownOriginal)
                    .strikethrough()   // Text-level: before .textStyle (View form is iOS 16+)
                    .textStyle(size.originalStyle)
                    .foregroundStyle(theme.text(.textTertiary))
            }
        } else {
            if let shownOriginal {
                Text(shownOriginal)
                    .strikethrough()   // Text-level: before .textStyle (View form is iOS 16+)
                    .textStyle(size.originalStyle)
                    .foregroundStyle(theme.text(.textTertiary))
            }
            amountText
        }
        if let unit {
            Text(unit)
                .textStyle(size.unitStyle)
                .foregroundStyle(theme.text(.textSecondary))
        }
        if let shownDiscount {
            Badge(shownDiscount).badgeStyle(.error).size(.small)
        }
    }

    @ViewBuilder private var amountText: some View {
        if let verbatimPrice {
            Text(verbatimPrice)
                .textStyle(size.priceStyle)
                .foregroundStyle(emphasis.color(theme))
                .numericTextTransitionCompat(resolvedAnimatesValue)
        } else {
            Text(formatted(amount))
                .textStyle(size.priceStyle)
                .foregroundStyle(emphasis.color(theme))
                .numericTextTransitionCompat(resolvedAnimatesValue,
                                             value: (amount as NSDecimalNumber).doubleValue)
        }
    }

    private func formatted(_ value: Decimal) -> String {
        value.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// `animatesValue()` resolved against Reduce Motion — the one motion gate
    /// (as in 1.4.0, `microAnimations` isn't consulted).
    private var resolvedAnimatesValue: Bool { animatesValue && !reduceMotion }

    /// The price as shown: the host's text, or the formatted amount.
    private var priceText: String { verbatimPrice ?? formatted(amount) }

    /// The struck original to draw: host text whenever set; a numeric one only
    /// on a formatted tag and only above the amount.
    private var shownOriginal: String? {
        if let originalText { return originalText }
        guard verbatimPrice == nil, let original, original > amount else { return nil }
        return formatted(original)
    }

    /// The discount badge to draw: host text whenever set, else the computed
    /// "-NN%" when `discountBadge()` is on and a saving exists.
    private var shownDiscount: String? {
        if let discountText { return discountText }
        guard showsDiscountBadge, let percent = discountPercent else { return nil }
        return "-\(percent)%"
    }

    private var discountPercent: Int? {
        guard verbatimPrice == nil else { return nil }   // no maths on host text
        return Self.discountPercent(original: original, amount: amount)
    }

    /// Rounded discount percentage from an original vs current price (pure; unit-tested).
    static func discountPercent(original: Decimal?, amount: Decimal) -> Int? {
        guard let original, original > 0, original > amount else { return nil }
        let ratio = (original - amount) / original
        return Int((ratio as NSDecimalNumber).doubleValue * 100 + 0.5)
    }

    /// The spoken label: the state word, or prefix · price · unit · host
    /// original · discount (host text, else the computed saving).
    private var accessibilityText: String {
        if let stateText { return stateText }
        var parts: [String] = []
        if let prefixText { parts.append(prefixText) }
        parts.append(priceText)
        if let unit { parts.append(unit) }
        if let originalText { parts.append(String(themeKit: "original price \(originalText)")) }
        if let discountText {
            parts.append(discountText)
        } else if let percent = discountPercent {
            parts.append(String(themeKit: "\(percent)% off"))
        }
        return parts.joined(separator: " ")
    }

    /// Everything a ``PriceTagStyle`` draws, resolved.
    private var styleConfiguration: PriceTagStyleConfiguration {
        PriceTagStyleConfiguration(
            price: priceText,
            amount: verbatimPrice == nil ? amount : nil,
            state: state,
            stateText: stateText,
            original: shownOriginal,
            originalBelow: originalBelow,
            prefix: prefixText,
            unit: unit,
            discount: shownDiscount,
            discountPercent: discountPercent,
            leading: leadingSlot,
            trailing: trailingSlot,
            size: size,
            emphasis: emphasis,
            animatesValue: resolvedAnimatesValue,
            accessibilityLabel: accessibilityText,
            density: density,
            locale: locale,
            isEnabled: isEnabled
        )
    }

    /// The word shown in place of the price for `.free` / `.soldOut`.
    private var stateText: String? {
        switch state {
        case .priced: return nil
        case .free: return String(themeKit: "Free")
        case .soldOut: return String(themeKit: "Sold out")
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceTag {
    /// A struck-through original price shown before the current one (enables the discount badge maths).
    /// Shown only when above the amount; ignored on a `PriceTag(verbatim:)`.
    /// Replaces an `original(verbatim:)` set earlier — the last call wins.
    func original(_ amount: Decimal?) -> Self { copy { $0.original = amount; $0.originalText = nil } }
    /// A struck-through original the host already formatted, e.g. `"EUR 1.899"`,
    /// shown whenever set — no comparison, no discount maths. VoiceOver reads it.
    /// Replaces a numeric `original(_:)` set earlier — the last call wins.
    func original(verbatim text: String?) -> Self { copy { $0.originalText = text; $0.original = nil } }
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
    /// Replaces a `discountBadge(_: String?)` text set earlier — the last call wins.
    func discountBadge(_ show: Bool = true) -> Self { copy { $0.showsDiscountBadge = show; $0.discountText = nil } }
    /// A discount badge with the host's own offer text, e.g. `"-15%"` or
    /// `"Deal"`, shown whenever set (`nil` → no badge). VoiceOver reads it in
    /// place of the computed saving. Replaces `discountBadge()` — the last call wins.
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text; $0.showsDiscountBadge = false } }
    /// Decimal places to render (default 0 — travel prices are usually whole).
    func fractionDigits(_ n: Int) -> Self { copy { $0.fractionDigits = max(0, n) } }
    /// Renders "Free" instead of the amount.
    func free() -> Self { copy { $0.state = .free } }
    /// Renders "Sold out" instead of the amount.
    func soldOut() -> Self { copy { $0.state = .soldOut } }
    /// Prefixes the price, e.g. "from ₺1.299".
    func prefix(_ text: String) -> Self { copy { $0.prefixText = text } }
    /// Prefixes the price with optional text; `nil` removes the prefix.
    func prefix(_ text: String?) -> Self { copy { $0.prefixText = text } }
    /// Shorthand for `.prefix("from")` — a "lead-in" price.
    func from() -> Self { copy { $0.prefixText = String(themeKit: "from") } }
    /// Animates digit changes (numeric-text transition); no-op under Reduce Motion.
    /// Wrap the value change in `withAnimation` at the call site to drive it.
    func animatesValue(_ on: Bool = true) -> Self { copy { $0.animatesValue = on } }
    /// A leading slot before the price and its prefix (an icon, a label).
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.leadingSlot = AnyView(content()) } }
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
        PreviewCase("Verbatim") {
            PriceTag(verbatim: "EUR 1.299").original(verbatim: "EUR 1.899").discountBadge("Deal").emphasis(.hero)
        }
        PreviewCase("Leading slot") { PriceTag(verbatim: "€89").unit("/ night").leading { Icon(systemName: "bed.double").size(.xs) } }
        PreviewCase("Custom style") {
            VStack(alignment: .leading, spacing: 8) {
                PriceTag(verbatim: "EUR 1.299").prefix("Total").original(verbatim: "EUR 1.899").discountBadge("-15%")
                PriceTag(1_299).original(1_899).unit("/ night").discountBadge()
                PriceTag(1_299).soldOut()
            }
            .priceTagStyle(PreviewStackedPriceTagStyle())
        }
    }
}

/// A host-shaped custom style for the preview: a trailing-aligned stack — the
/// prefix as a caption above, the price, then the struck original and the offer.
private struct PreviewStackedPriceTagStyle: PriceTagStyle {
    func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
        PreviewStackedPriceTagChrome(configuration: configuration)
    }
}

private struct PreviewStackedPriceTagChrome: View {
    let configuration: PriceTagStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .trailing, spacing: configuration.spacing(.xs)) {
            if let prefix = configuration.prefix {
                Text(prefix).textStyle(.overline400).foregroundStyle(theme.text(.textSecondary))
            }
            HStack(alignment: .firstTextBaseline, spacing: configuration.spacing(.xs)) {
                Text(configuration.stateText ?? configuration.price)
                    .textStyle(.headingSm)
                    .foregroundStyle(configuration.state == .priced ? theme.foreground(.fgHero) : theme.text(.textTertiary))
                if let unit = configuration.unit {
                    Text(unit).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            if configuration.state == .priced, configuration.original != nil || configuration.discount != nil {
                HStack(spacing: configuration.spacing(.xs)) {
                    if let original = configuration.original {
                        Text(original).strikethrough().textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    }
                    if let discount = configuration.discount {
                        Badge(discount).badgeStyle(.success).size(.small)
                    }
                }
            }
        }
    }
}
