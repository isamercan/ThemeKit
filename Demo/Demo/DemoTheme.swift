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

    var id: String { rawValue }

    /// The JSON resource name bundled in the package.
    var resourceName: String {
        switch self {
        case .default: return "defaultTheme"
        case .ocean: return "oceanTheme"
        case .sunset: return "sunsetTheme"
        }
    }

    var label: String {
        switch self {
        case .default: return "Default"
        case .ocean: return "Ocean"
        case .sunset: return "Sunset"
        }
    }

    private static let storageKey = "selectedTheme"
    private static let darkKey = "selectedThemeDark"

    /// Applies the theme (light or dark variant) and persists the choice.
    func apply(dark: Bool) {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
        UserDefaults.standard.set(dark, forKey: Self.darkKey)
        Theme.shared.loadTheme(named: resourceName, dark: dark)
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

    private static let presetKey = "selectedThemePreset"
    private static let customKey = "selectedThemeCustomConfig"

    init() {
        current = DemoTheme.stored
        isDark = DemoTheme.storedDark
        // Precedence at launch: a saved custom (generated) recipe wins, then a
        // preset, then the bundled JSON theme.
        if let data = UserDefaults.standard.data(forKey: Self.customKey),
           let cfg = try? ThemeConfig(jsonData: data) {
            activeConfig = cfg
            isDark = cfg.dark
            Theme.shared.apply(cfg)
        } else if let id = UserDefaults.standard.string(forKey: Self.presetKey),
                  let preset = ThemePreset.named(id) {
            presetID = id
            activeConfig = preset.config
            isDark = preset.isDark
            preset.apply()
        } else {
            current.apply(dark: DemoTheme.storedDark)
        }
    }

    func select(_ theme: DemoTheme) {
        presetID = nil
        activeConfig = nil
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
        UserDefaults.standard.removeObject(forKey: Self.customKey)
        UserDefaults.standard.set(theme.id, forKey: Self.presetKey)
        theme.apply()
    }

    /// Commits a recipe from the Theme Configurator: applies it, persists it, and
    /// makes it the active theme so the switcher + dark state stay in sync.
    func applyGenerated(_ config: ThemeConfig) {
        presetID = nil
        activeConfig = config
        isDark = config.dark
        UserDefaults.standard.removeObject(forKey: Self.presetKey)
        if let data = try? config.jsonData() {
            UserDefaults.standard.set(data, forKey: Self.customKey)
        }
        Theme.shared.apply(config)
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
