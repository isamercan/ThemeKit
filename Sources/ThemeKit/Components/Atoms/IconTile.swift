//
//  IconTile.swift
//  ThemeKit
//
//  Atom. A glyph on a rounded (or circular), token-tinted tile — the leading
//  affordance of suggestion / add-on / alert / recent-search rows. Extracted so
//  those rows compose one piece instead of repeating the same inline block.
//  Token-bound. The glyph is an SF Symbol, or any view via `init(glyph:)`.
//
//  ```swift
//  IconTile("airplane")                          // neutral tile
//  IconTile("suitcase.fill").accent(.turquoise)  // brand-tinted
//  IconTile { HostGlyph(.bell) }.tileShape(.circle)
//  ```
//
//  The tile's chrome is drawn by the active ``IconTileStyle`` when one is set
//  with `.iconTileStyle(_:)`.
//

import SwiftUI

/// The outline of an ``IconTile``.
public enum IconTileShape: Sendable, CaseIterable {
    /// A continuous rounded square at the tile's radius role (the default).
    case rounded
    /// A circle; the radius role is ignored.
    case circle
}

public struct IconTile: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.iconTileStyle) private var style

    private let systemImage: String?
    private let customGlyph: AnyView?
    // Appearance — mutated only through the modifiers below (R2).
    private var requestedSize: CGFloat = 46
    private var iconSize: CGFloat = 18
    private var backgroundKey: Theme.BackgroundColorKey = .bgElevatorTertiary
    private var iconColorKey: Theme.TextColorKey?
    private var accent: SemanticColor?
    private var cornerRole: Theme.RadiusRole = .selector
    private var shape: IconTileShape = .rounded

    public init(_ systemImage: String) {   // R1
        self.systemImage = systemImage
        self.customGlyph = nil
    }

    /// A tile around any glyph view — a host icon font, an asset image, an SF
    /// Symbol with its own rendering mode. Un-fonted glyphs pick up
    /// ``iconSize(_:)`` and the tile's foreground like the SF Symbol does.
    public init<Glyph: View>(@ViewBuilder glyph: () -> Glyph) {   // R1
        self.systemImage = nil
        self.customGlyph = AnyView(glyph())
    }

    /// The drawn edge: the requested size with the 24pt floor.
    private var size: CGFloat { max(24, requestedSize) }
    private var bg: Color {
        IconTilePaint.background(accent: accent, backgroundKey: backgroundKey, theme: theme)
    }
    private var fg: Color {
        IconTilePaint.foreground(accent: accent, iconColorKey: iconColorKey, theme: theme)
    }

    public var body: some View {
        if style.isDefault {
            defaultTile
                .accessibilityHidden(true)
        } else {
            // The style draws; the tile stays decorative to VoiceOver.
            style.makeBody(configuration: configuration)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var defaultTile: some View {
        let tile = glyph
            .font(.system(size: iconSize))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
        switch shape {
        case .rounded:
            tile.background(bg, in: RoundedRectangle(cornerRadius: cornerRole.value, style: .continuous))
        case .circle:
            tile.background(bg, in: Circle())
        }
    }

    /// The un-fonted glyph: the init's view, or the SF Symbol.
    @ViewBuilder private var glyph: some View {
        if let customGlyph {
            customGlyph
        } else if let systemImage {
            Image(systemName: systemImage)
        }
    }

    private var configuration: IconTileStyleConfiguration {
        IconTileStyleConfiguration(
            glyph: AnyView(glyph),
            systemImage: systemImage,
            requestedSize: requestedSize,
            size: size,
            iconSize: iconSize,
            cornerRadius: cornerRole,
            shape: shape,
            accent: accent,
            backgroundKey: backgroundKey,
            iconColorKey: iconColorKey,
            isEnabled: isEnabled)
    }
}

/// The tile fill and glyph colour the stock chrome resolves. Shared by
/// `IconTile`'s default path and ``DefaultIconTileStyle``.
enum IconTilePaint {
    static func background(accent: SemanticColor?, backgroundKey: Theme.BackgroundColorKey, theme: Theme) -> Color {
        accent.map { theme.resolve($0).bg } ?? theme.background(backgroundKey)
    }
    static func foreground(accent: SemanticColor?, iconColorKey: Theme.TextColorKey?, theme: Theme) -> Color {
        accent.map { theme.resolve($0).base } ?? iconColorKey.map { theme.text($0) } ?? theme.text(.textSecondary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension IconTile {
    /// Tile edge length in points. The default chrome never draws a tile
    /// smaller than 24pt; an ``IconTileStyle`` receives the requested value
    /// too (a negative one as 0), and may honour smaller sizes.
    func size(_ value: CGFloat) -> Self { copy { $0.requestedSize = max(0, value) } }
    func iconSize(_ value: CGFloat) -> Self { copy { $0.iconSize = max(8, value) } }
    /// Tile background (token key, default `.bgElevatorTertiary`).
    func background(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.backgroundKey = key } }
    /// Icon colour (text token key).
    func iconColor(_ key: Theme.TextColorKey) -> Self { copy { $0.iconColorKey = key } }
    /// Brand-tint the tile (bg = accent.bg, icon = accent.base).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.cornerRole = role } }
    /// The tile's outline: `.rounded` (default, at the ``cornerRadius(_:)``
    /// role) or `.circle`.
    func tileShape(_ shape: IconTileShape) -> Self { copy { $0.shape = shape } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    /// Proof of external implementability: a flat outlined disc that honours
    /// sizes under the default 24pt floor.
    struct RingIconTileStyle: IconTileStyle {
        func makeBody(configuration: IconTileStyleConfiguration) -> some View {
            RingIconTileBody(configuration: configuration)
        }
    }
    struct RingIconTileBody: View {
        let configuration: IconTileStyleConfiguration
        @Environment(\.theme) private var theme

        var body: some View {
            let hue = theme.resolve(configuration.accent ?? .primary)
            configuration.glyph
                .font(.system(size: configuration.requestedSize * 0.5))
                .foregroundStyle(hue.base)
                .frame(width: configuration.requestedSize, height: configuration.requestedSize)
                .overlay(Circle().strokeBorder(hue.border, lineWidth: 1))
        }
    }

    return PreviewMatrix("IconTile") {
        PreviewCase("Neutral") { IconTile("airplane") }
        PreviewCase("Accent") { IconTile("suitcase.fill").accent(.turquoise) }
        PreviewCase("Warning, sized") { IconTile("bell.fill").accent(.warning).size(40) }
        PreviewCase("Circle + custom glyph") {
            HStack {
                IconTile("heart.fill").accent(.pink).tileShape(.circle)
                IconTile { Text("A").textStyle(.labelBase700) }.accent(.info).tileShape(.circle)
                IconTile { Image(systemName: "star.fill").symbolRenderingMode(.multicolor) }
            }
        }
        PreviewCase("Custom style (16 / 24 / 32)") {
            HStack {
                IconTile("bell.fill").size(16)
                IconTile("bell.fill").accent(.success).size(24)
                IconTile { Image(systemName: "gift.fill") }.accent(.purple).size(32)
            }
            .iconTileStyle(RingIconTileStyle())
        }
    }
}
