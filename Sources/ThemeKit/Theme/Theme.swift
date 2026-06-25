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
    public private(set) var revision = 0

    private var foreground: [ForegroundColorKey: Color] = [:]
    private var background: [BackgroundColorKey: Color] = [:]
    private var border: [BorderColorKey: Color] = [:]
    private var text: [TextColorKey: Color] = [:]
    private var palette: [PaletteColorKey: Color] = [:]
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
        if var config = currentConfig {
            config.dark = dark
            apply(config)
        } else {
            loadTheme(named: baseThemeName, dark: dark)
        }
    }

    public func setTheme(jsonData: Data) {
        do {
            let decoded = try JSONDecoder().decode(ThemeData.self, from: jsonData)
            apply(decoded)
        } catch {
            assertionFailure("Failed to decode theme JSON: \(error)")
        }
    }

    /// The `ThemeConfig` currently applied via `apply(_:)` / `applyGenerated(...)`,
    /// or `nil` if a bundled named theme is active. Re-encode it to persist/share.
    public private(set) var currentConfig: ThemeConfig?

    /// Applies a `ThemeConfig` — the whole token set is regenerated on-device from
    /// its few inputs (`ThemeGenerator`), no bundled JSON needed. This is the
    /// entry point a host app uses to apply a configurator export.
    public func apply(_ config: ThemeConfig) {
        currentConfig = config
        baseThemeName = "custom"
        isDark = config.dark
        apply(ThemeGenerator.generate(
            primaryHex: config.primaryHex, tint: config.tint, dark: config.dark, font: config.font,
            fontScale: config.fontScale, radiusScale: config.radiusScale,
            spacingScale: config.spacingScale, shadowScale: config.shadowScale
        ))
    }

    /// Convenience for applying a generated theme without building a `ThemeConfig`.
    public func applyGenerated(
        primaryHex: String,
        tint: Double = 0.06,
        dark: Bool = false,
        font: String = "Montserrat",
        fontScale: Double = 1,
        radiusScale: Double = 1,
        spacingScale: Double = 1,
        shadowScale: Double = 1
    ) {
        apply(ThemeConfig(
            primaryHex: primaryHex, tint: tint, dark: dark, font: font,
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
            spacingScale: config.spacingScale, shadowScale: config.shadowScale
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
        // Signal subscribers BEFORE mutating (correct ObservableObject ordering)
        // so every theme-reading view refreshes in the same render pass.
        objectWillChange.send()
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
        foreground = [:]; background = [:]; border = [:]; text = [:]; palette = [:]
        radiusList = [:]; spacingList = [:]; typographyList = [:]; shadowList = [:]
    }

    // MARK: - Color accessors

    public func foreground(_ key: ForegroundColorKey) -> Color { foreground[key] ?? .clear }
    public func background(_ key: BackgroundColorKey) -> Color { background[key] ?? .clear }
    public func border(_ key: BorderColorKey) -> Color { border[key] ?? .clear }
    public func text(_ key: TextColorKey) -> Color { text[key] ?? .primary }

    /// Primitive 50..900 ladder color (Ant-style). `step 500` is the base.
    public func palette(_ key: PaletteColorKey) -> Color { palette[key] ?? .clear }

    // MARK: - Metric accessors

    public func radius(_ key: RadiusKey) -> CGFloat { radiusList[key.rawValue] ?? 0 }
    public func spacing(_ key: SpacingKey) -> CGFloat { spacingList[key.rawValue] ?? 0 }

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
