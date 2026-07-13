//
//  RecentSearchRowStyle.swift
//  ThemeKit
//
//  The styling hook for ``RecentSearchRow`` (ADR-0004): the configuration hands
//  styles the *typed search summary* (route, caption strings, trailing actions),
//  not pre-laid content, so a style owns the entire arrangement. Four built-ins
//  — the first three map 1:1 to the former ``RecentSearchVariant`` cases:
//
//    .plain     flush list row, no surface — today's default, verbatim.
//    .bordered  the row on a hairline-bordered rounded surface.
//    .pill      fully-rounded capsule surface (the "mini search bar"), no hairline.
//    .card      vertical tile for a horizontally scrolling recents carousel.
//
//      RecentSearchRow(from: "IST", to: "AYT") { rerun() }
//          .roundTrip().dates("18 – 27 Jul")
//          .recentSearchRowStyle(.card)
//
//  Component style arranges content; token theme colors everything. There is no
//  motion in this component, so styles never touch the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``RecentSearchRowStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no caption → route only, no trailing action → a
/// plain chevron, no leading icon → no tile and no reserved space).
public struct RecentSearchRowConfiguration {
    /// Departure airport / city ("IST").
    public let from: String
    /// Arrival airport / city ("AYT").
    public let to: String
    /// Round-trip route — the built-ins draw a ⇄ arrow instead of → (multi-city
    /// chains always render one-way arrows; see ``routeStops``).
    public let roundTrip: Bool
    /// Intermediate stops for a multi-city route (``RecentSearchRow/via(_:)``).
    public let viaCodes: [String]
    /// Preformatted dates caption ("18 – 27 Jul"); combine via ``caption``.
    public let dates: String?
    /// Preformatted passengers caption ("2 adults · Economy").
    public let passengers: String?
    /// Leading icon-tile glyph; `nil` = no tile (e.g. the search pill). Ignored
    /// when the ``leading`` slot is set.
    public let systemImage: String?
    /// Custom replacement for the leading icon tile (an avatar, a flag…).
    public let leading: AnyView?
    /// The row's primary tap — re-runs the search. Every built-in wraps its
    /// whole surface in a button that calls this.
    public let action: () -> Void
    /// Trailing filled search button; takes precedence over ``onRemove``.
    public let onSearch: (() -> Void)?
    /// Trailing remove (✕) button; `nil` (with no ``onSearch``) = a chevron.
    public let onRemove: (() -> Void)?
    /// Fill color of the ``onSearch`` button (default `.neutral` ink).
    public let searchAccent: SemanticColor
    /// Brand tint for the leading icon tile; `nil` = the neutral tile.
    public let accent: SemanticColor?
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Explicit corner-radius role, or `nil` for the style's own default
    /// (resolve via ``radius(default:)`` — `.bordered` uses `.field`,
    /// `.card` uses `.box`).
    public let radiusRole: Theme.RadiusRole?
    /// Size ramp of the leading icon tile.
    public let tileSize: RecentSearchTileSize
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — the built-ins render
    /// preformatted strings, but custom styles that format dates/numbers must
    /// use it so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// The full route — origin, any `via` codes, destination.
    public var routeStops: [String] { [from] + viaCodes + [to] }

    /// The dates + passengers captions joined with a middot; `nil` when empty.
    public var caption: String? {
        let joined = [dates, passengers].compactMap { $0 }.joined(separator: " · ")
        return joined.isEmpty ? nil : joined
    }

    /// The row's spoken summary — route, via stops, caption. Built-ins apply it
    /// to their primary button so custom trailing controls stay reachable.
    public var accessibilitySummary: String {
        String(themeKit: "\(from) to \(to)")
            + (viaCodes.isEmpty ? "" : ", " + String(themeKit: "via \(viaCodes.joined(separator: ", "))"))
            + (caption.map { ", " + $0 } ?? "")
    }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// The explicit `radius(_:)` override, or the style's own default.
    public func radius(default fallback: Theme.RadiusRole) -> Theme.RadiusRole {
        radiusRole ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the row.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }
}

