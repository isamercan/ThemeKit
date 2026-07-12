//
//  StickyBookingBarStyle.swift
//  ThemeKit
//
//  The styling hook for ``StickyBookingBar`` (ADR-0004, Wave 3 — Class B). The
//  bar owns every *live control* — the CTA's action/`.enabled`/`.loading`, the
//  price-tap disclosure, the secondary action — so re-wiring them per style
//  would duplicate interaction logic. Instead the configuration hands styles
//  **pre-wired, type-erased units** (a price block, a primary CTA, an optional
//  secondary CTA) plus typed signals; styles arrange the units, never re-wire
//  them. Three built-ins:
//
//    .standard  price block left / CTA (+ secondary) right — today's bar. Default.
//    .stacked   note+price above a full-width CTA (+ secondary at its natural width)
//    .split     secondary and primary share the row evenly — a paired action row
//
//      StickyBookingBar("Book now") { checkout() }
//          .price(9_600).original(12_000).discountBadge("-20%")
//          .stickyBookingBarStyle(.stacked)
//
//  One law (ADR-0004 §6, unchanged from before this ADR): this protocol
//  arranges *content*; the bar's `BarStyle` chrome (surface fill, hairline,
//  shadow) stays **outside** this protocol and keeps painting around whatever
//  a `StickyBookingBarStyle` arranges — `.barStyle(_:)` still reskins the
//  chrome independently of `.stickyBookingBarStyle(_:)`. The token theme
//  colors everything.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The pre-wired inputs a ``StickyBookingBarStyle`` arranges. `cta` and
/// `secondaryCta` are built `.fullWidth()`-capable so `.stacked`/`.split` can
/// stretch them edge-to-edge; ``StandardStickyBookingBarStyle`` restores the
/// classic content-sized footprint with `.fixedSize(horizontal:vertical:)`
/// (a pure layout ask, not a re-wire — see its chrome). Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no price → no price block, no secondary action →
/// no secondary slot).
public struct StickyBookingBarConfiguration {
    /// The built-in price display — note, struck original, discount badge and
    /// price (`PriceBreakdown`), wrapped in a disclosure-chevron button when
    /// `.onPriceTap(_:)` was set. `nil` precisely when ``hasPrice`` is `false`.
    public let priceBlock: AnyView?
    /// The primary CTA — title, icon, color, `.enabled`/`.loading` fully wired.
    /// Built `.fullWidth()`-capable (see the type header).
    public let cta: AnyView
    /// An outline secondary action beside the CTA (`.secondaryAction(_:action:)`),
    /// `nil` when unset. Also built `.fullWidth()`-capable.
    public let secondaryCta: AnyView?
    /// Full replacement for the price side (`.leading { }`) — wins over ``priceBlock``.
    public let leading: AnyView?
    /// Full replacement for the CTA side (`.trailing { }`) — wins over ``cta``/``secondaryCta``.
    public let trailing: AnyView?

    /// Whether a price was set — precisely when ``priceBlock`` is non-nil.
    public let hasPrice: Bool
    /// The raw discount text (e.g. "-20%"), already rendered inline inside
    /// ``priceBlock`` — exposed for styles that want it *outside* the price
    /// stack (a corner ribbon, a chip next to the CTA…).
    public let discountBadge: String?
    /// `.enabled(_:)` — already baked into ``cta``/``secondaryCta``; exposed so
    /// a style can dim or hide accessories it adds of its own.
    public let isEnabled: Bool
    /// `.loading(_:)` — already baked into ``cta``.
    public let isLoading: Bool
    /// Brand-chrome accent (`.accent(_:)`), or `nil` for the theme's hero
    /// tokens — the color already baked into ``cta``/``secondaryCta``.
    public let accent: SemanticColor?
    /// Explicit surface fill (`.surface(_:)`), or `nil` to let the active
    /// `BarStyle` choose its own — resolve via ``surface(default:)``.
    public let surfaceKey: Theme.BackgroundColorKey?
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the bar.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `StickyBookingBar`'s content arrangement — the price/CTA units,
/// never the bar chrome. Implement `makeBody` to lay out the configuration's
/// pre-wired units. Set one with `.stickyBookingBarStyle(_:)`; the default is
/// ``StandardStickyBookingBarStyle``. The active ``BarStyle`` (`.barStyle(_:)`)
/// still paints the surface/hairline/shadow around whatever this style
/// arranges (ADR-0004 §6) — that delegation is unchanged by this protocol.
public protocol StickyBookingBarStyle {
    associatedtype Body: View
    @MainActor @ViewBuilder func makeBody(configuration: StickyBookingBarConfiguration) -> Body
}

// MARK: - .standard (default — today's bar, verbatim)

/// Price block left, CTA (+ optional outline secondary) right — today's
/// ``StickyBookingBar`` look, extracted verbatim.
public struct StandardStickyBookingBarStyle: StickyBookingBarStyle {
    public init() {}
    public func makeBody(configuration: StickyBookingBarConfiguration) -> some View {
        StandardStickyBookingBarChrome(configuration: configuration)
    }
}

private struct StandardStickyBookingBarChrome: View {
    let configuration: StickyBookingBarConfiguration

