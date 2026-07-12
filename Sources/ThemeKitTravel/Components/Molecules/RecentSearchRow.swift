//
//  RecentSearchRow.swift
//  ThemeKit
//
//  Molecule. A recent / saved search summary — the route (from → to, one-way or
//  round-trip), a dates + passengers caption, and a trailing chevron or remove
//  button. Tap to re-run. Presentation is style-driven (``RecentSearchRowStyle``,
//  ADR-0004) — set once per list via `.recentSearchRowStyle(_:)`. Token-bound.
//
//  ```swift
//  RecentSearchRow(from: "IST", to: "AYT") { rerun() }
//      .roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { remove() }
//      .recentSearchRowStyle(.card)      // .plain (default) / .bordered / .pill
//  ```
//

import SwiftUI
import ThemeKit

/// Chrome of a ``RecentSearchRow``: a flush `.plain` list row (default), a
/// `.bordered` card, or a fully-rounded `.pill` capsule (the mini search bar).
///
/// Superseded by ``RecentSearchRowStyle`` (each case maps 1:1 to a preset —
/// `.plain`/`.bordered`/`.pill`, joined by the new `.card` tile); kept for
/// source compatibility until the next major, together with the deprecated
/// ``RecentSearchRow/variant(_:)`` / ``RecentSearchRow/bordered(_:)`` /
/// ``RecentSearchRow/pill(_:)`` modifiers.
public enum RecentSearchVariant: Sendable { case plain, bordered, pill }

/// Size ramp of the leading icon tile (internal 32/12 · 40/16 · 48/20 pt).
public enum RecentSearchTileSize: Sendable {
    case sm, md, lg

    var tile: CGFloat {
        switch self {
        case .sm: 32
        case .md: 40
        case .lg: 48
        }
    }
    var icon: CGFloat {
        switch self {
        case .sm: 12
        case .md: 16
        case .lg: 20
        }
    }
}

public struct RecentSearchRow: View {
    @Environment(\.recentSearchRowStyle) private var envStyle
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale

    private let from: String
    private let to: String
    private let action: () -> Void
    // Content/appearance — mutated only through the modifiers below (R2).
    private var roundTrip = false
    private var dates: String?
    private var passengers: String?
    private var systemImage: String? = "clock.arrow.circlepath"
    private var onRemove: (() -> Void)?
    private var onSearch: (() -> Void)?
    private var searchAccent: SemanticColor = .neutral
    private var accent: SemanticColor?
    /// `nil` → the style's own default surface (the built-ins use `.bgBase`).
    private var surfaceKey: Theme.BackgroundColorKey?
    /// `nil` → the style's own default role (`.bordered` uses `.field`, `.card` `.box`).
    private var radiusRole: Theme.RadiusRole?
    private var tileSize: RecentSearchTileSize = .md
    private var viaCodes: [String] = []
    private var customLeading: AnyView?
    /// Set by the deprecated ``variant(_:)`` / ``bordered(_:)`` / ``pill(_:)``
    /// modifiers — an explicitly chosen per-instance style wins over an
    /// ancestor's `.recentSearchRowStyle(_:)` (source-behavior stability
    /// during the enum's deprecation window, ADR-0004 §5).
    private var explicitStyle: AnyRecentSearchRowStyle?

    public init(from: String, to: String, action: @escaping () -> Void = {}) {   // R1
        self.from = from
        self.to = to
        self.action = action
    }

