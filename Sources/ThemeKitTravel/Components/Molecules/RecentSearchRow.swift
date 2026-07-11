//
//  RecentSearchRow.swift
//  ThemeKit
//
//  Molecule. A recent / saved search summary — the route (from → to, one-way or
//  round-trip), a dates + passengers caption, and a trailing chevron or remove
//  button. Tap to re-run. Token-bound.
//
//  ```swift
//  RecentSearchRow(from: "IST", to: "AYT") { rerun() }
//      .roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { remove() }
//  ```
//

import SwiftUI
import ThemeKit

/// Chrome of a ``RecentSearchRow``: a flush `.plain` list row (default), a
/// `.bordered` card, or a fully-rounded `.pill` capsule (the mini search bar).
/// Consolidates the `.bordered()` / `.pill()` boolean pair — the previously
/// silently-resolved `.bordered().pill()` conflict is unrepresentable.
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
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

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
    private var variant: RecentSearchVariant = .plain
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var radiusRole: Theme.RadiusRole = .field
    private var tileSize: RecentSearchTileSize = .md
    private var viaCodes: [String] = []
    private var customLeading: AnyView?

    public init(from: String, to: String, action: @escaping () -> Void = {}) {   // R1
        self.from = from
        self.to = to
        self.action = action
    }

    private var bordered: Bool { variant == .bordered }
    private var pill: Bool { variant == .pill }

    private var shape: AnyShape {
        pill
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous))
    }
    private var caption: String? {
        [dates, passengers].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }
    /// The full route — origin, any `via` codes, destination.
    private var routeStops: [String] { [from] + viaCodes + [to] }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                if let customLeading {
                    customLeading
                } else if let systemImage {
                    IconTile(systemImage).size(tileSize.tile).iconSize(tileSize.icon).accent(accent)
                }
                VStack(alignment: .leading, spacing: 2) {
                    routeLine
                    if let caption { Text(caption).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 6)
                trailing
            }
            // Uniform tap padding, except the pill "mini search bar" (no leading
            // tile) insets its content from the left (Figma pl-24 · pr-8 · py-8).
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .padding(.trailing, density.scale(Theme.SpacingKey.sm.value))
            .padding(.leading, density.scale(pill && systemImage == nil && customLeading == nil
                                             ? Theme.SpacingKey.base.value
                                             : Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((bordered || pill) ? theme.background(surfaceKey) : .clear, in: shape)
            .overlay { if bordered { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            String(themeKit: "\(from) to \(to)")
                + (viaCodes.isEmpty ? "" : ", " + String(themeKit: "via \(viaCodes.joined(separator: ", "))"))
                + (caption.map { ", " + $0 } ?? "")
        )
    }

    /// The route — a from → to pair, or a multi-city chain when ``via(_:)`` is set
    /// (IST → FRA → JFK). Multi-city always renders one-way arrows.
    private var routeLine: some View {
        HStack(spacing: 6) {
            ForEach(Array(routeStops.enumerated()), id: \.offset) { i, code in
                if i > 0 { routeArrow }
                Text(code).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
            }
        }
    }

    private var routeArrow: some View {
        Image(systemName: roundTrip && viaCodes.isEmpty ? "arrow.left.arrow.right" : "arrow.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.text(.textTertiary))
            .mirrorsInRTL()
    }

    @ViewBuilder private var trailing: some View {
        if let onSearch {
            ThemeButton(action: onSearch)
                .icon(leading: "magnifyingglass")
                .shape(.circle)
                .color(searchAccent)
                .size(.small)
                .accessibilityLabel(String(themeKit: "Search"))
        } else if let onRemove {
            Button { onRemove() } label: {
                Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }.buttonStyle(.plain).accessibilityLabel(String(themeKit: "Remove"))
        } else {
            Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
        }
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
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
    /// Chrome: a flush `.plain` list row (default), a `.bordered` card, or the
    /// fully-rounded `.pill` capsule. Consolidates `.bordered()` / `.pill()`.
    func variant(_ v: RecentSearchVariant) -> Self { copy { $0.variant = v } }
    /// Wrap in a bordered surface (default off — flush list row). Sugar for
    /// `.variant(.bordered)`.
    func bordered(_ on: Bool = true) -> Self { copy { $0.variant = on ? .bordered : .plain } }
    /// Fully-rounded **capsule** surface — a pill that sits on a colored band (the
    /// search-result mini bar). Fills with ``surface(_:)`` and drops the hairline.
    /// Sugar for `.variant(.pill)`.
    func pill(_ on: Bool = true) -> Self { copy { $0.variant = on ? .pill : .plain } }
    /// Surface fill of the bordered / pill variant (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Corner radius role of the `.bordered` variant (default `.field`).
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
        PreviewCase("Round trip") { RecentSearchRow(from: "IST", to: "AYT") { }.roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy") }
        PreviewCase("Removable") { RecentSearchRow(from: "SAW", to: "ESB") { }.dates("2 Aug").passengers("1 adult").onRemove { } }
        PreviewCase("Bordered") { RecentSearchRow(from: "IST", to: "LHR") { }.dates("5 Sep").passengers("1 adult").bordered() }
        PreviewCase("Bordered · box radius · large tile") {
            RecentSearchRow(from: "IST", to: "CDG") { }
                .dates("12 Oct").passengers("2 adults")
                .variant(.bordered).radius(.box).tileSize(.lg)
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
        .pill().surface(.bgWhite)
        .onSearch { }
        .padding()
        .frame(maxWidth: .infinity)
        .background(SemanticColor.primary.solid)
}
