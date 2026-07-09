//
//  ColorContrast.swift
//  ThemeKit
//
//  WCAG-style content contrast: pick a readable foreground (near-white / near-black)
//  for a given background, so "content on a solid color" stays legible whatever the
//  theme's accent is — a bright amber or yellow primary gets dark text, a deep navy
//  gets white. The generator stays brand-agnostic; legibility is computed, not baked.
//

import SwiftUI

// SPI, not public: a legibility helper the component layer (e.g. Tooltip) reuses,
// but not part of ThemeKit's supported consumer API. `@_exported` deliberately does
// not re-export `@_spi`, so component files that need it import it explicitly with
// `@_spi(ThemeKitInternal) import ThemeKitCore`.
@_spi(ThemeKitInternal) public enum ColorContrast {
    /// Near-black content for light surfaces (slightly soft, not pure `#000`).
    static let dark = Color(.sRGB, red: 0.08, green: 0.09, blue: 0.11, opacity: 1)
    /// White content for dark surfaces.
    static let light = Color.white

    /// Approx. relative luminance of `dark`, for the contrast comparison below.
    private static let darkLuminance = 0.01

    /// The readable content color (near-white or near-black) for a background.
    @_spi(ThemeKitInternal) public static func content(on background: Color) -> Color {
        contentIsDark(on: background) ? dark : light
    }

    /// Whether dark content reads better than white on `background` (WCAG contrast).
    static func contentIsDark(on background: Color) -> Bool {
        let l = luminance(of: background)
        let contrastWithWhite = 1.05 / (l + 0.05)
        let contrastWithDark = (l + 0.05) / (darkLuminance + 0.05)
        return contrastWithDark >= contrastWithWhite
    }

    /// WCAG relative luminance (0…1) of a color.
    static func luminance(of color: Color) -> Double {
        let (r, g, b) = components(of: color)
        func lin(_ c: Double) -> Double { c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4) }
        return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b)
    }

    /// sRGB 0…1 components of a `Color`. Uses SwiftUI's cross-platform resolver
    /// (iOS 17 / macOS 14), so it works the same in the app and in `swift test`.
    static func components(of color: Color) -> (Double, Double, Double) {
        let resolved = color.resolve(in: EnvironmentValues())
        func clamp(_ v: Float) -> Double { min(max(Double(v), 0), 1) }
        return (clamp(resolved.red), clamp(resolved.green), clamp(resolved.blue))
    }
}
