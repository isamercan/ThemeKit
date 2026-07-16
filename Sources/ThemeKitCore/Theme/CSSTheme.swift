//
//  CSSTheme.swift
//  ThemeKit
//
//  Native, runtime import of a HeroUI-style CSS design system (OKLCH / hex
//  custom properties) into a ThemeKit theme — the Swift port of
//  `tools/import_css_theme.py`. No build step, no Python: hand `Theme` a CSS
//  string (`setTheme(css:)`) or a bundled `.css` (`loadTheme(cssNamed:)`) and the
//  whole token set is generated on-device via `ThemeGenerator`.
//
//  The CSS body is treated as untrusted text — it is only scanned for
//  `--var: value;` declarations and color literals; nothing is ever executed
//  (mirrors the Design Mode markdown parser). Anything the CSS doesn't define
//  falls back to ThemeKit's defaults, so a partial file still yields a full theme.
//

import CoreGraphics
import Foundation

/// Parses a HeroUI-style CSS theme (its `:root`/`.light` and `.dark` blocks) into
/// ThemeKit token sets. Brand-agnostic: works for any design system that exposes
/// `--accent` / `--background` / `--danger`… as `oklch()` or hex custom properties.
public enum CSSTheme {

    // MARK: - Public API

    /// A parsed CSS theme: the light + dark variable maps and the accent hue.
    /// Turn it into a `Theme.ThemeData` for either scheme with `themeData(dark:font:)`.
    public struct Parsed: Sendable {
        public let light: [String: String]
        public let dark: [String: String]
        let hue: Double

        /// `true` when the CSS declared a distinct `.dark` block.
        public var hasDarkScheme: Bool { !dark.isEmpty && dark.keys.contains("accent") }

        /// The generated token set for one scheme. `font` names the type family
        /// (must be bundled/registered to render, else the system font is used).
        /// Internal: `Theme.ThemeData` is an internal type — apply via `Theme.setTheme(css:)`.
        func themeData(dark: Bool, font: String = "System") -> Theme.ThemeData {
            CSSTheme.build(vars: dark ? self.dark : self.light,
                           rootFallback: self.light,   // structural tokens (radius, padding) are usually declared once, in :root
                           dark: dark, hue: hue, font: font)
        }
    }

    /// Parses a CSS string. Missing a `.dark` block is fine — the light variables
    /// are reused for both schemes.
    public static func parse(_ css: String) -> Parsed {
        var light: [String: String] = [:]
        var dark: [String: String] = [:]
        for (selector, body) in blocks(in: stripComments(css)) {
            let isDark = selector.lowercased().contains("dark")
            for (name, value) in declarations(in: body) {
                if isDark { dark[name] = value } else { light[name] = value }
            }
        }
        if !dark.keys.contains("accent") { dark = light }
        let hue = parseColor(light["accent"] ?? "")?.hue ?? 253.83
        return Parsed(light: light, dark: dark, hue: hue)
    }

    // MARK: - Token mapping (mirrors import_css_theme.py)

    /// CSS var -> the ThemeKit semantic token(s) it paints EXACTLY.
    private static let semanticMap: [(css: String, tokens: [String])] = [
        ("accent", ["foreground.fg-hero", "text.text-hero", "border.border-hero",
                    "background.bg-hero", "background.systemcolors.bg-info",
                    "border.systemcolors.border-info"]),
        ("focus", ["foreground.systemcolors.fg-info"]),
        ("accent-foreground", ["foreground.fg-secondary"]),
        ("danger", ["foreground.systemcolors.fg-error", "background.systemcolors.bg-error",
                    "border.systemcolors.border-error"]),
        ("success", ["foreground.systemcolors.fg-success", "background.systemcolors.bg-success",
                     "border.systemcolors.border-success"]),
        ("warning", ["foreground.systemcolors.fg-warning", "background.systemcolors.bg-warning",
                     "border.systemcolors.border-warning"]),
        ("surface", ["background.bg-white"]),
        ("background", ["background.bg-base"]),
        ("border", ["border.border-primary"]),
        ("foreground", ["text.text-primary"]),
        ("muted", ["text.text-tertiary"]),
        ("surface-secondary", ["background.bg-elevator-primary"]),
        ("surface-tertiary", ["background.bg-secondary-light"]),
        ("default", ["background.bg-secondary"]),
    ]