// MARK: - Protocol

/// Defines a `RecentSearchRow`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's search summary. Set one with
/// `.recentSearchRowStyle(_:)`; the default is ``PlainRecentSearchRowStyle``.
public protocol RecentSearchRowStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: RecentSearchRowConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// The leading affordance — the custom ``RecentSearchRowConfiguration/leading``
/// slot when set, else the ``IconTile`` glyph, else nothing.
private struct RecentSearchRowLeading: View {
    let configuration: RecentSearchRowConfiguration

    var body: some View {
        if let leading = configuration.leading {
            leading
        } else if let systemImage = configuration.systemImage {
            IconTile(systemImage)
                .size(configuration.tileSize.tile)
                .iconSize(configuration.tileSize.icon)
                .accent(configuration.accent)
        }
    }
}

/// The route — a from → to pair, or a multi-city chain when `via(_:)` is set
/// (IST → FRA → JFK). Multi-city always renders one-way arrows.
private struct RecentSearchRowRouteLine: View {
    @Environment(\.theme) private var theme
    let configuration: RecentSearchRowConfiguration

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(configuration.routeStops.enumerated()), id: \.offset) { i, code in
                if i > 0 { arrow }
                Text(code).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)).lineLimit(1)
            }
        }
    }

    private var arrow: some View {
        Image(systemName: configuration.roundTrip && configuration.viaCodes.isEmpty
                ? "arrow.left.arrow.right"
                : "arrow.right")
            .font(.system(size: 12, weight: .semibold))
            .foregroundStyle(theme.text(.textTertiary))
            .mirrorsInRTL()
    }
}

/// The trailing control — the filled search button (wins), the remove ✕, or,
/// in row-shaped styles, a plain chevron.
private struct RecentSearchRowTrailing: View {
    @Environment(\.theme) private var theme
    let configuration: RecentSearchRowConfiguration
    var showsChevron = true

    var body: some View {
        if let onSearch = configuration.onSearch {
            ThemeButton(action: onSearch)
                .icon(leading: "magnifyingglass")
                .shape(.circle)
                .color(configuration.searchAccent)
                .size(.small)
                .accessibilityLabel(String(themeKit: "Search"))
        } else if let onRemove = configuration.onRemove {
            Button { onRemove() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(theme.text(.textTertiary))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Remove"))
        } else if showsChevron {
            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(theme.text(.textTertiary))
                .mirrorsInRTL()
        }
    }
}

/// The horizontal row shared by `.plain` / `.bordered` / `.pill` — today's
/// ``RecentSearchRow`` body extracted verbatim; the chrome case only changes
/// the surface fill, hairline and leading inset.
private struct RecentSearchRowListChrome: View {
    enum Chrome { case plain, bordered, pill }

    @Environment(\.theme) private var theme
    let configuration: RecentSearchRowConfiguration
    let chrome: Chrome

    private var shape: AnyShape {
        chrome == .pill
            ? AnyShape(Capsule(style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: configuration.radius(default: .field).value, style: .continuous))
    }
    private var hasLeading: Bool { configuration.leading != nil || configuration.systemImage != nil }

    var body: some View {
        Button(action: configuration.action) {
            HStack(spacing: configuration.spacing(.sm)) {
                RecentSearchRowLeading(configuration: configuration)
                VStack(alignment: .leading, spacing: 2) {
                    RecentSearchRowRouteLine(configuration: configuration)
                    if let caption = configuration.caption {
                        Text(caption).textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 6)
                RecentSearchRowTrailing(configuration: configuration)
            }
            // Uniform tap padding, except the pill "mini search bar" (no leading
            // tile) insets its content from the left (Figma pl-24 · pr-8 · py-8).
            .padding(.vertical, configuration.spacing(.sm))
            .padding(.trailing, configuration.spacing(.sm))
            .padding(.leading, configuration.spacing(chrome == .pill && !hasLeading ? .base : .sm))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                chrome == .plain ? .clear : theme.background(configuration.surface(default: .bgBase)),
                in: shape)
            .overlay { if chrome == .bordered { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) } }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.accessibilitySummary)
    }
}