    public var body: some View {
        // The arrangement is owned by the active `RecentSearchRowStyle`; the
        // component only gathers its typed summary. No motion to resolve here.
        let configuration = RecentSearchRowConfiguration(
            from: from,
            to: to,
            roundTrip: roundTrip,
            viaCodes: viaCodes,
            dates: dates,
            passengers: passengers,
            systemImage: systemImage,
            leading: customLeading,
            action: action,
            onSearch: onSearch,
            onRemove: onRemove,
            searchAccent: searchAccent,
            accent: accent,
            surfaceKey: surfaceKey,
            radiusRole: radiusRole,
            tileSize: tileSize,
            density: density,
            locale: locale)
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension RecentSearchRow {
    /// Round-trip route (⇄ arrow) instead of one-way (→).
    func roundTrip(_ on: Bool = true) -> Self { copy { $0.roundTrip = on } }
    func dates(_ text: String?) -> Self { copy { $0.dates = text } }
    func passengers(_ text: String?) -> Self { copy { $0.passengers = text } }
    /// Leading icon-tile glyph, or `nil` to drop the tile (e.g. a search pill).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }
    /// Adds a trailing remove (✕) button instead of the chevron.
    func onRemove(_ action: @escaping () -> Void) -> Self { copy { $0.onRemove = action } }
    /// Trailing filled **search** button (magnifier) instead of the chevron/remove —
    /// turns the row into a "mini search bar" summary that re-runs the search when
    /// tapped. Takes precedence over ``onRemove(_:)``.
    func onSearch(_ action: @escaping () -> Void) -> Self { copy { $0.onSearch = action } }
    /// Fill color of the ``onSearch(_:)`` button (default `.neutral` ink).
    func searchAccent(_ color: SemanticColor) -> Self { copy { $0.searchAccent = color } }
    /// Brand-tints the leading icon tile (default: neutral tile).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Chrome — superseded by the style axis: prefer
    /// `.recentSearchRowStyle(.plain/.bordered/.pill)`, settable once per list
    /// via the environment (and joined by the new `.card` tile). This modifier
    /// keeps working and, when called, wins over an ancestor's environment style.
    @available(*, deprecated, message: "Use .recentSearchRowStyle(.plain/.bordered/.pill) instead")
    func variant(_ v: RecentSearchVariant) -> Self {
        copy {
            switch v {
            case .plain: $0.explicitStyle = AnyRecentSearchRowStyle(PlainRecentSearchRowStyle())
            case .bordered: $0.explicitStyle = AnyRecentSearchRowStyle(BorderedRecentSearchRowStyle())
            case .pill: $0.explicitStyle = AnyRecentSearchRowStyle(PillRecentSearchRowStyle())
            }
        }
    }
    /// Wrap in a bordered surface (default off — flush list row). Superseded by
    /// `.recentSearchRowStyle(.bordered)`; when called it wins over an
    /// ancestor's environment style.
    @available(*, deprecated, message: "Use .recentSearchRowStyle(.bordered) instead")
    func bordered(_ on: Bool = true) -> Self {
        copy {
            $0.explicitStyle = on
                ? AnyRecentSearchRowStyle(BorderedRecentSearchRowStyle())
                : AnyRecentSearchRowStyle(PlainRecentSearchRowStyle())
        }
    }
    /// Fully-rounded **capsule** surface — a pill that sits on a colored band (the
    /// search-result mini bar). Fills with ``surface(_:)`` and drops the hairline.
    /// Superseded by `.recentSearchRowStyle(.pill)`; when called it wins over an
    /// ancestor's environment style.
    @available(*, deprecated, message: "Use .recentSearchRowStyle(.pill) instead")
    func pill(_ on: Bool = true) -> Self {
        copy {
            $0.explicitStyle = on
                ? AnyRecentSearchRowStyle(PillRecentSearchRowStyle())
                : AnyRecentSearchRowStyle(PlainRecentSearchRowStyle())
        }
    }
    /// Surface fill of surfaced styles (background token key). When unset, the
    /// active ``RecentSearchRowStyle`` picks its own default (the built-ins
    /// use `.bgBase`; `.plain` draws no surface).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Corner-radius role of surfaced styles. When unset, the active style
    /// picks its own default (`.bordered` uses `.field`, `.card` uses `.box`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Intermediate stops for a multi-city route — renders IST → FRA → JFK
    /// instead of the fixed from → to pair.
    func via(_ codes: [String]) -> Self { copy { $0.viaCodes = codes } }
    /// Size ramp of the leading icon tile (default `.md`).
    func tileSize(_ s: RecentSearchTileSize) -> Self { copy { $0.tileSize = s } }
    /// Replaces the leading icon tile with custom content (an avatar, a flag…).
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.customLeading = AnyView(content()) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("RecentSearchRow") {
        PreviewCase("Round trip") {
            RecentSearchRow(from: "IST", to: "AYT") { }
                .roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy")
        }
        PreviewCase("Removable") {
            RecentSearchRow(from: "SAW", to: "ESB") { }.dates("2 Aug").passengers("1 adult").onRemove { }
        }
        PreviewCase("Bordered") {
            RecentSearchRow(from: "IST", to: "LHR") { }
                .dates("5 Sep").passengers("1 adult")
                .recentSearchRowStyle(.bordered)
        }
        PreviewCase("Bordered · box radius · large tile") {
            RecentSearchRow(from: "IST", to: "CDG") { }
                .dates("12 Oct").passengers("2 adults")
                .radius(.box).tileSize(.lg)
                .recentSearchRowStyle(.bordered)
        }
        PreviewCase("Multi-city via") {
            RecentSearchRow(from: "IST", to: "JFK") { }
                .via(["FRA"])
                .dates("3 Nov").passengers("1 adult · Business")
                .tileSize(.sm)
        }
        PreviewCase("Custom leading slot") {
            RecentSearchRow(from: "SAW", to: "AMS") { }
                .dates("9 Dec")
                .leading { Avatar(.initials("KL")).size(.sm) }
        }
    }
}

#Preview("Search summary pill") {
    // A "mini search bar" — no leading tile, capsule surface on a brand band,
    // trailing filled search button. Brand color comes from the theme, not here.
    RecentSearchRow(from: "Istanbul", to: "Antalya") { }
        .icon(nil)
        .dates("14 Jan").passengers("7")
        .surface(.bgWhite)
        .onSearch { }
        .recentSearchRowStyle(.pill)
        .padding()
        .frame(maxWidth: .infinity)
        .background(SemanticColor.primary.solid)
}
