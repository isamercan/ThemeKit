//
//  PriceTagStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `PriceTag`. The chrome — how the
//  price, the struck original, the prefix, the unit and the discount badge are
//  laid out, which type style and which colour each one gets — lives in a
//  `PriceTagStyle` you set with `.priceTagStyle(_:)`, so a host design system
//  can draw its own price block (a vertical stack, a caption above, its own
//  text styles and badge) without editing `PriceTag`.
//
//  `PriceTag` keeps everything that isn't paint: the content model (formatted
//  or verbatim price, the free / sold-out states, the discount maths), the
//  leading/trailing slots, the resolved motion flag and the VoiceOver label,
//  which it applies around whatever the style draws. The default style is
//  today's first-baseline row, so this is additive and non-breaking.
//
//      PriceTag(verbatim: "EUR 1.299")
//          .original(verbatim: "EUR 1.899").discountBadge("-15%")
//          .priceTagStyle(MyPriceChrome())   // or set it once on a container
//

import SwiftUI

// MARK: - Configuration

/// The inputs a ``PriceTagStyle`` renders. Every string is raw, unstyled
/// content — a style picks its own type style and colour for each — and every
/// optional is already resolved: `nil` means "the tag has none", so a style
/// never repeats the component's rules (when an original is shown, when a
/// discount badge appears).
public struct PriceTagStyleConfiguration {
    /// The headline price text: the tag's formatted amount, or the host's own
    /// string on a verbatim tag (`PriceTag(verbatim:)`). Always present — a
    /// `.free()` / `.soldOut()` tag still carries it, next to ``stateText``.
    public let price: String
    /// The numeric amount of a formatted tag; `nil` on a verbatim tag. Use it
    /// as the value of a numeric content transition.
    public let amount: Decimal?
    /// What the tag represents — a price, a free offer, or an unavailable fare.
    public let state: PriceState
    /// The localized word the default style draws *instead of* the price for
    /// `.free` ("Free") and `.soldOut` ("Sold out"); `nil` while `.priced`.
    public let stateText: String?
    /// The struck-through original to draw, or `nil` for none. The host's text
    /// from `original(verbatim:)` whenever set; a numeric `original(_:)` only
    /// when the tag is formatted and the original is above the amount.
    public let original: String?
    /// Whether the original stacks below the price (`originalBelow()`) rather
    /// than sitting inline before it.
    public let originalBelow: Bool
    /// The lead-in text, e.g. "from" (`prefix(_:)` / `from()`).
    public let prefix: String?
    /// The per-unit suffix, e.g. "/ night" (`unit(_:)`).
    public let unit: String?
    /// The discount badge text to draw, or `nil` for no badge: the host's text
    /// from `discountBadge(_: String?)`, or the computed "-NN%" when
    /// `discountBadge()` is on and a saving exists.
    public let discount: String?
    /// The rounded saving computed from a numeric original and amount — present
    /// whenever it can be computed, whether or not a badge is shown; always
    /// `nil` on a verbatim tag (ThemeKit does no maths on host text).
    public let discountPercent: Int?
    /// The `leading { }` slot, drawn before everything else; `nil` when unset.
    public let leading: AnyView?
    /// The `trailing { }` slot, drawn after everything else; `nil` when unset.
    public let trailing: AnyView?
    /// The tag's size tier.
    public let size: PriceSize
    /// The colour emphasis of the headline price.
    public let emphasis: PriceEmphasis
    /// Whether the price should roll on change — `animatesValue()` already
    /// resolved against Reduce Motion. Styles never read the motion
    /// environment themselves (ADR-0004 §4).
    ///
    /// As in 1.4.0, this flag doesn't follow `microAnimations(_:)`: a tag
    /// under `microAnimations(false)` still rolls. A later minor release will
    /// gate it on that switch too; a style that uses the flag picks the change
    /// up with no code change.
    public let animatesValue: Bool
    /// The VoiceOver label `PriceTag` applies around the style's body — the
    /// prefix, price, unit, original and discount as spoken text (host strings
    /// verbatim). Informational: the component already sets it.
    public let accessibilityLabel: String
    /// The environment's component density, captured by the component — scale
    /// any spacing a style adds with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale
    /// Whether the tag is enabled (`.disabled(_:)` in the environment). The
    /// default style ignores it.
    public let isEnabled: Bool

    init(
        price: String,
        amount: Decimal?,
        state: PriceState,
        stateText: String?,
        original: String?,
        originalBelow: Bool,
        prefix: String?,
        unit: String?,
        discount: String?,
        discountPercent: Int?,
        leading: AnyView?,
        trailing: AnyView?,
        size: PriceSize,
        emphasis: PriceEmphasis,
        animatesValue: Bool,
        accessibilityLabel: String,
        density: ComponentDensity,
        locale: Locale,
        isEnabled: Bool
    ) {
        self.price = price
        self.amount = amount
        self.state = state
        self.stateText = stateText
        self.original = original
        self.originalBelow = originalBelow
        self.prefix = prefix
        self.unit = unit
        self.discount = discount
        self.discountPercent = discountPercent
        self.leading = leading
        self.trailing = trailing
        self.size = size
        self.emphasis = emphasis
        self.animatesValue = animatesValue
        self.accessibilityLabel = accessibilityLabel
        self.density = density
        self.locale = locale
        self.isEnabled = isEnabled
    }

    /// Whether the price is host text from `PriceTag(verbatim:)` — nothing on
    /// the tag was formatted by ThemeKit.
    public var isVerbatim: Bool { amount == nil }

