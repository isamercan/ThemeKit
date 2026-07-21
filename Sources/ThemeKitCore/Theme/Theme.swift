//
//  Theme.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Token-based theme engine. Loads design tokens (colors / radius / spacing)
//  from bundled JSON and exposes them via typed, semantic keys.
//  Typography (`TextStyle`) and shadows (`ShadowStyle`) are structural and
//  defined in code; they are constant across themes.
//

import SwiftUI

/// The design-system theme singleton.
///
/// Concurrency: `Theme` is a main-thread-confined UI object — its tokens are
/// applied from the main thread (theme application is user/UI-driven) and read
/// during SwiftUI rendering, which is also main-thread. We therefore mark it
/// `@unchecked Sendable` rather than `@MainActor`: actor-isolating it would force
/// the whole nonisolated token layer (`SemanticColor`, `TextStyle`, `SpacingKey`,
/// `ShapeStyle` conformances …) onto the main actor, which they don't need.
///
/// Observation: `ObservableObject` (not the iOS-17 `@Observable` macro — ADR-0007
/// §D3, iOS 15.6 floor). Only ``revision`` is `@Published`; the stored token
/// dictionaries are not observed per-property — the `.id(revision)` full-subtree
/// rebuild in `.themeKit()` is the reactivity contract.
public final class Theme: ObservableObject, @unchecked Sendable {

    struct ThemeData: Codable {
        let colors: [AppColor]?
        let radius: [AppRadius]?
        let spacing: [AppSpacing]?
        let typography: [AppTypography]?
        let shadows: [AppShadow]?
    }

    public static let defaultThemeName = "defaultTheme"

    public static let shared = Theme()

    /// The base theme name (without the dark suffix) currently loaded.
    public private(set) var baseThemeName = defaultThemeName
    /// Whether the dark variant of the current theme is active.
    public private(set) var isDark = false
    /// Increments on every theme application. Use as a SwiftUI `.id(theme.revision)`
    /// to force a subtree to fully rebuild when the theme changes — needed for
    /// views whose leaf children read the theme statically (so SwiftUI's view
    /// diffing would otherwise skip re-rendering them on a live theme swap).
    /// `@Published` so an `@ObservedObject` root (`ThemeKitModifier`) re-runs its
    /// body on the bump and re-applies the `.id`.
    @Published public private(set) var revision = 0

    private var foreground: [ForegroundColorKey: Color] = [:]
    private var background: [BackgroundColorKey: Color] = [:]
    private var border: [BorderColorKey: Color] = [:]
    private var text: [TextColorKey: Color] = [:]
    private var palette: [PaletteColorKey: Color] = [:]
    /// Additive brand-color ladders (daisyUI `secondary` / `accent`) that aren't
    /// part of the generated Figma `PaletteColorKey` set. Keyed `"<family>.<step>"`
    /// (e.g. `"accent.500"`). Empty unless a theme/config provides these hexes.
    private var brandPalette: [String: Color] = [:]
    private var radiusList: [String: CGFloat] = [:]
    private var spacingList: [String: CGFloat] = [:]
    private var typographyList: [String: ResolvedTextStyle] = [:]
    private var shadowList: [String: [ResolvedShadowLayer]] = [:]

