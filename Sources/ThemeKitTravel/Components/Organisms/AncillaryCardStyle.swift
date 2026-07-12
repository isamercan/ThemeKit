//
//  AncillaryCardStyle.swift
//  ThemeKit
//
//  The styling hook for ``AncillaryCard`` (ADR-0004, Wave 3, Class A): the
//  configuration hands styles the *typed* add-on data (title, thumbnail, price,
//  badge…) plus the quantity/added control as pre-wired **state + closures** —
//  not a laid-out `AnyView` unit — so a style arranges the control itself and
//  never re-implements the stepper/toggle interaction. Three built-ins:
//
//    .row     icon/title/price + stepper or toggle, trailing edge — today's card. Default.
//    .tile    vertical grid tile: leading/badge row, title/subtitle, price, control at the bottom.
//    .banner  thumbnail-led full-width upsell strip — bigger art, softer surface.
//
//      AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg")
//          .price(450).quantity($bags, range: 0...4)
//          .ancillaryCardStyle(.tile)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints *chrome* (every built-in here is card-shaped, so it keeps
//  routing surface, elevation, selection and radius through `\.cardStyle`); the
//  token theme colors everything. Quantity/added state is a `@ControllableState`
//  owned by the component (ADR-F4) — the configuration exposes the current value
//  plus a `setQuantity`/`toggleAdded` closure, and a shared private
//  `AncillaryCardControl` (analogous to `FlightCardFavoriteHeart`) renders it
//  identically across all three presets, so the interaction logic is written once.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs an ``AncillaryCardStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no price → no price line, no badge → no chip).
public struct AncillaryCardConfiguration {
    /// The add-on's name, e.g. "Checked baggage".
    public let title: String
    /// SF Symbol used when there is no ``imageURL``/``leading`` slot.
    public let systemImage: String
    /// A remote thumbnail; wins over ``systemImage`` when set (and there's no
    /// ``leading`` slot). Styles size it.
    public let imageURL: URL?
    /// A one-line detail under the title, e.g. "20 kg".
    public let subtitle: String?
    /// The fare; `nil` hides the price line.
    public let priceAmount: Decimal?
    /// Currency code for ``priceAmount``, already resolved by the component
    /// through the FormatDefaults chain (explicit → `formatDefaults` →
    /// `locale.currency` → `"USD"`). Optional for additive safety only.
    public let currencyCode: String?
    /// A per-unit suffix after the price, e.g. `"/ bag"`.
    public let priceSuffix: String?
    /// Title badge text, e.g. "Popular"; `nil` hides the badge.
    public let badgeText: String?
    /// The title badge's style (`.info` unless overridden).
    public let badgeStyle: BadgeStyle

    /// `true` when ``AncillaryCard/quantity(_:range:)`` / ``AncillaryCard/quantity(range:)``
    /// was called — the interactive control is a stepper.
    public let showsQuantity: Bool
    /// The stepper's current value.
    public let quantity: Int
    /// The stepper's clamped range.
    public let quantityRange: ClosedRange<Int>
    /// Pre-wired step closure: styles read ``quantity`` and call this to change
    /// it. The `@ControllableState` storage stays in the component (ADR-F4) —
    /// styles never own a `Binding`, only this typed setter.
    public let setQuantity: ((Int) -> Void)?

    /// `true` when ``AncillaryCard/added(_:title:addedTitle:)`` /
    /// ``AncillaryCard/added(title:addedTitle:)`` was called — the interactive
    /// control is an add/remove toggle.
    public let showsAdded: Bool
    /// The toggle's current value.
    public let isAdded: Bool
    /// Pre-wired toggle closure — flips ``isAdded``. Same ADR-F4 split as
    /// ``setQuantity``.
    public let toggleAdded: (() -> Void)?
    /// Render-time-resolved "Add" title (already localized; re-resolves on
    /// every body pass, so a live language switch is never frozen).
    public let addTitle: String
    /// Render-time-resolved "Added" title.
    public let addedTitle: String