    /// CSS var -> palette family it reseeds (full 50..900 ladder regenerated from it).
    /// `accent`/`focus` drive primary+info via `primaryHex`, so only the semantic
    /// families need an explicit seed here.
    private static let seedMap: [(css: String, family: String)] = [
        ("danger", "error"), ("success", "success"), ("warning", "warning"),
    ]

    /// Neutral gray ramp: which CSS var supplies the L anchor at each ladder step.
    private static let neutralAnchorsLight: [(step: Int, css: String)] = [
        (50, "background"), (100, "surface-secondary"), (200, "border"), (500, "muted"), (900, "foreground")]
    private static let neutralAnchorsDark: [(step: Int, css: String)] = [
        (50, "background"), (100, "surface"), (200, "border"), (500, "muted"), (900, "foreground")]
    private static let steps = [50, 100, 200, 300, 400, 500, 600, 700, 800, 900]

    /// CSS var(s) -> the demand-minted spacing token each mints, DECLARED-ONLY:
    /// a var maps 1:1 onto exactly ONE token — no cascade flattening here
    /// (`--card-padding` does not write header/body/footer entries). Precedence
    /// between the tokens lives in the component (Card) at render time.
    /// First name in the alias list wins within a scheme block.
    private static let spacingVarMap: [(token: String, cssNames: [String])] = [
        ("card-padding", ["card-padding", "card-p", "padding-card"]),
        ("card-header-padding", ["card-header-padding"]),
        ("card-body-padding", ["card-body-padding"]),
        ("card-footer-padding", ["card-footer-padding"]),
    ]

    // MARK: - Build

    private static func build(vars: [String: String], rootFallback: [String: String],
                              dark: Bool, hue: Double, font: String) -> Theme.ThemeData {
        let accent = parseColor(vars["accent"] ?? "")?.hex ?? "056bfd"

        // 1) reseed the semantic ladders from the CSS brand colors
        var seeds: [String: String] = [:]
        for (css, family) in seedMap {
            if let c = parseColor(vars[css] ?? "") { seeds[family] = c.hex }
        }

        // 2) interpolate a pure-neutral gray ramp from the CSS L anchors
        let ramp = neutralRamp(vars: vars, anchors: dark ? neutralAnchorsDark : neutralAnchorsLight, hue: hue)

        // 3) exact semantic-token overrides
        var overrides: [String: String] = [:]
        for entry in semanticMap {
            guard let c = parseColor(vars[entry.css] ?? "") else { continue }
            for tok in entry.tokens { overrides[tok] = c.hex }
        }

        // 4) radius roles (--radius -> box/selector, --field-radius -> field);
        //    inherit from the light block when the scheme omits them.
        var radii: [String: CGFloat] = [:]
        if let box = remToPx(vars["radius"] ?? rootFallback["radius"] ?? "") {
            radii["radius-box"] = box
            radii["radius-selector"] = box
        }
        if let field = remToPx(vars["field-radius"] ?? rootFallback["field-radius"] ?? "") {
            radii["radius-field"] = field
        }

        // 5) per-component spacing tokens (--card-padding & friends) — declared-only
        //    (a key is written ONLY when the var is present), inheriting from the
        //    light block when the scheme omits them, exactly like radius.
        var spacings: [String: CGFloat] = [:]
        for entry in spacingVarMap {
            let declared = entry.cssNames.lazy.compactMap { vars[$0] }.first
                ?? entry.cssNames.lazy.compactMap { rootFallback[$0] }.first
            if let declared, let px = remToPx(declared) { spacings[entry.token] = px }
        }

        return ThemeGenerator.generate(
            primaryHex: accent, tint: 0, dark: dark,
            font: font, fontScale: 1, radiusScale: 1, spacingScale: 1, shadowScale: 1,
            baseHex: nil, secondaryHex: nil, accentHex: nil,
            paletteSeeds: seeds, neutralRamp: ramp,
            semanticOverrides: overrides, radiusOverrides: radii,
            spacingOverrides: spacings
        )
    }

