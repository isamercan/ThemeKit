//
//  ThemeGenerator.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A runtime port of `tools/gen_tokens.py`: builds a complete `Theme.ThemeData`
//  in memory from a primary color + tint + dark + scale knobs (radius / spacing /
//  font / shadow). Powers the live Theme Configurator — change the accent and the
//  whole Ant-style palette, neutral ramp, surfaces, borders and text regenerate
//  on the fly, exactly like the offline generator. (Brand-agnostic.)
//

import SwiftUI

enum ThemeGenerator {

    // MARK: - Color math (mirrors gen_tokens.py)

    private static func hexToRGB(_ h: String) -> (Double, Double, Double) {
        // Sanitize: keep only hex digits, then normalize to exactly 6 chars
        // (pad short / truncate long) so malformed input can't index out of bounds.
        var s = (h.hasPrefix("#") ? String(h.dropFirst()) : h).filter(\.isHexDigit)
        if s.count < 6 { s += String(repeating: "0", count: 6 - s.count) }
        else if s.count > 6 { s = String(s.prefix(6)) }
        func byte(_ i: Int) -> Double {
            let start = s.index(s.startIndex, offsetBy: i)
            let end = s.index(start, offsetBy: 2)
            return Double(Int(s[start..<end], radix: 16) ?? 0)
        }
        return (byte(0), byte(2), byte(4))
    }

    private static func rgbToHex(_ r: Double, _ g: Double, _ b: Double) -> String {
        String(format: "%02x%02x%02x", Int(r.rounded()), Int(g.rounded()), Int(b.rounded()))
    }

    private static func rgbToHSV(_ r0: Double, _ g0: Double, _ b0: Double) -> (Double, Double, Double) {
        let r = r0 / 255, g = g0 / 255, b = b0 / 255
        let mx = max(r, g, b), mn = min(r, g, b), d = mx - mn
        let v = mx
        let s = mx == 0 ? 0 : d / mx
        var h: Double
        if d == 0 { h = 0 }
        else if mx == r { h = (g - b) / d + (g < b ? 6 : 0) }
        else if mx == g { h = (b - r) / d + 2 }
        else { h = (r - g) / d + 4 }
        return (h * 60, s, v)
    }

    private static func hsvToRGB(_ h0: Double, _ s: Double, _ v: Double) -> (Double, Double, Double) {
        let h = h0.truncatingRemainder(dividingBy: 360) / 60
        let i = Int(h.rounded(.down)) % 6
        let f = h - h.rounded(.down)
        let p = v * (1 - s), q = v * (1 - f * s), t = v * (1 - (1 - f) * s)
        let r = [v, q, p, p, t, v][i]
        let g = [t, v, v, q, p, p][i]
        let b = [p, p, t, v, v, q][i]
        return (r * 255, g * 255, b * 255)
    }

    private static let hueStep = 2.0
    private static let satStep = 0.16, satStep2 = 0.05
    private static let briStep1 = 0.05, briStep2 = 0.15
    private static let lightCount = 5, darkCount = 4

    private static func antHue(_ h0: Double, _ i: Int, _ light: Bool) -> Double {
        let h = h0.rounded()
        let hue: Double
        if h >= 60 && h <= 240 {
            hue = light ? h - hueStep * Double(i) : h + hueStep * Double(i)
        } else {
            hue = light ? h + hueStep * Double(i) : h - hueStep * Double(i)
        }
        return (hue.truncatingRemainder(dividingBy: 360) + 360).truncatingRemainder(dividingBy: 360)
    }

    private static func antSat(_ h: Double, _ s: Double, _ i: Int, _ light: Bool) -> Double {
        if h == 0 && s == 0 { return s }
        var sat: Double
        if light { sat = s - satStep * Double(i) }
        else if i == darkCount { sat = s + satStep }
        else { sat = s + satStep2 * Double(i) }
        sat = min(sat, 1)
        if light && i == lightCount && sat > 0.1 { sat = 0.1 }
        return (max(sat, 0.06) * 100).rounded() / 100
    }