    /// Replacement for the built-in icon tile / thumbnail (`.leading { }`); `nil` = built-in.
    public let leading: AnyView?
    /// Replacement for the built-in stepper / add-button control area (`.trailing { }`).
    public let trailing: AnyView?

    /// Brand-chrome accent override (`AncillaryCard.accent(_:)`); `nil` defers
    /// to the subtree `ComponentDefaults.accent`, else `.primary` — resolve via
    /// ``resolvedAccent(_:)``.
    public let accent: SemanticColor?
    /// Explicit card-shell surface fill, or `nil` to let the style choose its
    /// own default (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Explicit stepper-track surface fill, or `nil` for the style's own
    /// default (resolve via ``controlSurface(default:)``).
    public let controlSurfaceKey: Theme.BackgroundColorKey?
    /// Shell corner radius role, fed to the active `CardStyle` by every
    /// (card-shaped) built-in.
    public let radiusRole: Theme.RadiusRole
    /// Shell elevation, fed to the active `CardStyle`.
    public let elevation: CardElevation
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale

    /// Added, or a positive quantity — card-shaped styles feed this to the
    /// `CardStyle` shell's `isSelected` (the default style draws a hero border).
    public var isActive: Bool { (showsAdded && isAdded) || (showsQuantity && quantity > 0) }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }
    /// The explicit `controlSurface(_:)` override, or the style's own default.
    public func controlSurface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        controlSurfaceKey ?? fallback
    }
    /// Density-scaled spacing — use for chrome padding/gaps so
    /// `.componentDensity` compacts or airs out the card.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
    /// The `accent(_:)` override, else the subtree `ComponentDefaults.accent`,
    /// else `.primary` — the resolution every built-in tints its icon/control
    /// with (the value the pre-style component computed as `accentSemantic`).
    public func resolvedAccent(_ defaults: ComponentDefaults) -> SemanticColor {
        accent ?? defaults.accent ?? .primary
    }
    /// Shared price formatting, so every style speaks one language. Matches the
    /// pre-style rendering exactly (no explicit `.locale()` — the amount is
    /// already currency-coded via ``currencyCode``).
    public func formattedPrice(_ amount: Decimal) -> String {
        amount.formatted(.currency(code: currencyCode ?? "USD").precision(.fractionLength(0)))
    }
}

// MARK: - Protocol

/// Defines an `AncillaryCard`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's add-on data. Set one with `.ancillaryCardStyle(_:)`;
/// the default is ``RowAncillaryCardStyle``.
public protocol AncillaryCardStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: AncillaryCardConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The leading affordance — a custom slot, a remote thumbnail, or the icon
/// tile — shared by every preset. `size`/`iconSize` are fixed per-preset
/// constants (not public knobs); the defaults reproduce `IconTile`'s own
/// defaults exactly, so `.row` renders byte-for-byte identical to the
/// pre-style component.
private struct AncillaryCardLeadingTile: View {
    @Environment(\.componentDefaults) private var defaults
    let configuration: AncillaryCardConfiguration
    var size: CGFloat = 46
    var iconSize: CGFloat = 18

    var body: some View {
        if let leading = configuration.leading {
            leading
        } else if let imageURL = configuration.imageURL {
            RemoteImage(imageURL).contentMode(.fill).frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        } else {
            IconTile(configuration.systemImage)
                .accent(configuration.resolvedAccent(defaults))
                .size(size)
                .iconSize(iconSize)
        }
    }
}

/// The formatted price (+ optional unit suffix) — shared by every preset.
private struct AncillaryCardPriceLine: View {
    @Environment(\.theme) private var theme
    let configuration: AncillaryCardConfiguration
    let amount: Decimal
    var textStyle: TextStyle = .labelBase700