    var body: some View {
        HStack(alignment: .center, spacing: configuration.spacing(.md)) {
            if let leading = configuration.leading {
                leading
            } else if let priceBlock = configuration.priceBlock {
                priceBlock
            }
            Spacer(minLength: 8)
            if let trailing = configuration.trailing {
                trailing
            } else {
                ctaArea
            }
        }
        .padding(.horizontal, configuration.spacing(.md))
        .padding(.vertical, configuration.spacing(.sm))
        .frame(maxWidth: .infinity)
    }

    /// The pre-wired CTA units restored to their intrinsic footprint.
    /// `.fixedSize(horizontal:vertical:)` asks each unit for its own ideal
    /// width instead of the space this row would otherwise offer it, which
    /// reproduces the classic content-sized, trailing-aligned CTA
    /// pixel-for-pixel even though both units are `.fullWidth()`-capable.
    private var ctaArea: some View {
        HStack(spacing: configuration.spacing(.sm)) {
            if let secondaryCta = configuration.secondaryCta {
                secondaryCta.fixedSize(horizontal: true, vertical: false)
            }
            configuration.cta.fixedSize(horizontal: true, vertical: false)
        }
    }
}

// MARK: - .stacked (note+price above a full-width CTA)

/// The price block on its own row, a full-width CTA beneath it — an outline
/// secondary action (when set) keeps its natural width leading the CTA row.
/// Reads better than `.standard` at narrow widths or with a long CTA title.
public struct StackedStickyBookingBarStyle: StickyBookingBarStyle {
    public init() {}
    public func makeBody(configuration: StickyBookingBarConfiguration) -> some View {
        StackedStickyBookingBarChrome(configuration: configuration)
    }
}

private struct StackedStickyBookingBarChrome: View {
    let configuration: StickyBookingBarConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if let leading = configuration.leading {
                leading
            } else if let priceBlock = configuration.priceBlock {
                priceBlock
            }
            ctaRow
        }
        .padding(.horizontal, configuration.spacing(.md))
        .padding(.vertical, configuration.spacing(.sm))
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var ctaRow: some View {
        if let trailing = configuration.trailing {
            trailing
        } else {
            HStack(spacing: configuration.spacing(.sm)) {
                if let secondaryCta = configuration.secondaryCta {
                    secondaryCta.fixedSize(horizontal: true, vertical: false)
                }
                configuration.cta   // left `.fullWidth()` — stretches to fill the row
            }
        }
    }
}

// MARK: - .split (secondary + primary action pair)

/// An optional price block on top, then the secondary and primary actions
/// sharing the row evenly beneath it — a paired confirm/cancel-style row.
/// With no secondary action set, the CTA alone fills the row (same footprint
/// as `.stacked`'s CTA row).
public struct SplitStickyBookingBarStyle: StickyBookingBarStyle {
    public init() {}
    public func makeBody(configuration: StickyBookingBarConfiguration) -> some View {
        SplitStickyBookingBarChrome(configuration: configuration)
    }
}

private struct SplitStickyBookingBarChrome: View {
    let configuration: StickyBookingBarConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
            if let leading = configuration.leading {
                leading
            } else if let priceBlock = configuration.priceBlock {
                priceBlock
            }
            actionRow
        }
        .padding(.horizontal, configuration.spacing(.md))
        .padding(.vertical, configuration.spacing(.sm))
        .frame(maxWidth: .infinity)
    }

    /// Secondary and primary share the row evenly — both units are built
    /// `.fullWidth()`-capable, so an unadorned `HStack` splits the available
    /// width between them without either needing an explicit fraction.
    @ViewBuilder private var actionRow: some View {
        if let trailing = configuration.trailing {
            trailing
        } else if let secondaryCta = configuration.secondaryCta {
            HStack(spacing: configuration.spacing(.sm)) {
                secondaryCta
                configuration.cta
            }
        } else {
            configuration.cta
        }
    }
}

