//
//  Typography.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Montserrat type ramp from the Figma design system. Each style carries its
//  size / weight / line-height. The font family falls back to the system font
//  when the Montserrat files are not bundled.
//

import SwiftUI

public enum TextStyle: String, CaseIterable {
    // Display
    case displayLg, displayMd, displayBase, displaySm
    // Heading
    case heading2xl, headingXl, headingLg, headingMd, headingBase, headingSm, headingXs, heading2xs, heading3xs
    // Label
    case labelLg600, labelLg700, labelMd600, labelMd700, labelBase600, labelBase700, labelSm600, labelSm700
    // Body
    case bodyLg500, bodyLg400, bodyMd500, bodyMd400, bodyBase500, bodyBase400, bodySm500, bodySm400
    // Overline
    case overline400, overline500
    // Link
    case linkMd, linkBase, linkSm

    public static let fontFamily = "Montserrat"

    /// (pointSize, weight, lineHeight) — values mirror the Figma tokens.
    public var spec: (size: CGFloat, weight: Font.Weight, lineHeight: CGFloat) {
        switch self {
        case .displayLg:    return (48, .bold, 68)
        case .displayMd:    return (44, .bold, 64)
        case .displayBase:  return (40, .bold, 60)
        case .displaySm:    return (36, .bold, 60)

        case .heading2xl:   return (40, .semibold, 60)
        case .headingXl:    return (36, .semibold, 54)
        case .headingLg:    return (32, .semibold, 44)
        case .headingMd:    return (28, .semibold, 40)
        case .headingBase:  return (24, .semibold, 30)
        case .headingSm:    return (20, .semibold, 26)
        case .headingXs:    return (18, .semibold, 24)
        case .heading2xs:   return (16, .semibold, 20)
        case .heading3xs:   return (14, .semibold, 16)

        case .labelLg600:   return (18, .semibold, 24)
        case .labelLg700:   return (18, .bold, 24)
        case .labelMd600:   return (16, .semibold, 20)
        case .labelMd700:   return (16, .bold, 20)
        case .labelBase600: return (14, .semibold, 16)
        case .labelBase700: return (14, .bold, 16)
        case .labelSm600:   return (12, .semibold, 14)
        case .labelSm700:   return (12, .bold, 14)

        case .bodyLg500:    return (18, .medium, 28)
        case .bodyLg400:    return (18, .regular, 28)
        case .bodyMd500:    return (16, .medium, 24)
        case .bodyMd400:    return (16, .regular, 24)
        case .bodyBase500:  return (14, .medium, 20)
        case .bodyBase400:  return (14, .regular, 20)
        case .bodySm500:    return (12, .medium, 16)
        case .bodySm400:    return (12, .regular, 16)

        case .overline400:  return (10, .regular, 12)
        case .overline500:  return (10, .medium, 12)

        case .linkMd:       return (16, .semibold, 24)
        case .linkBase:     return (14, .semibold, 20)
        case .linkSm:       return (12, .semibold, 16)
        }
    }

    /// The semantic `Font.TextStyle` this token scales against for Dynamic Type.
    /// Custom fonts built with `relativeTo:` grow/shrink with the user's preferred
    /// text size (anchored to this style), instead of staying a fixed point size.
    public var relativeTextStyle: Font.TextStyle {
        switch spec.size {
        case 34...:      return .largeTitle
        case 28..<34:    return .title
        case 23..<28:    return .title2
        case 20..<23:    return .title3
        case 17..<20:    return .body
        case 15..<17:    return .callout
        case 14..<15:    return .subheadline
        case 12..<14:    return .footnote
        case 11..<12:    return .caption
        default:         return .caption2
        }
    }

    /// Resolved from the active theme's JSON typography; falls back to the
    /// in-code ramp when a theme doesn't define this style. Scales with Dynamic
    /// Type via `relativeTo:`.
    public var font: Font {
        if let resolved = Theme.shared.textStyle(self) { return resolved.font }
        let spec = spec
        return Font.custom(TextStyle.fontFamily, size: spec.size, relativeTo: relativeTextStyle).weight(spec.weight)
    }

    /// Extra line spacing to approximate the token line-height.
    public var lineSpacing: CGFloat {
        if let resolved = Theme.shared.textStyle(self) { return resolved.lineSpacing }
        return max(0, spec.lineHeight - spec.size)
    }
}

public extension View {
    /// Applies a design-system text style (font + line spacing) from the active theme.
    func textStyle(_ style: TextStyle) -> some View {
        font(style.font).lineSpacing(style.lineSpacing)
    }
}