    var body: some View {
        HStack(spacing: 2) {
            Text(configuration.formattedPrice(amount))
                .textStyle(textStyle).foregroundStyle(theme.text(.textPrimary))
            if let priceSuffix = configuration.priceSuffix {
                Text(priceSuffix).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
            }
        }
    }
}

/// The interactive control area — a custom slot, the quantity stepper, or the
/// add/remove toggle. Every built-in preset places this one view; the
/// interaction logic (clamping, toggling, read-only gating, a11y) is written
/// once here instead of once per preset.
private struct AncillaryCardControl: View {
    let configuration: AncillaryCardConfiguration

    var body: some View {
        if let trailing = configuration.trailing {
            trailing
        } else if configuration.showsQuantity {
            AncillaryCardStepper(configuration: configuration)
        } else if configuration.showsAdded {
            AncillaryCardAddButton(configuration: configuration)
        }
    }
}

private struct AncillaryCardStepper: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDefaults) private var defaults
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — read-only surfaces render but don't mutate
    let configuration: AncillaryCardConfiguration

    private var accentSemantic: SemanticColor { configuration.resolvedAccent(defaults) }

    var body: some View {
        HStack(spacing: 0) {
            stepButton("minus", label: String(themeKit: "Decrease"),
                       enabled: configuration.quantity > configuration.quantityRange.lowerBound) {
                configuration.setQuantity?(max(configuration.quantityRange.lowerBound, configuration.quantity - 1))
            }
            Text("\(configuration.quantity)").textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                .frame(minWidth: 28).monospacedDigit()
            stepButton("plus", label: String(themeKit: "Increase"),
                       enabled: configuration.quantity < configuration.quantityRange.upperBound) {
                configuration.setQuantity?(min(configuration.quantityRange.upperBound, configuration.quantity + 1))
            }
        }
        .padding(.horizontal, 4)
        .background(theme.background(configuration.controlSurface(default: .bgSecondary)), in: Capsule())
        .disabled(isReadOnly)
    }

    private func stepButton(_ icon: String, label: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon).font(.system(size: 13, weight: .bold))
                .foregroundStyle(enabled ? accentSemantic.base : theme.text(.textDisabled))
                .frame(width: 32, height: 32)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(label)
        .accessibilityValue("\(configuration.quantity)")
    }
}

private struct AncillaryCardAddButton: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDefaults) private var defaults
    @Environment(\.isReadOnly) private var isReadOnly   // E1 — read-only surfaces render but don't mutate
    let configuration: AncillaryCardConfiguration

    private var accentSemantic: SemanticColor { configuration.resolvedAccent(defaults) }

    var body: some View {
        let on = configuration.isAdded
        Button { configuration.toggleAdded?() } label: {
            HStack(spacing: 4) {
                Image(systemName: on ? "checkmark" : "plus").font(.system(size: 12, weight: .bold))
                Text(on ? configuration.addedTitle : configuration.addTitle).textStyle(.labelSm700)
            }
            .foregroundStyle(on ? accentSemantic.onSolid : accentSemantic.base)
            .padding(.horizontal, configuration.spacing(.md))
            .frame(height: 36)
            .background(on ? accentSemantic.solid : accentSemantic.bg, in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(isReadOnly)
        .accessibilityLabel(configuration.title)
        .accessibilityAddTraits(on ? .isSelected : [])
    }
}

// MARK: - .row

/// Today's ``AncillaryCard`` look, extracted verbatim: leading tile, title +
/// badge, subtitle, price, and the stepper/toggle control at the trailing edge
/// — all inside the active `CardStyle` shell.
public struct RowAncillaryCardStyle: AncillaryCardStyle {
    public init() {}
    public func makeBody(configuration: AncillaryCardConfiguration) -> some View {
        RowAncillaryCardChrome(configuration: configuration)
    }
}

private struct RowAncillaryCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: AncillaryCardConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radiusRole.value, style: .continuous)
    }

    var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the
        // active `CardStyle` — built-ins and custom styles go through the same
        // gate. `.none` elevation reproduces the classic flat look: a 1pt
        // hairline border, no shadow.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: configuration.elevation,
            isSelected: configuration.isActive,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: configuration.radiusRole))
            .contentShape(shape)
    }

    private var cardContent: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            AncillaryCardLeadingTile(configuration: configuration)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(configuration.title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let badgeText = configuration.badgeText {
                        Badge(badgeText).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small).fixedSize()
                    }
                }
                if let subtitle = configuration.subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
                if let price = configuration.priceAmount {
                    AncillaryCardPriceLine(configuration: configuration, amount: price)
                }
            }
            Spacer(minLength: 6)
            AncillaryCardControl(configuration: configuration)
        }
        .padding(configuration.spacing(.md))
    }
}