// MARK: - .plain

/// Today's ``RecentSearchRow`` look, extracted verbatim: a flush list row —
/// leading tile, route + caption, trailing control — with no surface. Default.
public struct PlainRecentSearchRowStyle: RecentSearchRowStyle {
    public init() {}
    public func makeBody(configuration: RecentSearchRowConfiguration) -> some View {
        RecentSearchRowListChrome(configuration: configuration, chrome: .plain)
    }
}

// MARK: - .bordered

/// The row on a hairline-bordered rounded surface (`surface(_:)` fill, default
/// `.bgBase`; `radius(_:)` role, default `.field`) — the standalone card form.
public struct BorderedRecentSearchRowStyle: RecentSearchRowStyle {
    public init() {}
    public func makeBody(configuration: RecentSearchRowConfiguration) -> some View {
        RecentSearchRowListChrome(configuration: configuration, chrome: .bordered)
    }
}

// MARK: - .pill

/// A fully-rounded capsule surface that sits on a colored band — the search
/// summary "mini bar". Fills with `surface(_:)` and drops the hairline; with no
/// leading tile the content insets further from the leading edge.
public struct PillRecentSearchRowStyle: RecentSearchRowStyle {
    public init() {}
    public func makeBody(configuration: RecentSearchRowConfiguration) -> some View {
        RecentSearchRowListChrome(configuration: configuration, chrome: .pill)
    }
}

// MARK: - .card

/// A vertical tile for a horizontally scrolling recents carousel: leading tile
/// and trailing control on top, route + caption below, on a hairline-bordered
/// `.box` surface. Give carousel tiles a width from the outside.
public struct CardRecentSearchRowStyle: RecentSearchRowStyle {
    public init() {}
    public func makeBody(configuration: RecentSearchRowConfiguration) -> some View {
        CardRecentSearchRowChrome(configuration: configuration)
    }
}

private struct CardRecentSearchRowChrome: View {
    @Environment(\.theme) private var theme
    let configuration: RecentSearchRowConfiguration

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: configuration.radius(default: .box).value, style: .continuous)
    }

    var body: some View {
        Button(action: configuration.action) {
            VStack(alignment: .leading, spacing: configuration.spacing(.sm)) {
                HStack(alignment: .top, spacing: configuration.spacing(.sm)) {
                    RecentSearchRowLeading(configuration: configuration)
                    Spacer(minLength: 0)
                    // Search wins over remove (the row presets' precedence); no
                    // chevron — the whole tile is the tap affordance.
                    RecentSearchRowTrailing(configuration: configuration, showsChevron: false)
                }
                VStack(alignment: .leading, spacing: 2) {
                    RecentSearchRowRouteLine(configuration: configuration)
                    if let caption = configuration.caption {
                        Text(caption).textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                            .lineLimit(2)
                    }
                }
            }
            .padding(configuration.spacing(.md))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(theme.background(configuration.surface(default: .bgBase)), in: shape)
            .overlay { shape.stroke(theme.border(.borderPrimary), lineWidth: 1) }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(configuration.accessibilitySummary)
    }
}

// MARK: - Static accessors