    public init() {
        Theme.registerFonts()
        loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: - Fonts

    // One-time, idempotent registration guard. Flipped only inside `registerFonts()`
    // during `init` on the main thread; `nonisolated(unsafe)` documents that we own
    // its (trivial, write-once) thread-safety.
    nonisolated(unsafe) private static var fontsRegistered = false

    /// Registers bundled `.ttf` fonts (Montserrat) once. Missing files are a
    /// no-op — typography falls back to the system font.
    static func registerFonts() {
        guard !fontsRegistered else { return }
        fontsRegistered = true
        let urls = Bundle.module.urls(forResourcesWithExtension: "ttf", subdirectory: nil) ?? []
        for url in urls {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    // MARK: - Loading

    /// Loads a theme by base name, optionally its dark variant (`<name>Dark`).
    /// Falls back to the light variant if a dark JSON isn't bundled.
    public func loadTheme(named jsonName: String, dark: Bool = false) {
        currentConfig = nil
        currentCSS = nil
        baseThemeName = jsonName
        isDark = dark
        let resource = dark ? jsonName + "Dark" : jsonName
        let url = Bundle.module.url(forResource: resource, withExtension: "json")
            ?? Bundle.module.url(forResource: jsonName, withExtension: "json")
        guard let url, let data = try? Data(contentsOf: url) else {
            assertionFailure("Theme '\(resource)' not found in bundle")
            return
        }
        setTheme(jsonData: data)
    }

    /// Switches the active theme between its light and dark variants. Works for
    /// both bundled named themes and a live `ThemeConfig`.
    public func setColorScheme(dark: Bool) {
        if let css = currentCSS {
            setTheme(css: css, font: currentCSSFont, dark: dark)
        } else if var config = currentConfig {
            config.dark = dark
            apply(config)
        } else {
            loadTheme(named: baseThemeName, dark: dark)
        }
    }

    public func setTheme(jsonData: Data) {
        do {
            let decoded = try JSONDecoder().decode(ThemeData.self, from: jsonData)
            currentConfig = nil
            currentCSS = nil
            apply(decoded)
        } catch {
            assertionFailure("Failed to decode theme JSON: \(error)")
        }
    }

    /// Applies a HeroUI-style CSS theme (OKLCH / hex custom properties) **natively**
    /// — no offline conversion, no build step. Both the light and dark blocks are
    /// parsed; `dark` picks which to show now (defaults to the current scheme), and
    /// `setColorScheme(dark:)` then switches between them from the same CSS.
    ///
    /// `font` names the type family for the generated ramp — it must be bundled and
    /// registered in your app to render, otherwise the system font is used. The CSS
    /// is treated as untrusted text: only `--var: value;` declarations and color
    /// literals are read; nothing is executed.
    public func setTheme(css: String, font: String = "System", dark: Bool? = nil) {
        let parsed = CSSTheme.parse(css)
        let useDark = dark ?? isDark
        currentConfig = nil
        currentCSS = css
        currentCSSFont = font
        baseThemeName = "css"
        isDark = useDark
        apply(parsed.themeData(dark: useDark, font: font))
    }

    /// Loads a bundled `.css` theme and applies it via ``setTheme(css:font:dark:)``.
    /// Searches the ThemeKit resource bundle first, then the host app's main bundle —
    /// so a consumer can drop `brand.css` into their app and call
    /// `loadTheme(cssNamed: "brand")`.
    public func loadTheme(cssNamed name: String, font: String = "System", dark: Bool? = nil) {
        let url = Bundle.module.url(forResource: name, withExtension: "css")
            ?? Bundle.main.url(forResource: name, withExtension: "css")
        guard let url, let css = try? String(contentsOf: url, encoding: .utf8) else {
            assertionFailure("CSS theme '\(name).css' not found in bundle")
            return
        }
        setTheme(css: css, font: font, dark: dark)
    }

    /// The `ThemeConfig` currently applied via `apply(_:)` / `applyGenerated(...)`,
    /// or `nil` if a bundled named theme is active. Re-encode it to persist/share.
    public private(set) var currentConfig: ThemeConfig?

    /// The raw CSS currently applied via `setTheme(css:)` / `loadTheme(cssNamed:)`,
    /// or `nil` when a JSON / config theme is active. Retained so `setColorScheme(dark:)`
    /// can re-derive the other scheme from the same source.
    public private(set) var currentCSS: String?
    private var currentCSSFont: String = "System"

    /// Applies a `ThemeConfig` — the whole token set is regenerated on-device from
    /// its few inputs (`ThemeGenerator`), no bundled JSON needed. This is the
    /// entry point a host app uses to apply a configurator export.
    public func apply(_ config: ThemeConfig) {
        currentConfig = config
        currentCSS = nil
        baseThemeName = "custom"
        isDark = config.dark
        apply(ThemeGenerator.generate(
            primaryHex: config.primaryHex, tint: config.tint, dark: config.dark, font: config.font,
            fontScale: config.fontScale, radiusScale: config.radiusScale,
            spacingScale: config.spacingScale, shadowScale: config.shadowScale,
            baseHex: config.baseHex, secondaryHex: config.secondaryHex, accentHex: config.accentHex
        ))
    }

    /// Convenience for applying a generated theme without building a `ThemeConfig`.
    public func applyGenerated(
        primaryHex: String,
        baseHex: String? = nil,
        tint: Double = 0.06,
        dark: Bool = false,
        font: String = "Montserrat",
        fontScale: Double = 1,
        radiusScale: Double = 1,
        spacingScale: Double = 1,
        shadowScale: Double = 1
    ) {
        apply(ThemeConfig(
            primaryHex: primaryHex, baseHex: baseHex, tint: tint, dark: dark, font: font,
            fontScale: fontScale, radiusScale: radiusScale, spacingScale: spacingScale, shadowScale: shadowScale
        ))
    }

    /// The FULL generated token set for a config, encoded as JSON in the same
    /// shape as a bundled theme file. Lets a host bundle a static `.json` and load
    /// it via `setTheme(jsonData:)` with zero on-device generation. (Portable
    /// export — no Python, no dependency on this generator at runtime.)
    public func generatedTokenJSON(for config: ThemeConfig) -> Data? {
        let data = ThemeGenerator.generate(
            primaryHex: config.primaryHex, tint: config.tint, dark: config.dark, font: config.font,
            fontScale: config.fontScale, radiusScale: config.radiusScale,
            spacingScale: config.spacingScale, shadowScale: config.shadowScale,
            baseHex: config.baseHex, secondaryHex: config.secondaryHex, accentHex: config.accentHex
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        return try? encoder.encode(data)
    }

    // MARK: - Persistence (UserDefaults)

    /// Persists the active `ThemeConfig` so it can be restored next launch.
    @discardableResult
    public func persistConfig(key: String = Theme.persistedConfigKey) -> Bool {
        guard let config = currentConfig, let data = try? config.jsonData() else { return false }
        UserDefaults.standard.set(data, forKey: key)
        return true
    }

    /// Applies a previously `persistConfig()`-ed theme. Returns `false` if none.
    @discardableResult
    public func applyPersistedConfig(key: String = Theme.persistedConfigKey) -> Bool {
        guard let data = UserDefaults.standard.data(forKey: key),
              let config = try? ThemeConfig(jsonData: data) else { return false }
        apply(config)
        return true
    }

    public static let persistedConfigKey = "themeKitConfig"

    private func apply(_ decoded: ThemeData) {
        // Bumping `revision` (a @Published property observed by the root's
        // `.id(theme.revision)`) drives the full-subtree refresh on theme change.
        revision += 1
        resetThemeState()

        for color in decoded.colors ?? [] {
            let value = Color(hex: color.hex)
            if let key = ForegroundColorKey(rawValue: color.name) {
                foreground[key] = value
            } else if let key = BackgroundColorKey(rawValue: color.name) {
                background[key] = value
            } else if let key = BorderColorKey(rawValue: color.name) {
                border[key] = value
            } else if let key = TextColorKey(rawValue: color.name) {
                text[key] = value
            } else if let key = PaletteColorKey(rawValue: color.name) {
                palette[key] = value
            } else if color.name.hasPrefix("palette.secondary.") || color.name.hasPrefix("palette.accent.") {
                // Additive brand ladders (not in the generated PaletteColorKey set).
                brandPalette[String(color.name.dropFirst("palette.".count))] = value
            }
        }
        for r in decoded.radius ?? [] { radiusList[r.name] = r.radius }
        for s in decoded.spacing ?? [] { spacingList[s.name] = s.spacing }
        for t in decoded.typography ?? [] {
            let relativeTo = TextStyle(rawValue: t.name)?.relativeTextStyle ?? .body
            typographyList[t.name] = ResolvedTextStyle(
                font: makeFont(family: t.font, size: t.size, weight: fontWeight(t.weight), relativeTo: relativeTo),
                lineSpacing: max(0, t.lineHeight - t.size)
            )
        }
        for s in decoded.shadows ?? [] {
            shadowList[s.name] = s.layers.map {
                ResolvedShadowLayer(color: Color(hex: $0.color), radius: $0.radius, x: $0.x, y: $0.y)
            }
        }
    }

    private func resetThemeState() {
        foreground = [:]; background = [:]; border = [:]; text = [:]; palette = [:]; brandPalette = [:]
        radiusList = [:]; spacingList = [:]; typographyList = [:]; shadowList = [:]
    }

    // MARK: - Color accessors

    public func foreground(_ key: ForegroundColorKey) -> Color { foreground[key] ?? .clear }
    public func background(_ key: BackgroundColorKey) -> Color { background[key] ?? .clear }
    public func border(_ key: BorderColorKey) -> Color { border[key] ?? .clear }
    public func text(_ key: TextColorKey) -> Color { text[key] ?? .primary }

    /// The modal scrim color (`background.bg-backdrop`), used by every presenter
    /// (Dialog, Drawer, Tour) via the `Backdrop` atom. Themes that predate the
    /// token fall back to a neutral 40% dim derived from `bg-tertiary` — mirroring
    /// the `RadiusRole` fallback — so a consumer theme can never render an
    /// invisible scrim (`background(_:)` would return `.clear` for the missing key).
    public var backdrop: Color { background[.bgBackdrop] ?? background(.bgTertiary).opacity(0.4) }

    /// Primitive 50..900 ladder color (Ant-style). `step 500` is the base.
    public func palette(_ key: PaletteColorKey) -> Color { palette[key] ?? .clear }

    /// An additive brand ladder step (daisyUI `secondary` / `accent`), or `nil`
    /// when the active theme doesn't define one (callers fall back to primary).
    public func brandShade(_ family: String, _ step: Int) -> Color? { brandPalette["\(family).\(step)"] }

    // MARK: - Metric accessors

    public func radius(_ key: RadiusKey) -> CGFloat { radiusList[key.rawValue] ?? 0 }

    /// Resolved radius for a semantic *role* (box / field / selector). Reads the
    /// theme's role token if present, otherwise the role's fallback size key — so
    /// themes without role tokens (bundled JSON) keep their existing corners.
    public func radius(_ role: RadiusRole) -> CGFloat {
        radiusList[role.rawValue] ?? radius(role.fallback)
    }
    public func spacing(_ key: SpacingKey) -> CGFloat { spacingList[key.rawValue] ?? 0 }

    /// Resolved spacing for a semantic *role* (box). Reads the theme's role token
    /// if present, otherwise the role's fallback size key — so themes without
    /// role tokens (bundled JSON) keep their existing insets.
    public func spacing(_ role: SpacingRole) -> CGFloat {
        spacingList[role.rawValue] ?? spacing(role.fallback)
    }

    /// A demand-minted component spacing token (`card-padding`,
    /// `card-header-padding`, …), or `nil` when the active theme doesn't declare
    /// it — deliberately unlike the `?? 0` key accessor, so a component can walk
    /// its precedence chain (slot token → umbrella token → spacing role).
    /// `package`: stringly token names stay inside the library — consumers go
    /// through component modifiers or theme/CSS files.
    package func spacing(token name: String) -> CGFloat? { spacingList[name] }

    // MARK: - Typography accessor

    /// The active theme's resolved style for a `TextStyle` (font + line spacing).
    /// `nil` falls back to the in-code ramp in `Typography.swift`.
    public func textStyle(_ key: TextStyle) -> ResolvedTextStyle? { typographyList[key.rawValue] }

    /// The active theme's resolved drop-shadow layers for a `ShadowStyle`.
    /// `nil` falls back to the in-code layers in `Shadows.swift`.
    public func shadow(_ key: ShadowStyle) -> [ResolvedShadowLayer]? { shadowList[key.rawValue] }

    private func makeFont(family: String, size: CGFloat, weight: Font.Weight, relativeTo: Font.TextStyle = .body) -> Font {
        // Custom fonts scale with Dynamic Type via `relativeTo:`. System fonts at a
        // fixed point size have no `relativeTo` overload, so they stay exact.
        switch family {
        case "System": return .system(size: size).weight(weight)
        case "SystemRounded": return .system(size: size, design: .rounded).weight(weight)
        case "SystemSerif": return .system(size: size, design: .serif).weight(weight)
        case "SystemMono": return .system(size: size, design: .monospaced).weight(weight)
        default: return .custom(family, size: size, relativeTo: relativeTo).weight(weight)
        }
    }

    private func fontWeight(_ raw: String) -> Font.Weight {
        switch raw {
        case "bold": return .bold
        case "semibold": return .semibold
        case "medium": return .medium
        default: return .regular
        }
    }
}
