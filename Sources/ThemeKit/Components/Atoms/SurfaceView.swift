//
//  SurfaceView.swift
//  ThemeKit
//

import SwiftUI

/// Semantic surface level → background token. Visual hierarchy comes from
/// nesting levels (primary > secondary > tertiary), not from bespoke colors.
/// `transparent` renders no fill and suppresses any shadow.
public enum SurfaceLevel: CaseIterable {
    case primary, secondary, tertiary, transparent

    func background(_ theme: Theme) -> Color {
        switch self {
        case .primary: return theme.background(.bgWhite)
        case .secondary: return theme.background(.bgSecondaryLight)
        case .tertiary: return theme.background(.bgTertiary)
        case .transparent: return .clear
        }
    }
}

/// Atom. A brand-neutral, nestable themed container primitive — the surface
/// `Card` and other boxed organisms sit on. It draws only chrome (token fill,
/// continuous corner, optional token shadow) around arbitrary content; it has
/// no header, no interaction and no state. (HeroUI Native `Surface` parity.)
///
///     SurfaceView {
///         Text("Nested")
///     }
///     .level(.secondary)
///     .elevation(.soft)
///
/// Decorative by construction: it adds no accessibility label or traits and
/// does not force an accessibility element, so children read naturally.
public struct SurfaceView<Content: View>: View {
    @Environment(\.theme) private var theme

    private let content: () -> Content

    // Appearance — mutated only through the modifiers below (R2).
    private var level: SurfaceLevel = .primary
    private var elevation: CardElevation = .none
    private var radius: Theme.RadiusRole = .box
    private var padding: Theme.SpacingKey = .md

    public init(@ViewBuilder content: @escaping () -> Content) {   // R1 — content only
        self.content = content
    }

    public var body: some View {
        content()
            .padding(padding.value)
            .background(level.background(theme), in: shape)
            .clipShape(shape)   // keeps edge-to-edge children inside the corner
            .modifier(CardShadow(elevation: effectiveElevation))
    }

    /// Continuous corner used for both the fill and the clip.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: radius.value, style: .continuous)
    }

    /// A transparent surface casts no shadow, whatever the requested elevation.
    private var effectiveElevation: CardElevation {
        level == .transparent ? .none : elevation
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SurfaceView {
    /// Surface level: primary / secondary / tertiary background token, or
    /// transparent (no fill, no shadow). Nest levels for visual hierarchy.
    func level(_ l: SurfaceLevel) -> Self { copy { $0.level = l } }

    /// Token shadow: none (default) / soft / elevated. Ignored while transparent.
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }

    /// Radius role for the container corner (default `.box`).
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radius = role } }

    /// Inner content padding by spacing token (default `.md`); named so it
    /// doesn't shadow the native `.padding`.
    func contentPadding(_ key: Theme.SpacingKey) -> Self { copy { $0.padding = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - surfaceChrome (asChild companion)

public extension View {
    /// Applies surface chrome — the level's background token filled and clipped
    /// with the same continuous-corner shape — to an arbitrary view, without
    /// wrapping it in a `SurfaceView` (SwiftUI equivalent of HeroUI `asChild`).
    /// Adds no padding, shadow, interaction or accessibility traits.
    func surfaceChrome(_ level: SurfaceLevel, radius: Theme.RadiusRole = .box) -> some View {
        modifier(SurfaceChrome(level: level, radius: radius))
    }
}

private struct SurfaceChrome: ViewModifier {
    @Environment(\.theme) private var theme
    let level: SurfaceLevel
    let radius: Theme.RadiusRole

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: radius.value, style: .continuous)
        content
            .background(level.background(theme), in: shape)
            .clipShape(shape)
    }
}

// MARK: - Previews

#Preview("Levels + nesting") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            ScrollView {
                VStack(spacing: Theme.SpacingKey.md.value) {
                    // Every level
                    ForEach(SurfaceLevel.allCases, id: \.self) { level in
                        SurfaceView {
                            Text(String(describing: level))
                                .textStyle(.labelMd600)
                                .foregroundStyle(theme.text(.textPrimary))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .level(level)
                    }

                    // Elevation + radius + padding knobs
                    SurfaceView {
                        Text("Elevated · field radius · sm padding")
                            .textStyle(.labelSm600)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .elevation(.elevated)
                    .radius(.field)
                    .contentPadding(.sm)

                    // Nested hierarchy: primary > secondary > tertiary
                    SurfaceView {
                        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                            Text("Primary").textStyle(.headingSm)
                                .foregroundStyle(theme.text(.textPrimary))
                            SurfaceView {
                                VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                                    Text("Secondary").textStyle(.labelMd600)
                                        .foregroundStyle(theme.text(.textPrimary))
                                    SurfaceView {
                                        Text("Tertiary").textStyle(.labelSm600)
                                            .foregroundStyle(theme.text(.textSecondary))
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                    .level(.tertiary)
                                }
                            }
                            .level(.secondary)
                        }
                    }
                    .elevation(.soft)

                    // asChild companion: chrome on an arbitrary view
                    Text("surfaceChrome on a plain Text")
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .padding(Theme.SpacingKey.md.value)
                        .surfaceChrome(.secondary, radius: .field)
                }
                .padding()
            }
            .background(theme.background(.bgBase))
        }
    }
    return Demo()
}

#Preview("Dark theme") {
    let darkTheme: Theme = {
        let t = Theme()
        t.loadTheme(named: Theme.defaultThemeName, dark: true)
        return t
    }()
    return ScrollView {
        VStack(spacing: Theme.SpacingKey.md.value) {
            ForEach(SurfaceLevel.allCases, id: \.self) { level in
                SurfaceView {
                    Text(String(describing: level))
                        .textStyle(.labelMd600)
                        .foregroundStyle(darkTheme.text(.textPrimary))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .level(level)
            }
            SurfaceView {
                SurfaceView {
                    SurfaceView {
                        Text("Primary > Secondary > Tertiary")
                            .textStyle(.labelSm600)
                            .foregroundStyle(darkTheme.text(.textSecondary))
                    }
                    .level(.tertiary)
                }
                .level(.secondary)
            }
            .elevation(.soft)
        }
        .padding()
    }
    .background(darkTheme.background(.bgBase))
    .theme(darkTheme)
    .preferredColorScheme(.dark)
}