    private static func antVal(_ v: Double, _ i: Int, _ light: Bool) -> Double {
        let val = light ? v + briStep1 * Double(i) : v - briStep2 * Double(i)
        return (min(max(val, 0), 1) * 100).rounded() / 100
    }

    private static func antGenerate(_ baseHex: String) -> [String] {
        let (h, s, v) = rgbToHSV(hexToRGB(baseHex).0, hexToRGB(baseHex).1, hexToRGB(baseHex).2)
        var out: [String] = []
        for i in stride(from: lightCount, through: 1, by: -1) {
            let rgb = hsvToRGB(antHue(h, i, true), antSat(h, s, i, true), antVal(v, i, true))
            out.append(rgbToHex(rgb.0, rgb.1, rgb.2))
        }
        out.append(baseHex.hasPrefix("#") ? String(baseHex.dropFirst()) : baseHex)
        for i in 1...darkCount {
            let rgb = hsvToRGB(antHue(h, i, false), antSat(h, s, i, false), antVal(v, i, false))
            out.append(rgbToHex(rgb.0, rgb.1, rgb.2))
        }
        return out
    }

    private static func mix(_ c1: String, _ c2: String, _ amount: Double) -> String {
        let a = hexToRGB(c1), b = hexToRGB(c2)
        let p = amount / 100
        return rgbToHex(b.0 * p + a.0 * (1 - p), b.1 * p + a.1 * (1 - p), b.2 * p + a.2 * (1 - p))
    }

    private static let darkMix: [(Int, Double)] = [(7, 15), (6, 25), (5, 30), (5, 45), (5, 65), (5, 85), (4, 90), (3, 95), (2, 97), (1, 98)]
    private static let darkBG = "141414"

    private static func antGenerateDark(_ baseHex: String) -> [String] {
        let light = antGenerate(baseHex)
        return darkMix.map { mix(darkBG, light[$0.0 - 1], $0.1) }
    }

    private static let neutralLight = ["f6f7f9", "eceef1", "dde0e5", "c5c9d0", "a3a8b2", "808494", "5b5e69", "464951", "2b2d35", "0e1015"]
    private static let neutralDark = ["14161b", "1b1e24", "2a2e38", "3a3f4b", "565b68", "80858f", "9aa0ab", "bcc1ca", "d8dbe1", "f0f2f6"]

    private static func tintNeutral(_ shades: [String], _ primary: String, _ tint: Double) -> [String] {
        guard tint > 0 else { return shades }
        let n = shades.count
        return shades.enumerated().map { i, hex in
            let factor = tint * (1 - (Double(i) / Double(n - 1)) * 0.72)
            return mix(hex, primary, factor * 100)
        }
    }

