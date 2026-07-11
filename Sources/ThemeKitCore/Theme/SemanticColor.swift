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

    /// Background for the `solid` variant.
    public var solid: Color {
        switch self {
        case .primary: return Theme.shared.background(.bgHero)
        case .neutral: return Theme.shared.background(.bgTertiary)
        case .info: return Theme.shared.background(.systemcolorsBgInfo)
        case .success: return Theme.shared.background(.systemcolorsBgSuccess)
        case .warning: return Theme.shared.background(.systemcolorsBgWarning)
        case .error: return Theme.shared.background(.systemcolorsBgError)
        case .turquoise: return Theme.shared.background(.bgTurquoise)
        case .orange: return Theme.shared.background(.bgOrange)
        case .purple: return Theme.shared.text(.textPurple)
        case .pink: return Theme.shared.background(.badgeBgMaximumpinkBase)
        case .secondary, .accent: return base
        }
    }

    /// Foreground on top of the `solid` background — **auto-contrasting**: a bright
    /// accent (amber, yellow, light primary) gets dark content, a deep one gets white,
    /// computed from the background's luminance rather than hardcoded per color.
    public var onSolid: Color {
        ColorContrast.content(on: solid)
    }

    /// Light surface for the `soft` variant.
    public var soft: Color {
        switch self {
        case .primary: return Theme.shared.background(.bgElevatorTertiary)
        case .neutral: return Theme.shared.background(.bgSecondaryLight)
        case .info: return Theme.shared.background(.systemcolorsBgInfoLight)
        case .success: return Theme.shared.background(.systemcolorsBgSuccessLight)
        case .warning: return Theme.shared.background(.systemcolorsBgWarningLight)
        case .error: return Theme.shared.background(.systemcolorsBgErrorLight)
        case .turquoise: return Theme.shared.background(.bgTurquoiseLight)
        case .orange: return Theme.shared.background(.badgeBgOrange)
        case .purple: return Theme.shared.background(.badgeBgPurple)
        case .pink: return Theme.shared.background(.badgeBgMaximumpinkLight)
        case .secondary, .accent: return bg
        }
    }

    /// Accent foreground for `soft` / `outline` / `ghost` variants.
    public var accent: Color {
        switch self {
        case .primary: return Theme.shared.text(.textHero)
        case .neutral: return Theme.shared.text(.textPrimary)
        case .info: return Theme.shared.foreground(.systemcolorsFgInfo)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        case .turquoise: return Theme.shared.foreground(.fgTurquoise)
        case .orange: return Theme.shared.foreground(.badgeFgOrange)
        case .purple: return Theme.shared.text(.textPurple)
        case .pink: return Theme.shared.foreground(.badgeFgMaximumpink)
        case .secondary, .accent: return strong
        }
    }

    /// Border for the `outline` variant.
    public var border: Color {
        switch self {
        case .primary: return Theme.shared.border(.borderHero)
        case .neutral: return Theme.shared.border(.borderPrimary)
        case .info: return Theme.shared.border(.systemcolorsBorderInfo)
        case .success: return Theme.shared.border(.systemcolorsBorderSuccess)
        case .warning: return Theme.shared.border(.systemcolorsBorderWarning)
        case .error: return Theme.shared.border(.systemcolorsBorderError)
        case .turquoise: return Theme.shared.border(.borderTurquoise)
        case .orange: return Theme.shared.border(.borderOrange)
        case .purple: return Theme.shared.text(.textPurple)
        case .pink: return Theme.shared.foreground(.badgeFgMaximumpink)
        case .secondary, .accent: return base
        }
    }

    // MARK: - Ant-style ladder roles

    /// A step on the primitive 50..900 ladder (Ant's 10-shade palette).
    public enum Shade: Int, CaseIterable {
        case s50 = 50, s100 = 100, s200 = 200, s300 = 300, s400 = 400
        case s500 = 500, s600 = 600, s700 = 700, s800 = 800, s900 = 900
    }

    /// Resolve any ladder step for this color, e.g. `.primary.shade(.s700)`.
    public func shade(_ step: Shade) -> Color {
        // Brand secondary/accent live in the additive ladder; fall back to primary
        // when a theme doesn't define them, so they never resolve to `.clear`.
        if self == .secondary || self == .accent {
            return Theme.shared.brandShade(rawValue, step.rawValue)
                ?? (Theme.PaletteColorKey(rawValue: "palette.primary.\(step.rawValue)").map { Theme.shared.palette($0) } ?? .clear)
        }
        guard let key = Theme.PaletteColorKey(rawValue: "palette.\(rawValue).\(step.rawValue)") else { return .clear }
        return Theme.shared.palette(key)
    }

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