// MARK: - Static accessors

public extension StickyBookingBarStyle where Self == StandardStickyBookingBarStyle {
    /// Price block left / CTA (+ secondary) right — today's bar. The default.
    static var standard: StandardStickyBookingBarStyle { StandardStickyBookingBarStyle() }
}
public extension StickyBookingBarStyle where Self == StackedStickyBookingBarStyle {
    /// Note+price above a full-width CTA — reads better at narrow widths.
    static var stacked: StackedStickyBookingBarStyle { StackedStickyBookingBarStyle() }
}
public extension StickyBookingBarStyle where Self == SplitStickyBookingBarStyle {
    /// Secondary and primary actions share the row evenly — a paired action row.
    static var split: SplitStickyBookingBarStyle { SplitStickyBookingBarStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyStickyBookingBarStyle: StickyBookingBarStyle {
    private let _makeBody: @MainActor (StickyBookingBarConfiguration) -> AnyView
    init<S: StickyBookingBarStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: StickyBookingBarConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct StickyBookingBarStyleKey: EnvironmentKey {
    static let defaultValue = AnyStickyBookingBarStyle(StandardStickyBookingBarStyle())
}

extension EnvironmentValues {
    var stickyBookingBarStyle: AnyStickyBookingBarStyle {
        get { self[StickyBookingBarStyleKey.self] }
        set { self[StickyBookingBarStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``StickyBookingBarStyle`` for `StickyBookingBar`s in this view
    /// and its descendants. Independent of `.barStyle(_:)` (ADR-0004 §6): this
    /// arranges the price/CTA content, `.barStyle(_:)` paints the bar chrome
    /// around it.
    func stickyBookingBarStyle<S: StickyBookingBarStyle>(_ style: sending S) -> some View {
        environment(\.stickyBookingBarStyle, AnyStickyBookingBarStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — proves the protocol is
/// externally implementable: an accent ribbon built from the raw
/// `discountBadge` *signal* (not the pre-wired `priceBlock` unit) beside the
/// action pair.
private struct RibbonStickyBookingBarStyle: StickyBookingBarStyle {
    func makeBody(configuration: StickyBookingBarConfiguration) -> some View {
        RibbonChrome(configuration: configuration)
    }

    private struct RibbonChrome: View {
        let configuration: StickyBookingBarConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.sm)) {
                if let discountBadge = configuration.discountBadge {
                    Badge(discountBadge).badgeStyle(.error).variant(.solid).size(.small)
                }
                Spacer(minLength: configuration.spacing(.sm))
                if let secondaryCta = configuration.secondaryCta {
                    secondaryCta.fixedSize(horizontal: true, vertical: false)
                }
                configuration.cta.fixedSize(horizontal: true, vertical: false)
            }
            .padding(configuration.spacing(.md))
        }
    }
}

#Preview("StickyBookingBarStyle — presets × light/dark") {
    let priced = StickyBookingBar("Book now") { }
        .note("2 rooms · 4 nights").original(12_000).discountBadge("-20%").price(9_600).ctaIcon("arrow.right")
    let withSecondary = StickyBookingBar("Continue") { }
        .price(4_320).note("2 travellers").secondaryAction("Hold fare") { }
    let noPrice = StickyBookingBar("Confirm") { }
        .secondaryAction("Cancel") { }
    return PreviewMatrix("StickyBookingBarStyle") {
        PreviewCase("Standard (default)") { priced }
        PreviewCase("Standard · with secondary") { withSecondary }
        PreviewCase("Stacked") { priced.stickyBookingBarStyle(.stacked) }
        PreviewCase("Stacked · with secondary") { withSecondary.stickyBookingBarStyle(.stacked) }
        PreviewCase("Split · action pair") { withSecondary.stickyBookingBarStyle(.split) }
        PreviewCase("Split · no price") { noPrice.stickyBookingBarStyle(.split) }
        PreviewCase("Custom (in-preview)") { withSecondary.stickyBookingBarStyle(RibbonStickyBookingBarStyle()) }
    }
}
