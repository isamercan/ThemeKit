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
    private let style: BadgeStyle
    private let variant: FillVariant
    private let size: BadgeSize
    private let leadingSystemImage: String?
    private let action: (() -> Void)?
    // Long-tail styling — rarely set, so configured via chainable modifiers
    // rather than the init (keeps the common call site to `Badge("x", style:)`).
    private var shape: BadgeShape = .pill
    private var trailingSystemImage: String? = nil
    private var textColor: Color? = nil
    private var gradient: [Color]? = nil
    private var highlighted: Bool = false

    public init(
        _ text: String,
        style: BadgeStyle = .neutral,
        variant: FillVariant = .soft,
        size: BadgeSize = .medium,
        leadingSystemImage: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.variant = variant
        self.size = size
        self.leadingSystemImage = leadingSystemImage
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
        case .solid: return style.semantic.onSolid
        case .outline, .ghost: return style.semantic.accent
        }
    }
    private var backgroundStyle: AnyShapeStyle {
        if let gradient { return AnyShapeStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)) }
        switch variant {
        case .soft: return AnyShapeStyle(style.background(theme))
        case .solid: return AnyShapeStyle(style.semantic.solid)
        case .outline, .ghost: return AnyShapeStyle(Color.clear)
        }
    }
    private var border: Color {
        switch variant {
        case .soft: return style.border(theme)
        case .solid: return .clear
        case .outline: return style.semantic.border
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

public extension Badge {
    /// Pill (default) or rounded-rectangle outline.
    func badgeShape(_ shape: BadgeShape) -> Self { var copy = self; copy.shape = shape; return copy }
    /// A trailing SF Symbol after the text (e.g. a dismiss chevron).
    func trailingIcon(_ systemName: String?) -> Self { var copy = self; copy.trailingSystemImage = systemName; return copy }
    /// Overrides the text/foreground color (otherwise derived from style + variant).
    func badgeColor(_ color: Color?) -> Self { var copy = self; copy.textColor = color; return copy }
    /// Fills the badge with a horizontal gradient instead of the style background.
    func gradient(_ colors: [Color]?) -> Self { var copy = self; copy.gradient = colors; return copy }
    /// Lifts the badge off the surface with a subtle drop shadow.
    func highlighted(_ on: Bool = true) -> Self { var copy = self; copy.highlighted = on; return copy }
}

private struct BadgeHighlight: ViewModifier {
    let on: Bool
    func body(content: Content) -> some View {
        if on {
            content.shadow(color: .black.opacity(0.22), radius: 3, x: 0, y: 2)
        } else {
            content
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        ForEach(BadgeStyle.allCases, id: \.self) { style in
            Badge(style.rawValue.capitalized, style: style, leadingSystemImage: "star.fill")
        }
        HStack {
            Badge("Small", style: .info, size: .small)
            Badge("Medium", style: .info, size: .medium)
            Badge("Large", style: .info, size: .large)
            Badge("Rounded", style: .success).badgeShape(.rounded)
        }
    }
    .padding()
}