    /// Density-scaled spacing, for any gaps a style adds between the parts.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Draws a ``PriceTag``. Implement `makeBody` to lay out and paint the
/// configuration's raw parts — price, original, prefix, unit, discount and the
/// slots — with your own type styles, colours and badge. Set one with
/// `.priceTagStyle(_:)`; the default is ``DefaultPriceTagStyle``.
///
/// `PriceTag` keeps the content model, the slots and accessibility: it wraps
/// whatever the style returns in one VoiceOver element labelled with
/// ``PriceTagStyleConfiguration/accessibilityLabel``, so a style only draws.
///
/// The style is read from the environment, so setting it on a container
/// restyles every `PriceTag` below — including the ones ThemeKit composes
/// inside other components (`PriceBreakdown`, `DestinationCard`,
/// `PriceAlertCard`, `MapCallout`, and the ThemeKitTravel fare and flight
/// cards). Set it on the tag itself to restyle just that one.
///
/// ```swift
/// struct StackedPriceStyle: PriceTagStyle {
///     func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
///         VStack(alignment: .trailing, spacing: configuration.spacing(.xs)) {
///             if let prefix = configuration.prefix { Text(prefix).font(.caption) }
///             Text(configuration.stateText ?? configuration.price).font(.title3.bold())
///             if let original = configuration.original { Text(original).strikethrough() }
///         }
///     }
/// }
///
/// PriceTag(verbatim: "EUR 1.299").from().priceTagStyle(StackedPriceStyle())
/// ```
public protocol PriceTagStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: PriceTagStyleConfiguration) -> Body
}

// MARK: - Default style

/// The stock price row — `PriceTag`'s own look: a first-baseline row of the
/// leading slot, the secondary prefix, the struck tertiary original (inline
/// before the price, or stacked below it), the price in its size tier's type
/// style and emphasis colour, the secondary unit, a small error `Badge` for the
/// discount, and the trailing slot. Ignores `isEnabled`. Reads the active
/// `\.theme`, so an injected theme re-skins it too.
public struct DefaultPriceTagStyle: PriceTagStyle, Sendable {
    public init() {}
    public func makeBody(configuration: PriceTagStyleConfiguration) -> some View {
        DefaultPriceTagChrome(configuration: configuration)
    }
}

/// Mirrors `PriceTag`'s default-path body part for part, reading the resolved
/// configuration instead of the component's stored properties — so
/// `.priceTagStyle(.default)` draws exactly what no style at all draws.
private struct DefaultPriceTagChrome: View {
    let configuration: PriceTagStyleConfiguration
    @Environment(\.theme) private var theme

    private var size: PriceSize { configuration.size }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: configuration.spacing(.xs)) {
            if let leading = configuration.leading { leading }
            if let prefix = configuration.prefix {
                Text(prefix).textStyle(size.unitStyle).foregroundStyle(theme.text(.textSecondary))
            }
            switch configuration.state {
            case .priced: pricedContent
            case .free:
                Text(configuration.stateText ?? configuration.price)
                    .textStyle(size.priceStyle).foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            case .soldOut:
                Text(configuration.stateText ?? configuration.price)
                    .textStyle(size.priceStyle).foregroundStyle(theme.text(.textTertiary))
            }
            if let trailing = configuration.trailing { trailing }
        }
    }

    @ViewBuilder private var pricedContent: some View {
        if configuration.originalBelow, let original = configuration.original {
            VStack(alignment: .trailing, spacing: 0) {
                priceText
                originalText(original)
            }
        } else {
            if let original = configuration.original { originalText(original) }
            priceText
        }
        if let unit = configuration.unit {
            Text(unit)
                .textStyle(size.unitStyle)
                .foregroundStyle(theme.text(.textSecondary))
        }
        if let discount = configuration.discount {
            Badge(discount).badgeStyle(.error).size(.small)
        }
    }

    @ViewBuilder private var priceText: some View {
        if let amount = configuration.amount {
            Text(configuration.price)
                .textStyle(size.priceStyle)
                .foregroundStyle(configuration.emphasis.color(theme))
                .numericTextTransitionCompat(configuration.animatesValue,
                                             value: (amount as NSDecimalNumber).doubleValue)
        } else {
            Text(configuration.price)
                .textStyle(size.priceStyle)
                .foregroundStyle(configuration.emphasis.color(theme))
                .numericTextTransitionCompat(configuration.animatesValue)
        }
    }

    private func originalText(_ text: String) -> some View {
        Text(text)
            .strikethrough()   // Text-level: before .textStyle (View form is iOS 16+)
            .textStyle(size.originalStyle)
            .foregroundStyle(theme.text(.textTertiary))
    }
}

public extension PriceTagStyle where Self == DefaultPriceTagStyle {
    /// The stock price row — `PriceTag`'s own look.
    static var `default`: DefaultPriceTagStyle { DefaultPriceTagStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyPriceTagStyle: PriceTagStyle {
    /// `true` only for the environment key's stock value — no
    /// `.priceTagStyle(_:)` anywhere up the tree. `PriceTag` keys off this to
    /// render its original inline body (pixel-identical by construction) and
    /// routes through `makeBody` only when a style was explicitly set,
    /// `.default` included.
    let isDefault: Bool
    private let _makeBody: @MainActor (PriceTagStyleConfiguration) -> AnyView
    init<S: PriceTagStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: PriceTagStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct PriceTagStyleKey: EnvironmentKey {
    static let defaultValue = AnyPriceTagStyle(DefaultPriceTagStyle(), isDefault: true)
}

extension EnvironmentValues {
    var priceTagStyle: AnyPriceTagStyle {
        get { self[PriceTagStyleKey.self] }
        set { self[PriceTagStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``PriceTagStyle`` for `PriceTag`s in this view and its
    /// descendants — including the tags ThemeKit composes inside other
    /// components.
    func priceTagStyle<S: PriceTagStyle>(_ style: sending S) -> some View {
        environment(\.priceTagStyle, AnyPriceTagStyle(style))
    }
}