    private static let paletteBases: [(String, String)] = [
        ("primary", "056bfd"), ("neutral", "808494"), ("info", "2e90fa"),
        ("success", "12b76a"), ("warning", "f79009"), ("error", "f04438"),
        ("turquoise", "0fb4ab"), ("orange", "ee9124"), ("purple", "b48bea"), ("pink", "ff0d87"),
    ]
    private static let steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]

    /// `family/step` -> hex. Primary & info follow the chosen accent; neutral is
    /// tinted toward it; the rest use Ant's HSV generator (or dark-mix).
    private static func buildPalette(primaryBase: String, dark: Bool, tint: Double) -> [String: String] {
        var table: [String: String] = [:]
        for (family, base) in paletteBases {
            let shades: [String]
            if family == "neutral" {
                let raw = dark ? neutralDark : neutralLight
                // The UNTINTED ladder stays addressable: base-100 surfaces must
                // remain true neutral on a re-skin (no accent wash on cards).
                for (step, hex) in zip(steps, raw) { table["neutral-raw/\(step)"] = hex }
                shades = tintNeutral(raw, primaryBase, tint)
            } else {
                let seed = (family == "primary" || family == "info") ? primaryBase : base
                shades = dark ? antGenerateDark(seed) : antGenerate(seed)
            }
            for (step, hex) in zip(steps, shades) { table["\(family)/\(step)"] = hex }
        }
        return table
    }

    // MARK: - Semantic alias tables (mirrors gen_tokens.py)

    private enum Tok { case d(String, Int); case a(String, String) }

    private static func resolve(_ t: Tok, _ palette: [String: String], _ dark: Bool) -> String {
        switch t {
        case .d(let family, let step): return palette["\(family)/\(step)"] ?? "000000"
        case .a(let light, let dk): return dark ? dk : light
        }
    }

    private static let foreground: [(String, Tok)] = [
        ("fg-hero", .d("primary", 500)), ("fg-secondary", .a("ffffff", "ffffff")),
        ("fg-turquoise", .d("turquoise", 500)),
        ("badge/fg-maximumpink", .d("pink", 600)), ("badge/fg-turquoise", .d("turquoise", 600)), ("badge/fg-orange", .d("orange", 700)),
        ("systemcolors/fg-success", .d("success", 500)), ("systemcolors/fg-error", .d("error", 500)),
        ("systemcolors/fg-warning", .d("warning", 500)), ("systemcolors/fg-info", .d("info", 500)),
    ]
    private static let background: [(String, Tok)] = [
        ("bg-white", .a("ffffff", "181c24")), ("bg-base", .d("neutral-raw", 50)), ("bg-hero", .d("primary", 500)),
        ("bg-elevator-primary", .d("neutral", 50)), ("bg-elevator-tertiary", .d("primary", 50)),
        ("bg-secondary", .d("neutral", 300)), ("bg-secondary-light", .d("neutral", 100)),
        ("bg-tertiary", .a("000929", "3a4150")),
        ("bg-backdrop", .a("00000066", "0000008c")),   // modal scrim: black @ 40% light / 55% dark
        ("bg-turquoise", .d("turquoise", 500)), ("bg-turquoise-light", .d("turquoise", 50)), ("bg-orange", .d("orange", 500)),
        ("badge/bg-maximumpink-base", .d("pink", 500)), ("badge/bg-maximumpink-light", .d("pink", 50)),
        ("badge/bg-purple", .d("purple", 50)), ("badge/bg-orange", .d("orange", 50)), ("badge/bg-turquoise-light", .d("turquoise", 100)),
        ("skeleton/bg-skeleton-base", .a("00092914", "ffffff14")),
        ("systemcolors/bg-success", .d("success", 500)), ("systemcolors/bg-success-light", .d("success", 50)),
        ("systemcolors/bg-error", .d("error", 500)), ("systemcolors/bg-error-light", .d("error", 50)),
        ("systemcolors/bg-warning", .d("warning", 500)), ("systemcolors/bg-warning-light", .d("warning", 50)),
        ("systemcolors/bg-info", .d("info", 500)), ("systemcolors/bg-info-light", .d("info", 50)),
    ]
    private static let borderTable: [(String, Tok)] = [
        ("border-hero", .d("primary", 500)), ("border-primary", .d("neutral", 200)),
        ("border-orange", .d("orange", 300)), ("border-turquoise", .d("turquoise", 300)),
        ("systemcolors/border-success", .d("success", 500)), ("systemcolors/border-success-light", .d("success", 200)),
        ("systemcolors/border-error", .d("error", 500)), ("systemcolors/border-error-light", .d("error", 200)),
        ("systemcolors/border-warning", .d("warning", 500)), ("systemcolors/border-warning-light", .d("warning", 200)),
        ("systemcolors/border-info", .d("info", 500)), ("systemcolors/border-info-light", .d("info", 200)),
    ]
    private static let textTable: [(String, Tok)] = [
        ("text-primary", .d("neutral", 900)), ("text-secondary", .d("neutral", 700)),
        ("text-tertiary", .d("neutral", 500)), ("text-disabled", .d("neutral", 300)),
        ("text-hero", .d("primary", 500)), ("text-purple", .d("purple", 500)),
        ("text-secondary-inverse", .a("d8d9de", "c5c6ce")),
    ]

    private static func jsonName(_ cat: String, _ sub: String) -> String {
        cat + "." + sub.replacingOccurrences(of: "/", with: ".")
    }

    // MARK: - Base metrics / typography / shadows

    private static let radiusBase: [(String, CGFloat)] = [
        ("radius-none", 0), ("rd-xs", 6), ("rd-sm", 8), ("rd-md", 16), ("rd-base", 24), ("rd-lg", 32), ("rd-xl", 40), ("rd-4xl", 64),
        // Semantic radius roles (daisyUI parity) — box / field / selector.
        ("radius-box", 16), ("radius-field", 8), ("radius-selector", 6),
    ]
    private static let spacingBase: [(String, CGFloat)] = [
        ("spacing-none", 0), ("sp-xs", 4), ("sp-sm", 8), ("sp-md", 16), ("sp-base", 24), ("sp-lg", 32), ("sp-xl", 40), ("sp-4xl", 64),
    ]
    // name, size, weight, lineHeight
    private static let typographyBase: [(String, CGFloat, String, CGFloat)] = [
        ("displayLg", 48, "bold", 68), ("displayMd", 44, "bold", 64), ("displayBase", 40, "bold", 60), ("displaySm", 36, "bold", 60),
        ("heading2xl", 40, "semibold", 60), ("headingXl", 36, "semibold", 54), ("headingLg", 32, "semibold", 44),
        ("headingMd", 28, "semibold", 40), ("headingBase", 24, "semibold", 30), ("headingSm", 20, "semibold", 26),
        ("headingXs", 18, "semibold", 24), ("heading2xs", 16, "semibold", 20), ("heading3xs", 14, "semibold", 16),
        ("labelLg600", 18, "semibold", 24), ("labelLg700", 18, "bold", 24), ("labelMd600", 16, "semibold", 20), ("labelMd700", 16, "bold", 20),
        ("labelBase600", 14, "semibold", 16), ("labelBase700", 14, "bold", 16), ("labelSm600", 12, "semibold", 14), ("labelSm700", 12, "bold", 14),
        ("bodyLg500", 18, "medium", 28), ("bodyLg400", 18, "regular", 28), ("bodyMd500", 16, "medium", 24), ("bodyMd400", 16, "regular", 24),
        ("bodyBase500", 14, "medium", 20), ("bodyBase400", 14, "regular", 20), ("bodySm500", 12, "medium", 16), ("bodySm400", 12, "regular", 16),
        ("overline400", 10, "regular", 12), ("overline500", 10, "medium", 12),
        ("linkMd", 16, "semibold", 24), ("linkBase", 14, "semibold", 20), ("linkSm", 12, "semibold", 16),
    ]
    // name -> layers of (8-digit RRGGBBAA color, radius, x, y)
    private static let shadowBase: [(String, [(String, CGFloat, CGFloat, CGFloat)])] = [
        ("elevated", [("3352a414", 8, 0, 6), ("3352a40d", 14, 0, 9), ("3352a408", 24, 0, 12)]),
        ("tabBar", [("0009291a", 8, 0, 0)]),
        ("soft", [("3352a414", 6, 0, 2)]),
    ]

    private static let surfaceTintKeys: Set<String> = ["background.bg-tertiary"]

    // MARK: - Public entry point

    /// Surface "paper" keys that take the theme's `baseHex` tone (the background a
    /// card / page sits on), each nudged toward the contrast color for elevation.
    /// Mirrors daisyUI's `base-100 … base-300` ramp.
    private static let baseSurfaceBlend: [(String, Double)] = [
        ("background.bg-white", 0),
        ("background.bg-base", 0),
        ("background.bg-elevator-primary", 5),
        ("background.bg-secondary-light", 8),
        ("background.bg-secondary", 16),
    ]

    static func generate(
        primaryHex: String, tint: Double, dark: Bool,
        font: String, fontScale: Double, radiusScale: Double, spacingScale: Double, shadowScale: Double,
        baseHex: String? = nil, secondaryHex: String? = nil, accentHex: String? = nil
    ) -> Theme.ThemeData {
        let primary = primaryHex.hasPrefix("#") ? String(primaryHex.dropFirst()) : primaryHex
        let palette = buildPalette(primaryBase: primary, dark: dark, tint: tint)
        let surfaceTint = tint * 0.25

        // When a base tone is supplied (e.g. a daisyUI theme's `base-100`), the
        // "paper" surfaces derive from it instead of the neutral ramp, so the theme
        // keeps its signature background (cupcake cream, cyberpunk yellow, dracula
        // slate) rather than a primary-tinted grey. Text/borders still follow `dark`.
        let baseOverrides: [String: String] = baseHex.map { rawBase in
            let base = rawBase.hasPrefix("#") ? String(rawBase.dropFirst()) : rawBase
            let contrast = dark ? "ffffff" : "000000"
            return Dictionary(uniqueKeysWithValues: baseSurfaceBlend.map { ($0.0, mix(base, contrast, $0.1)) })
        } ?? [:]

        var colors: [Theme.AppColor] = []
        let categories: [(String, [(String, Tok)])] = [
            ("foreground", foreground), ("background", background), ("border", borderTable), ("text", textTable),
        ]
        for (cat, table) in categories {
            for (sub, tok) in table {
                let name = jsonName(cat, sub)
                var hex = resolve(tok, palette, dark)
                if let override = baseOverrides[name] {
                    hex = override
                } else if surfaceTint > 0, surfaceTintKeys.contains("\(cat).\(sub)") {
                    hex = mix(hex, primary, surfaceTint * 100)
                }
                colors.append(.init(name: name, hex: hex))
            }
        }
        for (key, hex) in palette where !key.hasPrefix("neutral-raw/") {
            // neutral-raw is resolution-only plumbing (untinted bg-base source).
            colors.append(.init(name: "palette." + key.replacingOccurrences(of: "/", with: "."), hex: hex))
        }

        // Additive brand ladders (daisyUI `secondary` / `accent`) — full 50..900
        // ramps seeded from the given hexes, emitted alongside the typed palette.
        for (family, seedHex) in [("secondary", secondaryHex), ("accent", accentHex)] {
            guard let seedHex else { continue }
            let seed = seedHex.hasPrefix("#") ? String(seedHex.dropFirst()) : seedHex
            let shades = dark ? antGenerateDark(seed) : antGenerate(seed)
            for (step, shadeHex) in zip(steps, shades) {
                colors.append(.init(name: "palette.\(family).\(step)", hex: shadeHex))
            }
        }

        let radius = radiusBase.map { Theme.AppRadius(name: $0.0, radius: ($0.1 * radiusScale).rounded()) }
        let spacing = spacingBase.map { Theme.AppSpacing(name: $0.0, spacing: ($0.1 * spacingScale).rounded()) }
        let typography = typographyBase.map {
            Theme.AppTypography(name: $0.0, font: font, size: ($0.1 * fontScale).rounded(),
                                weight: $0.2, lineHeight: ($0.3 * fontScale).rounded())
        }
        let shadows = shadowBase.map { name, layers in
            Theme.AppShadow(name: name, layers: layers.map {
                Theme.AppShadowLayer(color: $0.0, radius: ($0.1 * shadowScale).rounded(), x: $0.2, y: ($0.3 * shadowScale).rounded())
            })
        }

        return Theme.ThemeData(colors: colors, radius: radius, spacing: spacing, typography: typography, shadows: shadows)
    }
}