    /// Pure-neutral (chroma 0) 10-step ramp, L interpolated from the CSS anchors.
    /// Returns `nil` when no anchor resolves, so the generator keeps its own ramp.
    private static func neutralRamp(vars: [String: String],
                                    anchors: [(step: Int, css: String)], hue: Double) -> [String]? {
        var known: [(step: Int, lightness: Double)] = []
        for (step, css) in anchors {
            if let c = parseColor(vars[css] ?? ""), let lightness = c.approxL {
                known.append((step, lightness))
            }
        }
        guard !known.isEmpty else { return nil }
        known.sort { $0.step < $1.step }
        let firstL = known.first!.lightness, lastL = known.last!.lightness
        return steps.map { step -> String in
            let value: Double
            if let exact = known.first(where: { $0.step == step }) {
                value = exact.lightness
            } else if step <= known.first!.step {
                value = firstL
            } else if step >= known.last!.step {
                value = lastL
            } else {
                let lo = known.last { $0.step < step }!
                let hi = known.first { $0.step > step }!
                let t = Double(step - lo.step) / Double(hi.step - lo.step)
                value = lo.lightness + (hi.lightness - lo.lightness) * t
            }
            return oklchToHex(lightness: value, chroma: 0, hue: hue)
        }
    }

    // MARK: - Color parsing

    struct CSSColor {
        let hex: String
        let lightness: Double?
        let hue: Double
        /// `lightness` is present for `oklch()`; for hex/rgb it's estimated from
        /// luminance so those inputs can still anchor a neutral ramp.
        var approxL: Double? {
            if let lightness { return lightness }
            let r = Double(Int(hex.prefix(2), radix: 16) ?? 0) / 255
            let g = Double(Int(hex.dropFirst(2).prefix(2), radix: 16) ?? 0) / 255
            let b = Double(Int(hex.dropFirst(4).prefix(2), radix: 16) ?? 0) / 255
            return (0.2126 * r + 0.7152 * g + 0.0722 * b) * 100
        }
    }

