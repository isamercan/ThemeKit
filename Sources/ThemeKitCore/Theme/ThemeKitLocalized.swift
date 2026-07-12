//
//  ThemeKitLocalized.swift
//  ThemeKit
//
//  ADR-0003 §D4 — the view layer of the localization override. The root
//  provider makes a tree live-localizable: it observes `ThemeKitStrings`'
//  revision and, on every language change, re-injects the effective
//  `\.locale` (+ the matching `\.layoutDirection` for RTL languages) and
//  re-identifies the subtree.
//
//  Why `.id(revision)`: ThemeKit's default strings resolve during body
//  construction into plain `String`s — they are not SwiftUI dependencies, so
//  re-injecting `\.locale` alone would re-render only the components that
//  read it. Re-identifying the root subtree is the one mechanism that
//  guarantees EVERY body re-runs — including the strings resolved in enum /
//  model computed properties outside the View graph (they re-execute when
//  the bodies that call them do). Verified by a compiled re-render probe:
//  without the identity reset a global-only child keeps its stale language;
//  with it, both View strings and non-View enum strings flip live.
//
//  Documented cost (inherent to restart-free switching): view-local `@State`
//  below the root resets on switch. App state held in observable models and
//  navigation state stored outside the tree survive.
//

import Foundation
import SwiftUI

public extension View {
    /// Makes this tree live-localizable — apply ONCE at the app root.
    ///
    /// Observes ``ThemeKitStrings``: on every ``ThemeKitStrings/locale`` (or
    /// ``ThemeKitStrings/register(bundle:table:)``) change it re-injects the
    /// effective `\.locale`, flips `\.layoutDirection` for right-to-left
    /// languages (ar, he, fa, ur, …), and re-identifies the subtree so every
    /// ThemeKit default string — View and non-View alike — re-resolves in the
    /// new language. No restart.
    ///
    /// ```swift
    /// WindowGroup {
    ///     RootView().themeKitLocalized()
    /// }
    /// // Anywhere below (e.g. a settings screen):
    /// LanguageSwitcher([.init(code: "en"), .init(code: "tr")],
    ///                  selection: ThemeKitStrings.languageBinding)
    /// ```
    ///
    /// > Note: the identity reset clears view-local `@State` under the root —
    /// > the standard trade-off of restart-free language switching.
    func themeKitLocalized() -> some View {
        modifier(ThemeKitLocalizedRoot())
    }

    /// Scopes `\.locale` (and the matching `\.layoutDirection`) to this
    /// subtree — for previews, snapshots, and the locale-reading components
    /// (date/number formatting, exonyms, …).
    ///
    /// > Important: this does NOT change the language of ThemeKit's catalog
    /// > strings. Default strings resolve inside a `String` initializer,
    /// > which can never read `@Environment` — per-subtree string language
    /// > (two languages on one screen) is physically impossible there. Use
    /// > ``ThemeKitStrings/locale`` + ``themeKitLocalized()`` for the
    /// > process-wide string language (ADR-0003 known limitation).
    func themeKitLocale(_ locale: Locale) -> some View {
        environment(\.locale, locale)
            .environment(\.layoutDirection, locale.themeKitLayoutDirection)
    }
}

/// The root provider behind ``SwiftUICore/View/themeKitLocalized()``.
private struct ThemeKitLocalizedRoot: ViewModifier {
    func body(content: Content) -> some View {
        // Reading `observable.value` during body registers this view with
        // Observation, so every revision bump re-runs it; using the value as
        // the subtree identity then forces the full re-render (see header).
        let locale = ThemeKitStrings.effectiveLocale
        return content
            .environment(\.locale, locale)
            .environment(\.layoutDirection, locale.themeKitLayoutDirection)
            .id(ThemeKitStrings.observable.value)
    }
}

extension Locale {
    /// The layout direction this locale's language writes in —
    /// `.rightToLeft` for ar/he/fa/ur/…, else `.leftToRight`.
    var themeKitLayoutDirection: LayoutDirection {
        language.characterDirection == .rightToLeft ? .rightToLeft : .leftToRight
    }
}