// MARK: - .tile

/// A vertical grid tile: leading tile + badge on top, title/subtitle below,
/// then the price and — at the bottom — the stepper/toggle control. Destination
/// / add-on carousels and grid pickers.
public struct TileAncillaryCardStyle: AncillaryCardStyle {
    public init() {}
    public func makeBody(configuration: AncillaryCardConfiguration) -> some View {
        TileAncillaryCardChrome(configuration: configuration)
    }
}

private struct TileAncillaryCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: AncillaryCardConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radiusRole.value, style: .continuous)
    }

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(tileContent),
            elevation: configuration.elevation,
            isSelected: configuration.isActive,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgBase),
            radius: configuration.radiusRole))
            .contentShape(shape)
    }

    private var tileContent: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            HStack(alignment: .top, spacing: configuration.spacing(.sm)) {
                AncillaryCardLeadingTile(configuration: configuration, size: 40, iconSize: 16)
                Spacer(minLength: 0)
                if let badgeText = configuration.badgeText {
                    Badge(badgeText).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small).fixedSize()
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(configuration.title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(2)
                if let subtitle = configuration.subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
            }
            if let price = configuration.priceAmount {
                AncillaryCardPriceLine(configuration: configuration, amount: price)
            }
            // The control anchors the tile's bottom edge (VStack's leading
            // alignment keeps it left-aligned, matching a grid-tile CTA).
            AncillaryCardControl(configuration: configuration)
        }
        .padding(configuration.spacing(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - .banner

/// A thumbnail-led, full-width upsell strip: a larger leading image/icon, a
/// bigger title, subtitle and price in the middle, the control on the trailing
/// edge — and a softer default surface so it reads as a promo, not a list row.
public struct BannerAncillaryCardStyle: AncillaryCardStyle {
    public init() {}
    public func makeBody(configuration: AncillaryCardConfiguration) -> some View {
        BannerAncillaryCardChrome(configuration: configuration)
    }
}

private struct BannerAncillaryCardChrome: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle
    let configuration: AncillaryCardConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radiusRole.value, style: .continuous)
    }

    var body: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(bannerContent),
            elevation: configuration.elevation,
            isSelected: configuration.isActive,
            isPressed: false,
            surfaceKey: configuration.surface(default: .bgSecondaryLight),
            radius: configuration.radiusRole))
            .contentShape(shape)
    }

    private var bannerContent: some View {
        HStack(alignment: .center, spacing: configuration.spacing(.md)) {
            AncillaryCardLeadingTile(configuration: configuration, size: 64, iconSize: 26)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(configuration.title).textStyle(.labelLg700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
                    if let badgeText = configuration.badgeText {
                        Badge(badgeText).badgeStyle(configuration.badgeStyle).variant(.soft).size(.small).fixedSize()
                    }
                }
                if let subtitle = configuration.subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(2)
                }
                if let price = configuration.priceAmount {
                    AncillaryCardPriceLine(configuration: configuration, amount: price)
                }
            }
            Spacer(minLength: configuration.spacing(.sm))
            AncillaryCardControl(configuration: configuration)
        }
        .padding(configuration.spacing(.md))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Static accessors

