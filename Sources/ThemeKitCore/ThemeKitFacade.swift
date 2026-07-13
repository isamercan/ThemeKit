//
//  ThemeKitFacade.swift
//  ThemeKit
//
//  Friendly, discoverable localization sugar on the hub `Theme` type. The whole
//  consumer story:
//
//      ContentView().themeKit()      // root, once (you already add this for theming)
//      Theme.setLanguage("tr")       // anywhere — the UI flips live, no restart
//
//  `.themeKit()` folds in the live-localization provider (see ThemeKit.swift), so no
//  separate `.themeKitLocalized()` is needed. The lower-level knobs stay on
//  `ThemeKitStrings` (`locale`, `register(bundle:table:)`, `languageBinding`).
//
//  NB: this sugar can't live on a top-level `ThemeKit` type — a type with the
//  module's name shadows module-qualified lookups (`ThemeKit.Tag`, …) and breaks
//  them; `Theme` is the hub type consumers already use.
//

import Foundation

public extension Theme {
    /// Switch the language of every ThemeKit default string — live and restart-free
    /// (the `.themeKit()` root re-renders the tree, including the non-View enum/model
    /// strings). Pass a BCP-47 code (`"tr"`, `"ar"`, `"en"`), or `nil` to follow the
    /// device/app language again.
    ///
    /// ```swift
    /// Theme.setLanguage("tr")   // whole UI → Turkish
    /// Theme.setLanguage(nil)    // back to the device language
    /// ```
    ///
    /// Per-component string parameters you pass in code still win over the catalog,
    /// and this requires `.themeKit()` (or `.themeKitLocalized()`) at the root. Your
    /// `ThemeKit.xcstrings` in the app target is picked up automatically (zero-config,
    /// `Bundle.main`); for a catalog in an app extension / framework, call
    /// ``ThemeKitStrings/register(bundle:table:)`` once at launch.
    static func setLanguage(_ languageCode: String?) {
        ThemeKitStrings.locale = languageCode.map { Locale(identifier: $0) }
    }

    /// The active override language code, or `nil` when following the device.
    static var currentLanguage: String? {
        ThemeKitStrings.locale?.identifier
    }
}

public extension ThemeKitStrings {
    /// - Warning: Renamed. Use ``Theme/setLanguage(_:)`` — the friendlier hub-type
    ///   spelling. (Deprecated in 1.x; removed at 2.0.)
    @available(*, deprecated, renamed: "Theme.setLanguage(_:)",
               message: "Use Theme.setLanguage(_:) — the friendlier hub-type API.")
    static func setLanguage(_ languageCode: String?) {
        locale = languageCode.map { Locale(identifier: $0) }
    }

    /// - Warning: Renamed. Use ``Theme/currentLanguage``. (Deprecated in 1.x; removed at 2.0.)
    @available(*, deprecated, renamed: "Theme.currentLanguage",
               message: "Use Theme.currentLanguage.")
    static var currentLanguage: String? {
        locale?.identifier
    }
}