    static func parseColor(_ raw0: String) -> CSSColor? {
        let raw = raw0.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ";"))
            .trimmingCharacters(in: .whitespaces)
        if raw.isEmpty || raw == "transparent" || raw == "none" || raw.hasPrefix("var(") { return nil }

        if let open = raw.range(of: "oklch("), let close = raw.range(of: ")", range: open.upperBound..<raw.endIndex) {
            let inner = raw[open.upperBound..<close.lowerBound]
            let parts = inner.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "/" })
                .map { $0.replacingOccurrences(of: "%", with: "") }
            if parts.count >= 3, let lightness = Double(parts[0]),
               let chroma = Double(parts[1]), let hue = Double(parts[2]) {
                return CSSColor(hex: oklchToHex(lightness: lightness, chroma: chroma, hue: hue),
                                lightness: lightness, hue: hue)
            }
            return nil
        }
        if raw.hasPrefix("#") {
            var h = String(raw.dropFirst()).lowercased().filter(\.isHexDigit)
            if h.count == 3 { h = h.map { "\($0)\($0)" }.joined() }
            if h.count >= 6 { return CSSColor(hex: String(h.prefix(6)), lightness: nil, hue: 0) }
            return nil
        }
        if let open = raw.range(of: "rgb", options: .caseInsensitive),
           let paren = raw.range(of: "(", range: open.upperBound..<raw.endIndex),
           let close = raw.range(of: ")", range: paren.upperBound..<raw.endIndex) {
            let comps = raw[paren.upperBound..<close.lowerBound]
                .split(whereSeparator: { $0 == " " || $0 == "," || $0 == "/" })
                .compactMap { Double($0) }
            if comps.count >= 3 {
                return CSSColor(hex: String(format: "%02x%02x%02x", Int(comps[0]), Int(comps[1]), Int(comps[2])),
                                lightness: nil, hue: 0)
            }
        }
        return nil
    }

    /// OKLCH (L in %, C chroma, H degrees) -> sRGB "rrggbb". Banker's rounding
    /// matches `import_css_theme.py` (Python `round()`), for byte-identical output.
    static func oklchToHex(lightness: Double, chroma: Double, hue: Double) -> String {
        let lNorm = lightness / 100
        let hRad = hue * .pi / 180
        let a = chroma * cos(hRad), b = chroma * sin(hRad)
        let l_ = lNorm + 0.3963377774 * a + 0.2158037573 * b
        let m_ = lNorm - 0.1055613458 * a - 0.0638541728 * b
        let s_ = lNorm - 0.0894841775 * a - 1.2914855480 * b
        let l = l_ * l_ * l_, m = m_ * m_ * m_, s = s_ * s_ * s_
        let r = 4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s
        let g = -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s
        let bl = -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s
        func gamma(_ x: Double) -> Int {
            let c = max(0, min(1, x))
            let v = c > 0.0031308 ? 1.055 * pow(c, 1 / 2.4) - 0.055 : 12.92 * c
            return Int((v * 255).rounded(.toNearestOrEven))
        }
        return String(format: "%02x%02x%02x", gamma(r), gamma(g), gamma(bl))
    }

    // MARK: - CSS scanning (no execution)

    private static func stripComments(_ css: String) -> String {
        var out = "", i = css.startIndex
        while i < css.endIndex {
            if css[i] == "/", let n = css.index(i, offsetBy: 1, limitedBy: css.endIndex), n < css.endIndex, css[n] == "*" {
                if let end = css.range(of: "*/", range: n..<css.endIndex) { i = end.upperBound; continue }
                break
            }
            out.append(css[i]); i = css.index(after: i)
        }
        return out
    }

    /// (selector, body) for each `… { … }` block. Custom-property blocks don't nest.
    private static func blocks(in css: String) -> [(String, String)] {
        var result: [(String, String)] = []
        var idx = css.startIndex
        while let open = css.range(of: "{", range: idx..<css.endIndex),
              let close = css.range(of: "}", range: open.upperBound..<css.endIndex) {
            let selector = String(css[idx..<open.lowerBound])
            let body = String(css[open.upperBound..<close.lowerBound])
            result.append((selector, body))
            idx = close.upperBound
        }
        return result
    }

    /// `--name: value` declarations in a block body (name without the `--`).
    private static func declarations(in body: String) -> [(String, String)] {
        var out: [(String, String)] = []
        for stmt in body.split(separator: ";") {
            guard let colon = stmt.firstIndex(of: ":") else { continue }
            let name = stmt[stmt.startIndex..<colon].trimmingCharacters(in: .whitespacesAndNewlines)
            guard name.hasPrefix("--") else { continue }
            let value = stmt[stmt.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            out.append((String(name.dropFirst(2)), value))
        }
        return out
    }

    private static func remToPx(_ value0: String) -> CGFloat? {
        let value = value0.trimmingCharacters(in: .whitespaces)
        if value.hasSuffix("rem"), let n = Double(value.dropLast(3)) { return CGFloat((n * 16).rounded(.toNearestOrEven)) }
        if value.hasSuffix("px"), let n = Double(value.dropLast(2)) { return CGFloat(n.rounded(.toNearestOrEven)) }
        if let n = Double(value) { return CGFloat(n.rounded(.toNearestOrEven)) }
        return nil
    }
}
