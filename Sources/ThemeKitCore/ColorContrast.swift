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
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

    /// sRGB 0…1 components of a `Color`, via the platform color bridge
    /// (`UIColor` on iOS, `NSColor` on macOS) — `Color.resolve(in:)` is iOS 17+
    /// (ADR-0007 §D3, iOS 15.6 floor). The theme's token colors are plain sRGB
    /// values (`Color(hex:)` / `Color(.sRGB, …)`), for which the bridge returns
    /// the same components the old resolver did — pinned by
    /// `ContentContrastTests` / `ColorModelsTests` on macOS `swift test`.
    static func components(of color: Color) -> (Double, Double, Double) {
        func clamp(_ v: CGFloat) -> Double { min(max(Double(v), 0), 1) }
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        return (clamp(r), clamp(g), clamp(b))
        #elseif canImport(AppKit)
        guard let srgb = NSColor(color).usingColorSpace(.sRGB) else { return (0, 0, 0) }
        return (clamp(srgb.redComponent), clamp(srgb.greenComponent), clamp(srgb.blueComponent))
        #else
        return (0, 0, 0)
        #endif
    }
}
