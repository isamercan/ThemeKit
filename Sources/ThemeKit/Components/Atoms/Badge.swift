//
//  Badge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum BadgeStyle: String, CaseIterable {
    case neutral, info, success, warning, error
    case pink, orange, turquoise, purple

    func background(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgSecondaryLight)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        case .pink: return theme.background(.badgeBgMaximumpinkLight)
        case .orange: return theme.background(.badgeBgOrange)
        case .turquoise: return theme.background(.badgeBgTurquoiseLight)
        case .purple: return theme.background(.badgeBgPurple)
        }
    }

    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.text(.textSecondary)
        case .info: return theme.foreground(.systemcolorsFgInfo)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error: return theme.foreground(.systemcolorsFgError)
        case .pink: return theme.foreground(.badgeFgMaximumpink)
        case .orange: return theme.foreground(.badgeFgOrange)
        case .turquoise: return theme.foreground(.badgeFgTurquoise)
        case .purple: return theme.text(.textPurple)
        }
    }

    func border(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.border(.borderPrimary)
        case .info: return theme.border(.systemcolorsBorderInfoLight)
        case .success: return theme.border(.systemcolorsBorderSuccessLight)
        case .warning: return theme.border(.systemcolorsBorderWarningLight)
        case .error: return theme.border(.systemcolorsBorderErrorLight)
        case .pink, .orange, .turquoise, .purple: return .clear
        }
    }

    var semantic: SemanticColor {
        switch self {
        case .neutral: return .neutral
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .pink: return .pink
        case .orange: return .orange
        case .turquoise: return .turquoise
        case .purple: return .purple
        }
    }
}

public enum BadgeSize {
    case small, medium, large, xlarge

    var height: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        case .xlarge: return 44
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .small, .medium: return Theme.SpacingKey.sm.value   // 8
        case .large, .xlarge: return Theme.SpacingKey.md.value   // 16
        }
    }
    var textStyle: TextStyle {
        switch self {
        case .small, .medium: return .labelSm600
        case .large: return .labelBase600
        case .xlarge: return .labelMd600
        }
    }
    var iconSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14
        case .large: return 16
        case .xlarge: return 18
        }
    }
}

public enum BadgeShape {
    case pill
    case rounded
}

/// Improved, token-bound rewrite of the reference BadgeView. Styling is driven
/// by a semantic `BadgeStyle` (system + brand variants) instead of
/// component-specific color lookups, and icons use SF Symbols.
public struct Badge: View {
    @Environment(\.theme) private var theme

    private let text: String
    private let action: (() -> Void)?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var style: BadgeStyle = .neutral
    private var variant: FillVariant = .soft
    private var size: BadgeSize = .medium
    private var leadingSystemImage: String?
    private var shape: BadgeShape = .pill
    private var trailingSystemImage: String?
    private var textColor: Color?
    // ADR-0006: stored as `SemanticColor` (not a resolved `Color`) so the
    // gradient is re-resolved from the environment theme in `body`, honoring
    // per-subtree `.theme(_:)`; `rawGradient` is the raw-`Color` escape hatch
    // (deprecated `gradient(_: [Color]?)`), which has no theme to resolve.
    private var semanticGradient: [SemanticColor]?
    private var rawGradient: [Color]?
    private var highlighted: Bool = false

    public init(_ text: String, action: (() -> Void)? = nil) {   // R1 — content + action
        self.text = text
        self.action = action
    }

    public var body: some View {
        if let action {
            Button(action: action) { content }.buttonStyle(PressFeedbackStyle())
        } else {
            content
        }
    }

