//
//  SemanticColor.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A daisyUI-style semantic color the configurable components share. Each color
//  resolves to solid / soft / outline roles from the design tokens, so a single
//  `color:` + `variant:` pair drives backgrounds, foregrounds and borders.
//

import SwiftUI

public enum SemanticColor: String, CaseIterable, Sendable {
    case primary, neutral, info, success, warning, error
    case turquoise, orange, purple, pink
    /// daisyUI brand colors — backed by additive `palette.secondary/accent.*`
    /// ladders; fall back to `primary` when a theme doesn't define them.
    case secondary, accent

    // MARK: - Role accessors
    //
    // ADR-0006 Phase 0/2: the role→color logic lives ONCE in `Resolved`
    // (`SemanticColorResolved.swift`). These zero-arg accessors forward to
    // `resolved(in: .shared)`, so they stay byte-identical to before — but
    // they are `Theme.shared`-backed and unaware of a subtree's `.theme(_:)`
    // override. Deprecated in favor of `theme.resolve(color)` (a View body,
    // reads `@Environment(\.theme)`) or `color.resolved(in: theme)` (a helper
    // that already holds a `theme`) — either honors per-subtree re-theming.

    /// Background for the `solid` variant.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).solid")
    public var solid: Color { resolved(in: .shared).solid }

    /// Foreground on top of the `solid` background — **auto-contrasting**: a bright
    /// accent (amber, yellow, light primary) gets dark content, a deep one gets white,
    /// computed from the background's luminance rather than hardcoded per color.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).onSolid")
    public var onSolid: Color { resolved(in: .shared).onSolid }

    /// Light surface for the `soft` variant.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).soft")
    public var soft: Color { resolved(in: .shared).soft }

    /// Accent foreground for `soft` / `outline` / `ghost` variants.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).accent")
    public var accent: Color { resolved(in: .shared).accent }

    /// Border for the `outline` variant.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).border")
    public var border: Color { resolved(in: .shared).border }

    // MARK: - Ant-style ladder roles

    /// A step on the primitive 50..900 ladder (Ant's 10-shade palette).
    public enum Shade: Int, CaseIterable {
        case s50 = 50, s100 = 100, s200 = 200, s300 = 300, s400 = 400
        case s500 = 500, s600 = 600, s700 = 700, s800 = 800, s900 = 900
    }

    /// Resolve any ladder step for this color, e.g. `.primary.shade(.s700)`.
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).shade(_:)")
    public func shade(_ step: Shade) -> Color { resolved(in: .shared).shade(step) }

    /// Faint container background (Ant `colorXxxBg`, step 50).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).bg")
    public var bg: Color { resolved(in: .shared).bg }
    /// Container background, hovered/stronger (Ant `colorXxxBgHover`, step 100).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).bgHover")
    public var bgHover: Color { resolved(in: .shared).bgHover }
    /// Subtle border (Ant `colorXxxBorder`, step 200).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).borderSubtle")
    public var borderSubtle: Color { resolved(in: .shared).borderSubtle }
    /// Border, hovered (Ant `colorXxxBorderHover`, step 300).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).borderHover")
    public var borderHover: Color { resolved(in: .shared).borderHover }
    /// Solid fill, hovered — lighter than base (Ant `colorXxxHover`, step 400).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).hover")
    public var hover: Color { resolved(in: .shared).hover }
    /// The color itself (Ant `colorXxx`, step 500).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).base")
    public var base: Color { resolved(in: .shared).base }
    /// Solid fill, pressed/active — darker than base (Ant `colorXxxActive`, step 600).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).active")
    public var active: Color { resolved(in: .shared).active }
    /// High-contrast text/icon on light surfaces (step 700).
    @available(*, deprecated, message: "Reads Theme.shared and ignores per-subtree .theme(); use theme.resolve(color).strong")
    public var strong: Color { resolved(in: .shared).strong }
}

/// Fill style shared by configurable components (daisyUI: solid / soft / outline / ghost).
public enum FillVariant: String, CaseIterable {
    case solid, soft, outline, ghost
}
