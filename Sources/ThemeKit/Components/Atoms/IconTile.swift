//
//  IconTile.swift
//  ThemeKit
//
//  Atom. An SF Symbol on a rounded, token-tinted tile — the leading affordance of
//  suggestion / add-on / alert / recent-search rows. Extracted so those rows compose
//  one piece instead of repeating the same inline block. Token-bound.
//
//  ```swift
//  IconTile("airplane")                          // neutral tile
//  IconTile("suitcase.fill").accent(.turquoise)  // brand-tinted
//  ```
//

import SwiftUI

public struct IconTile: View {
    @Environment(\.theme) private var theme

    private let systemImage: String
    // Appearance — mutated only through the modifiers below (R2).
    private var size: CGFloat = 46
    private var iconSize: CGFloat = 18
    private var backgroundKey: Theme.BackgroundColorKey = .bgElevatorTertiary
    private var iconColorKey: Theme.TextColorKey?
    private var accent: SemanticColor?
    private var cornerRole: Theme.RadiusRole = .selector

    public init(_ systemImage: String) { self.systemImage = systemImage }   // R1

    private var bg: Color { accent.map { $0.bg } ?? theme.background(backgroundKey) }
    private var fg: Color { accent.map { $0.base } ?? iconColorKey.map { theme.text($0) } ?? theme.text(.textSecondary) }

    public var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: iconSize))
            .foregroundStyle(fg)
            .frame(width: size, height: size)
            .background(bg, in: RoundedRectangle(cornerRadius: cornerRole.value, style: .continuous))
            .accessibilityHidden(true)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension IconTile {
    func size(_ value: CGFloat) -> Self { copy { $0.size = max(24, value) } }
    func iconSize(_ value: CGFloat) -> Self { copy { $0.iconSize = max(8, value) } }
    /// Tile background (token key, default `.bgElevatorTertiary`).
    func background(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.backgroundKey = key } }
    /// Icon colour (text token key).
    func iconColor(_ key: Theme.TextColorKey) -> Self { copy { $0.iconColorKey = key } }
    /// Brand-tint the tile (bg = accent.bg, icon = accent.base).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.cornerRole = role } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("IconTile") {
        PreviewCase("Neutral") { IconTile("airplane") }
        PreviewCase("Accent") { IconTile("suitcase.fill").accent(.turquoise) }
        PreviewCase("Warning, sized") { IconTile("bell.fill").accent(.warning).size(40) }
    }
}
