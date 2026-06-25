//
//  Badge.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference BadgeView. Styling is driven
//  by a semantic `BadgeStyle` (system + brand variants) instead of
//  component-specific color lookups, and icons use SF Symbols.
//

import SwiftUI

public enum BadgeStyle: String, CaseIterable {
    case neutral, info, success, warning, error
    case pink, orange, turquoise, purple

    var background: Color {
        switch self {
        case .neutral: return Theme.shared.background(.bgSecondaryLight)
        case .info: return Theme.shared.background(.systemcolorsBgInfoLight)
        case .success: return Theme.shared.background(.systemcolorsBgSuccessLight)
        case .warning: return Theme.shared.background(.systemcolorsBgWarningLight)
        case .error: return Theme.shared.background(.systemcolorsBgErrorLight)
        case .pink: return Theme.shared.background(.badgeBgMaximumpinkLight)
        case .orange: return Theme.shared.background(.badgeBgOrange)
        case .turquoise: return Theme.shared.background(.badgeBgTurquoiseLight)
        case .purple: return Theme.shared.background(.badgeBgPurple)
        }
    }

    var foreground: Color {
        switch self {
        case .neutral: return Theme.shared.text(.textSecondary)
        case .info: return Theme.shared.foreground(.systemcolorsFgInfo)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        case .pink: return Theme.shared.foreground(.badgeFgMaximumpink)
        case .orange: return Theme.shared.foreground(.badgeFgOrange)
        case .turquoise: return Theme.shared.foreground(.badgeFgTurquoise)
        case .purple: return Theme.shared.text(.textPurple)
        }
    }

    var border: Color {
        switch self {
        case .neutral: return Theme.shared.border(.borderPrimary)
        case .info: return Theme.shared.border(.systemcolorsBorderInfoLight)
        case .success: return Theme.shared.border(.systemcolorsBorderSuccessLight)
        case .warning: return Theme.shared.border(.systemcolorsBorderWarningLight)
        case .error: return Theme.shared.border(.systemcolorsBorderErrorLight)
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

public struct Badge: View {
    private let text: String
    private let style: BadgeStyle
    private let variant: FillVariant
    private let size: BadgeSize
    private let shape: BadgeShape
    private let leadingSystemImage: String?
    private let trailingSystemImage: String?
    private let textColor: Color?
    private let gradient: [Color]?
    private let highlighted: Bool
    private let action: (() -> Void)?

    public init(
        _ text: String,
        style: BadgeStyle = .neutral,
        variant: FillVariant = .soft,
        size: BadgeSize = .medium,
        shape: BadgeShape = .pill,
        leadingSystemImage: String? = nil,
        trailingSystemImage: String? = nil,
        textColor: Color? = nil,
        gradient: [Color]? = nil,
        highlighted: Bool = false,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.style = style
        self.variant = variant
        self.size = size
        self.shape = shape
        self.leadingSystemImage = leadingSystemImage
        self.trailingSystemImage = trailingSystemImage
        self.textColor = textColor
        self.gradient = gradient
        self.highlighted = highlighted
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
        case .soft: return style.foreground
        case .solid: return style.semantic.onSolid
        case .outline, .ghost: return style.semantic.accent
        }
    }
    private var backgroundStyle: AnyShapeStyle {
        if let gradient { return AnyShapeStyle(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)) }
        switch variant {
        case .soft: return AnyShapeStyle(style.background)
        case .solid: return AnyShapeStyle(style.semantic.solid)
        case .outline, .ghost: return AnyShapeStyle(Color.clear)
        }
    }
    private var border: Color {
        switch variant {
        case .soft: return style.border
        case .solid: return .clear
        case .outline: return style.semantic.border
        case .ghost: return .clear
        }
    }

    private var shapeStyle: AnyShape {
        switch shape {
        case .pill: return AnyShape(Capsule())
        case .rounded: return AnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
        }
    }
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
            Badge("Rounded", style: .success, shape: .rounded)
        }
    }
    .padding()
}
