//
//  IconTileStyle.swift
//  ThemeKit
//  Created by İsa Mercan on 16.09.2026.
//
//  The `ButtonStyle`-shaped styling hook for `IconTile`. The chrome — glyph
//  size and colour, tile size, fill and outline — lives in an `IconTileStyle`
//  you set with `.iconTileStyle(_:)`, so a host design system can draw its own
//  icon discs and squares while `IconTile` keeps the rest.
//
//      IconTile { HostGlyph(.plane) }
//          .size(20).tileShape(.circle)
//          .iconTileStyle(HostIconDisc())
//
//  `IconTile` keeps: the glyph (an SF Symbol or any view), the size / icon
//  size / colour / corner / shape axes, and accessibility (the tile is
//  decorative, hidden from VoiceOver, on both paths).
//

import SwiftUI

/// The inputs an ``IconTileStyle`` renders: the tile's glyph, its raw SF Symbol
/// name when it has one, and the appearance axes set on the tile.
///
/// Fields a style doesn't use are simply ignored; new fields may be added in a
/// minor release.
public struct IconTileStyleConfiguration {
    /// The glyph, **un-fonted**: the SF Symbol image, or the view passed to
    /// `IconTile(glyph:)` as-is. A style sizes it (the default style applies
    /// `.font(.system(size: iconSize))`) and colours it.
    public let glyph: AnyView
    /// The SF Symbol name for `IconTile(_:)`, so a style can build the symbol
    /// its own way; `nil` for `IconTile(glyph:)`.
    public let systemImage: String?
    /// The edge length the caller asked for with `.size(_:)` (46 when unset),
    /// before the default chrome's 24pt floor. Never negative.
    public let requestedSize: CGFloat
    /// The edge length the default chrome draws: ``requestedSize``, at least 24.
    public let size: CGFloat
    /// The glyph point size (`.iconSize(_:)`, at least 8; 18 when unset).
    public let iconSize: CGFloat
    /// The corner role for the `.rounded` shape (`.cornerRadius(_:)`).
    public let cornerRadius: Theme.RadiusRole
    /// The tile's outline (`.tileShape(_:)`).
    public let shape: IconTileShape
    /// The semantic tint (`.accent(_:)`); when set the default style fills
    /// with its `bg` shade and draws the glyph in its `base` shade.
    public let accent: SemanticColor?
    /// The fill token used when no ``accent`` is set (`.background(_:)`).
    public let backgroundKey: Theme.BackgroundColorKey
    /// The glyph colour token used when no ``accent`` is set (`.iconColor(_:)`);
    /// `nil` means the default secondary text colour.
    public let iconColorKey: Theme.TextColorKey?
    /// Whether the tile is enabled (`.disabled(_:)` in the environment). The
    /// default style ignores it.
    public let isEnabled: Bool
}

/// Draws an icon tile. Implement `makeBody` to size and colour the
/// configuration's glyph and paint the tile around it. Set one with
/// `.iconTileStyle(_:)`; the default is ``DefaultIconTileStyle``.
///
/// The style draws; `IconTile` keeps the content and hides the result from
/// VoiceOver (a tile is decorative — the row around it carries the meaning).
///
/// The style applies to every `IconTile` below the view it's set on, including
/// the tiles ThemeKit composes inside other components (suggestion rows,
/// price-alert and agent-price cards, the travel edition's add-on and
/// recent-search rows). Set it on the tile itself to restyle only that tile.
///
/// ```swift
/// struct DiscIconTileStyle: IconTileStyle {
///     func makeBody(configuration: IconTileStyleConfiguration) -> some View {
///         DiscIconTileBody(configuration: configuration)
///     }
/// }
///
/// private struct DiscIconTileBody: View {
///     let configuration: IconTileStyleConfiguration
///     @Environment(\.theme) private var theme
///
///     var body: some View {
///         let hue = theme.resolve(configuration.accent ?? .neutral)
///         configuration.glyph
///             .font(.system(size: configuration.requestedSize * 0.5))
///             .foregroundStyle(hue.onSolid)
///             .frame(width: configuration.requestedSize, height: configuration.requestedSize)
///             .background(hue.solid, in: Circle())
///     }
/// }
/// ```
public protocol IconTileStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: IconTileStyleConfiguration) -> Body
}

/// The stock tile chrome — exactly the look `IconTile` draws with no style set:
/// the glyph at `iconSize`, tinted by the accent's `base` shade (else the icon
/// colour token, else secondary text), on a `size`-square tile filled with the
/// accent's `bg` shade (else the background token), as a continuous rounded
/// square at the corner role or a circle. Ignores `isEnabled`. Reads the
/// active `\.theme`, so an injected theme re-skins it too.
public struct DefaultIconTileStyle: IconTileStyle, Sendable {
    public init() {}
    public func makeBody(configuration: IconTileStyleConfiguration) -> some View {
        DefaultIconTileChrome(configuration: configuration)
    }
}

private struct DefaultIconTileChrome: View {
    let configuration: IconTileStyleConfiguration
    @Environment(\.theme) private var theme

    // Mirrors `IconTile`'s default path modifier for modifier, so
    // `.iconTileStyle(.default)` renders the same pixels.
    var body: some View {
        let background = IconTilePaint.background(
            accent: configuration.accent, backgroundKey: configuration.backgroundKey, theme: theme)
        let tile = configuration.glyph
            .font(.system(size: configuration.iconSize))
            .foregroundStyle(IconTilePaint.foreground(
                accent: configuration.accent, iconColorKey: configuration.iconColorKey, theme: theme))
            .frame(width: configuration.size, height: configuration.size)
        switch configuration.shape {
        case .rounded:
            tile.background(background, in: RoundedRectangle(cornerRadius: configuration.cornerRadius.value, style: .continuous))
        case .circle:
            tile.background(background, in: Circle())
        }
    }
}

public extension IconTileStyle where Self == DefaultIconTileStyle {
    /// The stock tile chrome (today's `IconTile` look).
    static var `default`: DefaultIconTileStyle { DefaultIconTileStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyIconTileStyle: IconTileStyle {
    /// `true` only for the environment key's stock default below. `IconTile`
    /// checks it: while the environment still carries the default it draws its
    /// own chrome, unchanged; any style set with `.iconTileStyle(_:)` —
    /// including `.default` — is unmarked and goes through `makeBody`.
    let isDefault: Bool
    private let _makeBody: @MainActor (IconTileStyleConfiguration) -> AnyView
    init<S: IconTileStyle>(_ style: sending S, isDefault: Bool = false) {
        self.isDefault = isDefault
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: IconTileStyleConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct IconTileStyleKey: EnvironmentKey {
    static let defaultValue = AnyIconTileStyle(DefaultIconTileStyle(), isDefault: true)
}

extension EnvironmentValues {
    var iconTileStyle: AnyIconTileStyle {
        get { self[IconTileStyleKey.self] }
        set { self[IconTileStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``IconTileStyle`` for `IconTile`s in this view and its descendants.
    func iconTileStyle<S: IconTileStyle>(_ style: sending S) -> some View {
        environment(\.iconTileStyle, AnyIconTileStyle(style))
    }
}
