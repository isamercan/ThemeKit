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
    private var bordered = false
    private var pill = false
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase

    public init(from: String, to: String, action: @escaping () -> Void = {}) {   // R1
        self.from = from
        self.to = to
        self.action = action
    }

    private var shape: AnyShape {
        pill
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
    private var caption: String? {
        [dates, passengers].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                if let systemImage { IconTile(systemImage).size(40).iconSize(16).accent(accent) }
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(from).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                        Image(systemName: roundTrip ? "arrow.left.arrow.right" : "arrow.right").font(.system(size: 12, weight: .semibold)).foregroundStyle(theme.text(.textTertiary)).mirrorsInRTL()
                        Text(to).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                    }
                    if let caption { Text(caption).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1) }
                }
                Spacer(minLength: 6)
                trailing
            }
            // Uniform tap padding, except the pill "mini search bar" (no leading
            // tile) insets its content from the left (Figma pl-24 · pr-8 · py-8).
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .padding(.trailing, density.scale(Theme.SpacingKey.sm.value))
            .padding(.leading, density.scale(pill && systemImage == nil
                                             ? Theme.SpacingKey.base.value
                                             : Theme.SpacingKey.sm.value))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background((bordered || pill) ? theme.background(surfaceKey) : .clear, in: shape)
            .overlay { if bordered && !pill { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(from) to \(to)\(caption.map { ", " + $0 } ?? "")")
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
    /// Wrap in a bordered surface (default off — flush list row).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }
    /// Fully-rounded **capsule** surface — a pill that sits on a colored band (the
    /// search-result mini bar). Fills with ``surface(_:)`` and drops the hairline.
    func pill(_ on: Bool = true) -> Self { copy { $0.pill = on } }
    /// Surface fill of the bordered / pill variant (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 4) {
        RecentSearchRow(from: "IST", to: "AYT") { }.roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy")
        RecentSearchRow(from: "SAW", to: "ESB") { }.dates("2 Aug").passengers("1 adult").onRemove { }
    }
    .padding()
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
