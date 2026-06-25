//
//  Localization.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Bridges the package's bundled String Catalog (`Localizable.xcstrings`) into
//  default-argument expressions.
//
//  `Bundle.module` is internal, so it can't appear directly in a *public*
//  function's default argument. This public initializer wraps the lookup — its
//  body runs in-module (where `.module` is visible) — so call sites can write
//  `String(globalUIComponents: "…")` as a default and stay overridable.
//
//  Shipped defaults are English (the catalog's source language); a `tr`
//  translation ships too, and consumers can add their own localizations.
//

import Foundation

public extension String {
    /// Resolves a default, overridable string from GlobalUIComponents' bundled
    /// String Catalog, falling back to the English source key.
    ///
    /// Note: under a plain `swift build`/`swift test` SwiftPM copies the
    /// `.xcstrings` verbatim (it doesn't run the catalog compiler), so only the
    /// English source resolves there. Under Xcode / `xcodebuild` the catalog is
    /// compiled and all bundled localizations (e.g. `tr`) resolve.
    init(globalUIComponents key: String.LocalizationValue) {
        self = String(localized: key, bundle: .module)
    }
}

extension Bundle {
    /// The package's own resource bundle. Exposed (internally, reachable from
    /// tests via `@testable`) so callers don't collide with a consumer module's
    /// own synthesized `Bundle.module`.
    static var globalUIComponents: Bundle { .module }
}
