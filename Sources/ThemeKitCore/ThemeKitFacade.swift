//
//  ThemeKitFacade.swift
//  ThemeKit
//
//  Friendly, discoverable sugar for consumer localization, co-located with the
//  rest of the `ThemeKitStrings` API (`locale`, `register`, `languageBinding`).
//  The whole consumer story becomes:
//
//      ContentView().themeKit()               // root, once (you already add this)
//      ThemeKitStrings.setLanguage("tr")      // anywhere — the UI flips live, no restart
//
//  `.themeKit()` folds in the live-localization provider (see ThemeKit.swift),
//  so no separate `.themeKitLocalized()` is needed. `Theme.setLanguage(_:)` is a
//  shorter alias on the hub type for the same call.
//
//  NB: the facade can't be named `ThemeKit` — a type with the module's name
//  shadows module-qualified lookups (`ThemeKit.Tag`, …) and breaks them.
//

import Foundation

public extension ThemeKitStrings {
    /// Switch the language of every ThemeKit default string — live and
    /// restart-free (the `.themeKit()` root re-renders the tree, including the
    /// non-View enum/model strings). Pass a BCP-47 code (`"tr"`, `"ar"`,
    /// `"en"`), or `nil` to follow the device/app language again.
    ///
    /// ```swift
    /// ThemeKitStrings.setLanguage("tr")   // whole UI → Turkish
    /// ThemeKitStrings.setLanguage(nil)    // back to the device language
    /// ```
    ///
    /// Per-component string parameters you pass in code still win over the
    /// catalog. Requires `.themeKit()` (or `.themeKitLocalized()`) at the root.
    static func setLanguage(_ languageCode: String?) {
        locale = languageCode.map { Locale(identifier: $0) }
    }

    /// The active override language code, or `nil` when following the device.
    /// (For an explicit `Locale`, set ``locale`` directly.)
    static var currentLanguage: String? {
        locale?.identifier
    }
}

public extension Theme {
    /// Shorter alias for ``ThemeKitStrings/setLanguage(_:)-(String?)`` on the hub
    /// type — `Theme.setLanguage("tr")` flips every ThemeKit string live.
    static func setLanguage(_ languageCode: String?) {
        ThemeKitStrings.setLanguage(languageCode)
    }

    /// The active override language code, or `nil` when following the device.
    static var currentLanguage: String? {
        ThemeKitStrings.currentLanguage
    }
}
