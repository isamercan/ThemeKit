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

    init() {
        current = DemoTheme.stored
        isDark = DemoTheme.storedDark
        current.apply(dark: DemoTheme.storedDark)
    }

    func select(_ theme: DemoTheme) {
        current = theme
        theme.apply(dark: isDark)
    }

    func setDark(_ dark: Bool) {
        isDark = dark
        current.apply(dark: dark)
    }
}
