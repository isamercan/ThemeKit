//
//  DemoTheme.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//

import Foundation
import ThemeKit

/// The generic themes shipped with the package, surfaced for the demo's switcher.
/// Names are intentionally brand-agnostic.
enum DemoTheme: String, CaseIterable, Identifiable {
    case `default`
    case ocean
    case sunset
    case heroui

    var id: String { rawValue }

    /// The JSON resource name bundled in the package.
    var resourceName: String {
        switch self {
        case .default: return "defaultTheme"
        case .ocean: return "oceanTheme"
        case .sunset: return "sunsetTheme"
        case .heroui: return "herouiTheme"
        }
    }

    var label: String {
        switch self {
        case .default: return "Default"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        case .heroui: return "HeroUI"
        }
    }

    private static let storageKey = "selectedTheme"
    private static let darkKey = "selectedThemeDark"

    /// Applies the theme (light or dark variant) and persists the choice.
    func apply(dark: Bool) {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
        UserDefaults.standard.set(dark, forKey: Self.darkKey)
        if self == .heroui {
            // Demonstrates the native runtime CSS path: parse the bundled
            // heroui.css on-device (no JSON, no build step) and apply it.
            Theme.shared.loadTheme(cssNamed: "heroui", font: "Inter", dark: dark)
        } else {
            Theme.shared.loadTheme(named: resourceName, dark: dark)
        }
    }

    /// The currently persisted theme (defaults to `.default`).
    static var stored: DemoTheme {
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? ""
        return DemoTheme(rawValue: raw) ?? .default
    }

    /// The persisted color scheme (defaults to light).
    static var storedDark: Bool { UserDefaults.standard.bool(forKey: darkKey) }

    /// Applies the persisted theme + scheme at launch.
    static func applyStored() {
        stored.apply(dark: storedDark)
    }
}

/// Holds the selected theme + color scheme so the switcher stays in sync across
/// tabs. Applying drives `Theme.shared`, refreshing every `@ThemeContext` view.
final class DemoThemeStore: ObservableObject {
    @Published private(set) var current: DemoTheme
    @Published private(set) var isDark: Bool
    /// The active theme preset `id`, or `nil` when a bundled `DemoTheme` is active.
    @Published private(set) var presetID: String?
    /// The generated/preset recipe currently driving the theme — what the Theme
    /// Configurator seeds from. `nil` when a bundled JSON theme is active.
    @Published private(set) var activeConfig: ThemeConfig?
    /// The `design.md` spec id whose import produced the active theme, if any.
    /// Drives the "active design mode" badge; `nil` for presets / bundled themes.
    @Published private(set) var activeDesignSpecID: String?

    private static let presetKey = "selectedThemePreset"
    private static let customKey = "selectedThemeCustomConfig"
    private static let designSpecKey = "selectedDesignSpecID"

    init() {
        current = DemoTheme.stored
        isDark = DemoTheme.storedDark
        // Screenshot/deep-link override: `-forceTheme <resourceName> [-forceThemeDark YES]`
        // pins a bundled JSON theme at launch, bypassing the saved preset/custom
        // precedence below (used to verify a specific theme in the simulator).
        if let forced = UserDefaults.standard.string(forKey: "forceTheme"), !forced.isEmpty {
            let dark = UserDefaults.standard.bool(forKey: "forceThemeDark")
            isDark = dark
            // Route through DemoTheme when the forced name is a known theme (so
            // HeroUI takes the native CSS path); otherwise load the JSON directly.
            if let match = DemoTheme.allCases.first(where: { $0.resourceName == forced || $0.rawValue == forced }) {
                current = match
                match.apply(dark: dark)
            } else {
                Theme.shared.loadTheme(named: forced, dark: dark)
            }
            return
        }
        // Precedence at launch: a saved custom (generated) recipe wins, then a
        // preset, then the bundled JSON theme.
        if let data = UserDefaults.standard.data(forKey: Self.customKey),
           let cfg = try? ThemeConfig(jsonData: data) {
            activeConfig = cfg
            activeDesignSpecID = UserDefaults.standard.string(forKey: Self.designSpecKey)
            isDark = cfg.dark
            Theme.shared.apply(cfg)
        } else if let id = UserDefaults.standard.string(forKey: Self.presetKey),
                  let preset = ThemePreset.named(id) {
            presetID = id
            activeConfig = preset.config
            isDark = preset.isDark
            preset.apply()
        } else if let def = ThemePreset.named("default") {
            // Fresh launch → ThemeKit's Default preset (first in the grid, selected).
            presetID = "default"
            activeConfig = def.config
            isDark = def.isDark
            def.apply()
        } else {
            current.apply(dark: DemoTheme.storedDark)
        }
    }

    func select(_ theme: DemoTheme) {
        presetID = nil
        activeConfig = nil
        clearDesignSpec()
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        UserDefaults.standard.removeObject(forKey: Self.customKey)
        current = theme
        theme.apply(dark: isDark)
    }

    func setDark(_ dark: Bool) {
        // presets / generated recipes are single-scheme — toggling light/dark
        // returns to the bundled theme, where the scheme switch applies.
        presetID = nil
        activeConfig = nil
        clearDesignSpec()
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        UserDefaults.standard.removeObject(forKey: Self.customKey)
        isDark = dark
        current.apply(dark: dark)
    }

    /// Applies a theme preset live (and follows its light/dark scheme).
    func applyPreset(_ theme: ThemePreset) {
        presetID = theme.id
        activeConfig = theme.config
        isDark = theme.isDark
        clearDesignSpec()
        UserDefaults.standard.removeObject(forKey: Self.customKey)
        UserDefaults.standard.set(theme.id, forKey: Self.presetKey)
        theme.apply()
    }

    private func clearDesignSpec() {
        activeDesignSpecID = nil
        UserDefaults.standard.removeObject(forKey: Self.designSpecKey)
    }

    /// Commits a recipe from the Theme Configurator: applies it, persists it, and
    /// makes it the active theme so the switcher + dark state stay in sync.
    func applyGenerated(_ config: ThemeConfig) {
        applyGenerated(config, designSpecID: nil)
    }

    /// As `applyGenerated`, but records the originating design.md id (for the
    /// "active design mode" badge). Passing `nil` clears the provenance.
    func applyGenerated(_ config: ThemeConfig, designSpecID: String?) {
        presetID = nil
        activeConfig = config
        isDark = config.dark
        activeDesignSpecID = designSpecID
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        if let id = designSpecID {
            UserDefaults.standard.set(id, forKey: Self.designSpecKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.designSpecKey)
        }
        if let data = try? config.jsonData() {
            UserDefaults.standard.set(data, forKey: Self.customKey)
        }
        Theme.shared.apply(config)
    }

    /// Commits a parsed `design.md` result: applies its config and remembers which
    /// spec produced it. Reuses the existing custom-config persistence.
    func applyDesign(_ result: DesignParseResult, specID: String?) {
        applyGenerated(result.config, designSpecID: specID)
    }

    /// Re-applies whatever theme is currently active — used to discard the
    /// configurator's live preview when the user cancels.
    func reapplyActive() {
        if let cfg = activeConfig {
            Theme.shared.apply(cfg)
        } else if let id = presetID, let preset = ThemePreset.named(id) {
            preset.apply()
        } else {
            current.apply(dark: isDark)
        }
    }
}
