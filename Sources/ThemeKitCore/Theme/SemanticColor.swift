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
    // ADR-0006 Phase 0: the role→color logic now lives ONCE in `Resolved`
    // (`SemanticColorResolved.swift`). These zero-arg accessors forward to
    // `resolved(in: .shared)`, so they stay byte-identical to before — still
    // `Theme.shared`-backed, unaware of a subtree's `.theme(_:)` override.
    // NOT deprecated yet (Phase 2 follow-up); prefer `theme.resolve(_:)` in a
    // view body, which reads the environment theme instead of the singleton.

    /// Background for the `solid` variant.
    public var solid: Color { resolved(in: .shared).solid }

    /// Foreground on top of the `solid` background — **auto-contrasting**: a bright
    /// accent (amber, yellow, light primary) gets dark content, a deep one gets white,
    /// computed from the background's luminance rather than hardcoded per color.
    public var onSolid: Color { resolved(in: .shared).onSolid }

    /// Light surface for the `soft` variant.
    public var soft: Color { resolved(in: .shared).soft }

    /// Accent foreground for `soft` / `outline` / `ghost` variants.
    public var accent: Color { resolved(in: .shared).accent }

    /// Border for the `outline` variant.
    public var border: Color { resolved(in: .shared).border }

    // MARK: - Ant-style ladder roles

    /// A step on the primitive 50..900 ladder (Ant's 10-shade palette).
    public enum Shade: Int, CaseIterable {
        case s50 = 50, s100 = 100, s200 = 200, s300 = 300, s400 = 400
        case s500 = 500, s600 = 600, s700 = 700, s800 = 800, s900 = 900
    }

    /// Resolve any ladder step for this color, e.g. `.primary.shade(.s700)`.
    public func shade(_ step: Shade) -> Color { resolved(in: .shared).shade(step) }

    /// Faint container background (Ant `colorXxxBg`, step 50).
    public var bg: Color { shade(.s50) }
    /// Container background, hovered/stronger (Ant `colorXxxBgHover`, step 100).
    public var bgHover: Color { shade(.s100) }
    /// Subtle border (Ant `colorXxxBorder`, step 200).
    public var borderSubtle: Color { shade(.s200) }
    /// Border, hovered (Ant `colorXxxBorderHover`, step 300).
    public var borderHover: Color { shade(.s300) }
    /// Solid fill, hovered — lighter than base (Ant `colorXxxHover`, step 400).
    public var hover: Color { shade(.s400) }
    /// The color itself (Ant `colorXxx`, step 500).
    public var base: Color { shade(.s500) }
    /// Solid fill, pressed/active — darker than base (Ant `colorXxxActive`, step 600).
    public var active: Color { shade(.s600) }
    /// High-contrast text/icon on light surfaces (step 700).
    public var strong: Color { shade(.s700) }
}

/// Fill style shared by configurable components (daisyUI: solid / soft / outline / ghost).
public enum FillVariant: String, CaseIterable {
    case solid, soft, outline, ghost
}
