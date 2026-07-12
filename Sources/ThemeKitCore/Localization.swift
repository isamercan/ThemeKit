//
//  Localization.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The single bridge every ThemeKit default string flows through. Since
//  ADR-0003 its body resolves through `ThemeKitStrings` — consumer catalog
//  (live or device locale) → ThemeKit's bundled catalog → the English source —
//  so a consumer can translate the whole library by dropping a
//  `ThemeKit.xcstrings` into their app target, with no per-call code. With no
//  consumer catalog and no locale override the output is byte-identical to
//  the pre-ADR behavior. Per-component parameter overrides never reach this
//  bridge and always win.
//
//  `Bundle.module` is internal, so it can't appear directly in a *public*
//  function's default argument. This public initializer wraps the lookup — its
//  body runs in-module (where `.module` is visible) — so call sites can write
//  `String(themeKit: "…")` as a default and stay overridable.
//
//  Shipped defaults are English (the catalog's source language, regenerated
//  from source by `make l10n`); consumers add their own localizations via the
//  generated template at `Templates/ThemeKit.xcstrings`.
//

import Foundation

public extension String {
    /// Resolves a default, overridable string through ThemeKit's localization
    /// chain (ADR-0003): consumer catalog (effective language, then the
    /// consumer's English rewording) → ThemeKit's bundled catalog → the
    /// English source key.
    init(themeKit value: ThemeKitLocalizationValue) {
        self = ThemeKitStrings.resolve(value, module: .themeKit)
    }

    /// Pre-ADR-0003 entry point for callers holding an explicit
    /// `String.LocalizationValue`. Its key/arguments are not extractable, so
    /// it can only resolve against ThemeKit's own catalog — consumer catalogs
    /// are bypassed.
    @available(*, deprecated, message: "Pass a string literal — an explicit LocalizationValue bypasses consumer catalogs (ADR-0003).")
    @_disfavoredOverload
    init(themeKit key: String.LocalizationValue) {
        self = String(localized: key, bundle: .module)
    }
}

extension Bundle {
    /// The package's own resource bundle. Exposed (internally, reachable from
    /// tests via `@testable`) so callers don't collide with a consumer module's
    /// own synthesized `Bundle.module`.
    static var themeKit: Bundle { .module }
}
