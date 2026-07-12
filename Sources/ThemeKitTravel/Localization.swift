//
//  Localization.swift
//  ThemeKitTravel
//
//  Bridges the edition's own bundled String Catalog (`Localizable.xcstrings`)
//  into default-argument expressions, mirroring `ThemeKitCore`'s
//  `String(themeKit:)`. The edition keeps a SEPARATE catalog so its domain
//  strings (traveler / payment / airport copy) don't crowd the neutral catalog,
//  and so a consumer who never imports the edition ships none of them.
//
//  Since ADR-0003 the body resolves through `ThemeKitStrings` with the
//  edition's bundle as the module fallback, so the CONSUMER experience stays
//  one file: the same `ThemeKit.xcstrings` (generated template at
//  `Templates/ThemeKit.xcstrings` — the union of both catalogs' keys)
//  translates neutral and Travel strings alike, and the live in-app language
//  switch covers the edition for free.
//
//  `Bundle.module` is internal, so it can't appear directly in a *public*
//  function's default argument. This public initializer wraps the lookup — its
//  body runs in-module (where `.module` is visible) — so call sites can write
//  `String(themeKitTravel: "…")` as a default and stay overridable.
//

import Foundation
import ThemeKitCore

public extension String {
    /// Resolves a default, overridable string through ThemeKit's localization
    /// chain (ADR-0003): consumer catalog (effective language, then the
    /// consumer's English rewording) → the edition's bundled catalog → the
    /// English source key.
    init(themeKitTravel value: ThemeKitLocalizationValue) {
        self = ThemeKitStrings.resolve(value, module: .themeKitTravel)
    }

    /// Pre-ADR-0003 entry point for callers holding an explicit
    /// `String.LocalizationValue`. Its key/arguments are not extractable, so
    /// it can only resolve against the edition's own catalog — consumer
    /// catalogs are bypassed.
    @available(*, deprecated, message: "Pass a string literal — an explicit LocalizationValue bypasses consumer catalogs (ADR-0003).")
    @_disfavoredOverload
    init(themeKitTravel key: String.LocalizationValue) {
        self = String(localized: key, bundle: .module)
    }
}

extension Bundle {
    /// The edition's own resource bundle. Exposed (internally, reachable from
    /// tests via `@testable`) so callers don't collide with `ThemeKitCore`'s
    /// `Bundle.themeKit` or a consumer module's own synthesized `Bundle.module`.
    static var themeKitTravel: Bundle { .module }
}
