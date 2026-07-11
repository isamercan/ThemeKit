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
//  `Bundle.module` is internal, so it can't appear directly in a *public*
//  function's default argument. This public initializer wraps the lookup — its
//  body runs in-module (where `.module` is visible) — so call sites can write
//  `String(themeKitTravel: "…")` as a default and stay overridable.
//
//  Shipped defaults are English (the catalog's source language); consumers can
//  add their own localizations, and every user-facing string also remains
//  overridable via API parameters.
//

import Foundation

public extension String {
    /// Resolves a default, overridable string from ThemeKitTravel's bundled
    /// String Catalog, falling back to the English source key.
    ///
    /// Note: under a plain `swift build`/`swift test` SwiftPM copies the
    /// `.xcstrings` verbatim (it doesn't run the catalog compiler), so only the
    /// English source resolves there. Under Xcode / `xcodebuild` the catalog is
    /// compiled and all bundled localizations resolve.
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