public extension RecentSearchRowStyle where Self == PlainRecentSearchRowStyle {
    /// Flush list row, no surface — today's look. The default.
    static var plain: PlainRecentSearchRowStyle { PlainRecentSearchRowStyle() }
}
public extension RecentSearchRowStyle where Self == BorderedRecentSearchRowStyle {
    /// The row on a hairline-bordered rounded surface.
    static var bordered: BorderedRecentSearchRowStyle { BorderedRecentSearchRowStyle() }
}
public extension RecentSearchRowStyle where Self == PillRecentSearchRowStyle {
    /// Fully-rounded capsule surface — the "mini search bar", no hairline.
    static var pill: PillRecentSearchRowStyle { PillRecentSearchRowStyle() }
}
public extension RecentSearchRowStyle where Self == CardRecentSearchRowStyle {
    /// Vertical tile for a recents carousel: tile top, route + caption below.
    static var card: CardRecentSearchRowStyle { CardRecentSearchRowStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyRecentSearchRowStyle: RecentSearchRowStyle {
    private let _makeBody: @MainActor (RecentSearchRowConfiguration) -> AnyView
    init<S: RecentSearchRowStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: RecentSearchRowConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct RecentSearchRowStyleKey: EnvironmentKey {
    static let defaultValue = AnyRecentSearchRowStyle(PlainRecentSearchRowStyle())
}

extension EnvironmentValues {
    var recentSearchRowStyle: AnyRecentSearchRowStyle {
        get { self[RecentSearchRowStyleKey.self] }
        set { self[RecentSearchRowStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``RecentSearchRowStyle`` for `RecentSearchRow`s in this view and
    /// its descendants — a recents list sets it once for every row.
    func recentSearchRowStyle<S: RecentSearchRowStyle>(_ style: sending S) -> some View {
        environment(\.recentSearchRowStyle, AnyRecentSearchRowStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a one-line route chip on a soft accent capsule, caption dropped.
private struct ChipRecentSearchRowStyle: RecentSearchRowStyle {
    func makeBody(configuration: RecentSearchRowConfiguration) -> some View {
        ChipChrome(configuration: configuration)
    }

    private struct ChipChrome: View {
        @Environment(\.theme) private var theme
        let configuration: RecentSearchRowConfiguration

        var body: some View {
            Button(action: configuration.action) {
                HStack(spacing: configuration.spacing(.xs)) {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.resolve(configuration.accent ?? .neutral).base)
                    RecentSearchRowRouteLine(configuration: configuration)
                }
                .padding(.vertical, configuration.spacing(.xs))
                .padding(.horizontal, configuration.spacing(.sm))
                .background(theme.resolve(configuration.accent ?? .neutral).soft, in: Capsule(style: .continuous))
                .contentShape(Capsule(style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(configuration.accessibilitySummary)
        }
    }
}

#Preview("RecentSearchRowStyle — presets × light/dark") {
    PreviewMatrix("RecentSearchRowStyle") {
        PreviewCase("Plain (default)") {
            RecentSearchRow(from: "IST", to: "AYT") { }
                .roundTrip().dates("18 – 27 Jul").passengers("2 adults · Economy").onRemove { }
        }
        PreviewCase("Bordered") {
            RecentSearchRow(from: "IST", to: "LHR") { }
                .dates("5 Sep").passengers("1 adult")
                .recentSearchRowStyle(.bordered)
        }
        PreviewCase("Pill · mini search bar") {
            RecentSearchRow(from: "Istanbul", to: "Antalya") { }
                .icon(nil).dates("14 Jan").passengers("7")
                .surface(.bgWhite).onSearch { }
                .padding(Theme.SpacingKey.sm.value)
                .background(SemanticColor.primary.solid)
                .recentSearchRowStyle(.pill)
        }
        PreviewCase("Card · carousel tile") {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                RecentSearchRow(from: "IST", to: "JFK") { }
                    .via(["FRA"]).dates("3 Nov").passengers("1 adult · Business").onRemove { }
                    .frame(width: 220)
                RecentSearchRow(from: "SAW", to: "AMS") { }
                    .roundTrip().dates("9 – 16 Dec").accent(.info)
                    .frame(width: 180)
            }
            .recentSearchRowStyle(.card)
        }
        PreviewCase("Custom (in-preview)") {
            RecentSearchRow(from: "IST", to: "AYT") { }
                .roundTrip().dates("18 – 27 Jul")
                .recentSearchRowStyle(ChipRecentSearchRowStyle())
        }
    }
}