public extension AncillaryCardStyle where Self == RowAncillaryCardStyle {
    /// Icon/title/price + stepper or toggle, trailing edge — today's card. The default.
    static var row: RowAncillaryCardStyle { RowAncillaryCardStyle() }
}
public extension AncillaryCardStyle where Self == TileAncillaryCardStyle {
    /// Vertical grid tile: leading/badge row, title/subtitle, price, control at the bottom.
    static var tile: TileAncillaryCardStyle { TileAncillaryCardStyle() }
}
public extension AncillaryCardStyle where Self == BannerAncillaryCardStyle {
    /// Thumbnail-led full-width upsell strip.
    static var banner: BannerAncillaryCardStyle { BannerAncillaryCardStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyAncillaryCardStyle: AncillaryCardStyle {
    private let _makeBody: @MainActor (AncillaryCardConfiguration) -> AnyView
    init<S: AncillaryCardStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: AncillaryCardConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct AncillaryCardStyleKey: EnvironmentKey {
    static let defaultValue = AnyAncillaryCardStyle(RowAncillaryCardStyle())
}

extension EnvironmentValues {
    var ancillaryCardStyle: AnyAncillaryCardStyle {
        get { self[AncillaryCardStyleKey.self] }
        set { self[AncillaryCardStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``AncillaryCardStyle`` for `AncillaryCard`s in this view and its
    /// descendants — one screen can mix archetypes per section.
    func ancillaryCardStyle<S: AncillaryCardStyle>(_ style: sending S) -> some View {
        environment(\.ancillaryCardStyle, AnyAncillaryCardStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a flat accent-tinted strip, no card shell, control still pre-wired.
private struct AccentFlatAncillaryCardStyle: AncillaryCardStyle {
    func makeBody(configuration: AncillaryCardConfiguration) -> some View {
        AccentFlatChrome(configuration: configuration)
    }

    private struct AccentFlatChrome: View {
        @Environment(\.theme) private var theme
        @Environment(\.componentDefaults) private var defaults
        let configuration: AncillaryCardConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                Icon(systemName: configuration.systemImage).size(.lg)
                    .accent(configuration.resolvedAccent(defaults))
                VStack(alignment: .leading, spacing: 2) {
                    Text(configuration.title).textStyle(.labelMd700).foregroundStyle(theme.text(.textPrimary))
                    if let price = configuration.priceAmount {
                        Text(configuration.formattedPrice(price))
                            .textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer()
                AncillaryCardControl(configuration: configuration)
            }
            .padding(configuration.spacing(.sm))
            .background(theme.background(.bgSecondaryLight), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
        }
    }
}

#Preview("AncillaryCardStyle — presets × light/dark") {
    struct Demo: View {
        @State private var bags = 1
        @State private var insurance = false
        var body: some View {
            let row = AncillaryCard("Checked baggage").icon("suitcase.fill").subtitle("20 kg")
                .price(450, suffix: "/ bag").quantity($bags, range: 0...4)
            let toggle = AncillaryCard("Travel insurance").icon("cross.case.fill").subtitle("Full coverage")
                .price(120).badge("Popular").added($insurance)
            return PreviewMatrix("AncillaryCardStyle") {
                PreviewCase("Row · stepper (default)") { row }
                PreviewCase("Row · toggle") { toggle }
                PreviewCase("Tile · stepper") { row.ancillaryCardStyle(.tile).frame(width: 180) }
                PreviewCase("Tile · toggle") { toggle.ancillaryCardStyle(.tile).frame(width: 180) }
                PreviewCase("Banner · stepper") { row.ancillaryCardStyle(.banner) }
                PreviewCase("Banner · toggle") { toggle.ancillaryCardStyle(.banner) }
                PreviewCase("Custom (in-preview)") { row.ancillaryCardStyle(AccentFlatAncillaryCardStyle()) }
            }
        }
    }
    return Demo()
}
