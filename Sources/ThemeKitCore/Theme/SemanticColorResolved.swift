//
//  SemanticColorResolved.swift
//  ThemeKit
//
//  ADR-0006 Phase 0 — the additive per-subtree color resolver.
//
//  `SemanticColor`'s role accessors (`.solid`, `.soft`, `.accent`, `.border`,
//  `.shade(_:)`, the ladder …) historically read `Theme.shared` directly, so a
//  subtree re-themed with `.theme(_:)` still painted accents from the global
//  singleton — a split-brain inside a single view body (see ADR-0006). This file
//  moves the role→color logic ONCE into `SemanticColor.Resolved`, a value that
//  binds a `SemanticColor` to a specific `Theme`. `SemanticColor`'s existing
//  zero-arg accessors now forward to `resolved(in: .shared)`, so behavior is
//  byte-identical for any call site that never touches `.theme(_:)` — this file
//  is purely additive; nothing is deprecated here (that is a Phase-2 follow-up).
//

import SwiftUI

public extension SemanticColor {
    /// Roles resolved against a specific `Theme` — honors per-subtree `.theme(_:)`.
    ///
    /// A transient value read within a view body (or a helper that already holds
    /// a `theme`); never stored across renders or escaped. `Sendable` because
    /// `Theme` is `@unchecked Sendable` and `SemanticColor` is `Sendable`.
    ///
    ///     @Environment(\.theme) private var theme
    ///     …
    ///     .fill(theme.resolve(.primary).solid)
    struct Resolved: Sendable {
        public let color: SemanticColor
        public let theme: Theme

        public init(color: SemanticColor, theme: Theme) {
            self.color = color
            self.theme = theme
        }

        /// Background for the `solid` variant.
        public var solid: Color {
            switch color {
            case .primary: return theme.background(.bgHero)
            case .neutral: return theme.background(.bgTertiary)
            case .info: return theme.background(.systemcolorsBgInfo)
            case .success: return theme.background(.systemcolorsBgSuccess)
            case .warning: return theme.background(.systemcolorsBgWarning)
            case .error: return theme.background(.systemcolorsBgError)
            case .turquoise: return theme.background(.bgTurquoise)
            case .orange: return theme.background(.bgOrange)
            case .purple: return theme.text(.textPurple)
            case .pink: return theme.background(.badgeBgMaximumpinkBase)
            case .secondary, .accent: return base
            }
        }

        /// Foreground on top of the `solid` background — auto-contrasting, same
        /// as `SemanticColor.onSolid` (theme-independent once `solid` resolves).
        public var onSolid: Color {
            ColorContrast.content(on: solid)
        }

        /// Light surface for the `soft` variant.
        public var soft: Color {
            switch color {
            case .primary: return theme.background(.bgElevatorTertiary)
            case .neutral: return theme.background(.bgSecondaryLight)
            case .info: return theme.background(.systemcolorsBgInfoLight)
            case .success: return theme.background(.systemcolorsBgSuccessLight)
            case .warning: return theme.background(.systemcolorsBgWarningLight)
            case .error: return theme.background(.systemcolorsBgErrorLight)
            case .turquoise: return theme.background(.bgTurquoiseLight)
            case .orange: return theme.background(.badgeBgOrange)
            case .purple: return theme.background(.badgeBgPurple)
            case .pink: return theme.background(.badgeBgMaximumpinkLight)
            case .secondary, .accent: return bg
            }
        }

        /// Accent foreground for `soft` / `outline` / `ghost` variants.
        public var accent: Color {
            switch color {
            case .primary: return theme.text(.textHero)
            case .neutral: return theme.text(.textPrimary)
            case .info: return theme.foreground(.systemcolorsFgInfo)
            case .success: return theme.foreground(.systemcolorsFgSuccess)
            case .warning: return theme.foreground(.systemcolorsFgWarning)
            case .error: return theme.foreground(.systemcolorsFgError)
            case .turquoise: return theme.foreground(.fgTurquoise)
            case .orange: return theme.foreground(.badgeFgOrange)
            case .purple: return theme.text(.textPurple)
            case .pink: return theme.foreground(.badgeFgMaximumpink)
            case .secondary, .accent: return strong
            }
        }

        /// Border for the `outline` variant.
        public var border: Color {
            switch color {
            case .primary: return theme.border(.borderHero)
            case .neutral: return theme.border(.borderPrimary)
            case .info: return theme.border(.systemcolorsBorderInfo)
            case .success: return theme.border(.systemcolorsBorderSuccess)
            case .warning: return theme.border(.systemcolorsBorderWarning)
            case .error: return theme.border(.systemcolorsBorderError)
            case .turquoise: return theme.border(.borderTurquoise)
            case .orange: return theme.border(.borderOrange)
            case .purple: return theme.text(.textPurple)
            case .pink: return theme.foreground(.badgeFgMaximumpink)
            case .secondary, .accent: return base
            }
        }

        // MARK: - Ant-style ladder roles

        /// Resolve any ladder step for this color, e.g. `theme.resolve(.primary).shade(.s700)`.
        public func shade(_ step: SemanticColor.Shade) -> Color {
            // Brand secondary/accent live in the additive ladder; fall back to primary
            // when a theme doesn't define them, so they never resolve to `.clear`.
            if color == .secondary || color == .accent {
                return theme.brandShade(color.rawValue, step.rawValue)
                    ?? (Theme.PaletteColorKey(rawValue: "palette.primary.\(step.rawValue)").map { theme.palette($0) } ?? .clear)
            }
            guard let key = Theme.PaletteColorKey(rawValue: "palette.\(color.rawValue).\(step.rawValue)") else { return .clear }
            return theme.palette(key)
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

    /// Enum-side binder — for Class-P helpers that already receive a `Theme`
    /// (mirrors `AlertToast.background(_:)` / `SeatPalette.colors(for:theme:)`).
    func resolved(in theme: Theme) -> Resolved { Resolved(color: self, theme: theme) }
}

public extension Theme {
    /// Theme-side binder — the ergonomic call in a view body: `theme.resolve(.primary).solid`.
    /// Mirrors the existing `theme.text(_:)` / `theme.background(_:)` shape.
    func resolve(_ color: SemanticColor) -> SemanticColor.Resolved { color.resolved(in: self) }
}