    private var content: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: size.iconSize))
            }
            Text(text).textStyle(size.textStyle)
            if let trailingSystemImage {
                Image(systemName: trailingSystemImage).font(.system(size: size.iconSize))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, size.horizontalPadding)
        .frame(height: size.height)
        .background(backgroundStyle, in: shapeStyle)
        .overlay(shapeStyle.stroke(border, lineWidth: 1))
        .modifier(BadgeHighlight(on: highlighted))
    }

    private var foreground: Color {
        if let textColor { return textColor }
        switch variant {
        case .soft: return style.foreground(theme)
        case .solid: return theme.resolve(style.semantic).onSolid
        case .outline, .ghost: return theme.resolve(style.semantic).accent
        }
    }
    private var backgroundStyle: AnyShapeStyle {
        if let semanticGradient {
            let colors = semanticGradient.map { theme.resolve($0).solid }
            return AnyShapeStyle(LinearGradient(colors: colors, startPoint: .leading, endPoint: .trailing))
        }
        if let rawGradient {
            return AnyShapeStyle(LinearGradient(colors: rawGradient, startPoint: .leading, endPoint: .trailing))
        }
        switch variant {
        case .soft: return AnyShapeStyle(style.background(theme))
        case .solid: return AnyShapeStyle(theme.resolve(style.semantic).solid)
        case .outline, .ghost: return AnyShapeStyle(Color.clear)
        }
    }
    private var border: Color {
        switch variant {
        case .soft: return style.border(theme)
        case .solid: return .clear
        case .outline: return theme.resolve(style.semantic).border
        case .ghost: return .clear
        }
    }

    private var shapeStyle: AnyShape {
        switch shape {
        case .pill: return AnyShape(Capsule())
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Badge {
    /// Semantic style (system + brand variants) driving fill/foreground/border
    /// (renamed from the bare `style:` to avoid the generic clash + match `BadgeStyle`).
    func badgeStyle(_ s: BadgeStyle) -> Self { copy { $0.style = s } }
    /// Fill treatment: soft / solid / outline / ghost.
    func variant(_ v: FillVariant) -> Self { copy { $0.variant = v } }
    /// Size tier: small / medium / large / xlarge.
    func size(_ s: BadgeSize) -> Self { copy { $0.size = s } }
    /// Leading SF Symbol before the text.
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }
    /// Pill (default) or rounded-rectangle outline.
    func badgeShape(_ shape: BadgeShape) -> Self { copy { $0.shape = shape } }
    /// A trailing SF Symbol after the text (e.g. a dismiss chevron).
    func trailingIcon(_ systemName: String?) -> Self { copy { $0.trailingSystemImage = systemName } }
    /// Overrides the text/foreground color (otherwise derived from style + variant).
    @available(*, deprecated, message: "Use badgeStyle(_:) with a semantic BadgeStyle (plus variant(_:)) instead of a raw color.")
    func badgeColor(_ color: Color?) -> Self { copy { $0.textColor = color } }
    /// Fills the badge with a horizontal gradient of semantic tokens (each
    /// hue's solid shade) instead of the style background; `nil` restores it.
    func gradient(_ colors: [SemanticColor]?) -> Self { copy { $0.semanticGradient = colors; $0.rawGradient = nil } }
    /// Raw-color gradient (back-compat); prefer the token-bound overload.
    /// Disfavored so member-shorthand literals like `[.purple, .pink]` —
    /// valid as both `[Color]` and `[SemanticColor]` — resolve to the token
    /// overload instead of being ambiguous.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use gradient(_: [SemanticColor]?) — the token-bound overload.")
    func gradient(_ colors: [Color]?) -> Self { copy { $0.rawGradient = colors; $0.semanticGradient = nil } }
    /// Lifts the badge off the surface with a subtle drop shadow.
    func highlighted(_ on: Bool = true) -> Self { copy { $0.highlighted = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

private struct BadgeHighlight: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on {
            content.themeShadow(.soft)
        } else {
            content
        }
    }
}

#Preview {
    PreviewMatrix("Badge") {
        for style in BadgeStyle.allCases {
            PreviewCase(style.rawValue.capitalized) {
                Badge(style.rawValue.capitalized).badgeStyle(style).icon("star.fill")
            }
        }
        PreviewCase("Sizes + rounded") {
            HStack {
                Badge("Small").badgeStyle(.info).size(.small)
                Badge("Medium").badgeStyle(.info).size(.medium)
                Badge("Large").badgeStyle(.info).size(.large)
                Badge("Rounded").badgeStyle(.success).badgeShape(.rounded)
            }
        }
        PreviewCase("Variants") {
            HStack {
                Badge("Solid").badgeStyle(.error).variant(.solid)
                Badge("Outline").badgeStyle(.info).variant(.outline)
                Badge("Ghost").badgeStyle(.success).variant(.ghost)
            }
        }
        // G5 — token gradient twin (solid shades of semantic hues); `.solid`
        // variant keeps the on-solid foreground over the gradient fill.
        PreviewCase("Gradient (solid)") {
            HStack {
                Badge("Pro").gradient([.purple, .pink]).variant(.solid)
                Badge("Deal").gradient([.primary, .turquoise]).variant(.solid)
            }
        }
        PreviewCase("Long text") {
            Badge("a-rather-long-badge-label").badgeStyle(.warning)
        }
    }
}
