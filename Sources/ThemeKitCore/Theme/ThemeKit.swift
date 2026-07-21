//
//  ThemeKit.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The single entry point a host app needs for theming. Apply `.themeKit()`
//  ONCE at the root (the `WindowGroup` content) and every component reads the
//  active `Theme`, reacting to runtime theme swaps.
//
//  Why it's needed: components resolve tokens from the `Theme.shared` singleton
//  (a deliberate design — no per-call environment lookups). SwiftUI therefore
//  can't infer that an arbitrary view depends on the theme, so a runtime theme
//  change wouldn't repaint views whose explicit inputs are unchanged. This
//  modifier closes that gap: it injects `Theme` into the `\.theme` environment
//  (so `@ThemeContext` / `@Environment(\.theme)` views resolve it) and — when
//  `reactToRuntimeChanges` is on — rebuilds the subtree keyed on `Theme.revision`
//  so EVERY view re-reads the regenerated tokens on a theme swap.
//

import SwiftUI

public extension View {
    /// Installs the ThemeKit theme at the app root.
    ///
    /// - Parameter reactToRuntimeChanges: when `true` (default), the subtree is
    ///   rebuilt on each theme change so a runtime swap (e.g. a configurator or a
    ///   settings toggle) repaints the whole UI. Set `false` if you only set the
    ///   theme once at launch and want to preserve navigation/scroll state across
    ///   the (then non-existent) swaps.
    ///
    /// ```swift
    /// @main struct MyApp: App {
    ///     init() { Theme.shared.applyPersistedConfig() }      // restore last theme
    ///     var body: some Scene {
    ///         WindowGroup { ContentView().themeKit() }
    ///     }
    /// }
    /// ```
    func themeKit(reactToRuntimeChanges: Bool = true) -> some View {
        modifier(ThemeKitModifier(reactToRuntimeChanges: reactToRuntimeChanges))
    }
}

private struct ThemeKitModifier: ViewModifier {
    // `@ObservedObject` (not a plain `let`) so `objectWillChange` — fired by the
    // `@Published` `revision` bump on a runtime theme swap — re-runs this body
    // and re-applies the `.id` (ADR-0007 §D3). `ViewModifier` participates in
    // `DynamicProperty` updates, so the wrapper works here exactly as in a View.
    @ObservedObject private var theme = Theme.shared
    // Same for the localization revision (ADR-0003 folded in): a language switch
    // bumps `ThemeKitStrings.observable.value` and re-runs this body.
    @ObservedObject private var strings = ThemeKitStrings.observable
    let reactToRuntimeChanges: Bool

    init(reactToRuntimeChanges: Bool) {
        self.reactToRuntimeChanges = reactToRuntimeChanges
    }

    func body(content: Content) -> some View {
        // Localization is folded in (ADR-0003): inject the effective locale and
        // an RTL-correct layout direction, and — with runtime reactions on —
        // fold ThemeKitStrings' language revision into the identity alongside the
        // theme revision. So `ThemeKit.setLanguage(_:)` re-renders the whole tree
        // (View and non-View strings alike) live, with no separate modifier —
        // `.themeKit()` at the root is all a consumer needs. The two
        // `@ObservedObject`s above register this view for both revisions.
        let locale = ThemeKitStrings.effectiveLocale
        let languageRevision = strings.value
        return Group {
            if reactToRuntimeChanges {
                // A runtime theme switch bumps `theme.revision` → the id changes
                // and the whole subtree rebuilds; the language revision does the
                // same for a live language switch.
                content.id(ThemeKitRootIdentity(theme: theme.revision, language: languageRevision))
            } else {
                content
            }
        }
        .environment(\.theme, theme)
        .environment(\.locale, locale)
        .environment(\.layoutDirection, locale.themeKitLayoutDirection)
    }
}

/// Composite identity so BOTH a theme swap and a language switch rebuild the
/// `.themeKit()` subtree — each is an independent published revision.
private struct ThemeKitRootIdentity: Hashable {
    let theme: Int
    let language: Int
}
