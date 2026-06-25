//
//  GlobalUITheme.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The single entry point a host app needs for theming. Apply `.globalUITheme()`
//  ONCE at the root (the `WindowGroup` content) and every component reads the
//  active `Theme`, reacting to runtime theme swaps.
//
//  Why it's needed: components resolve tokens from the `Theme.shared` singleton
//  (a deliberate design — no per-call environment lookups). SwiftUI therefore
//  can't infer that an arbitrary view depends on the theme, so a runtime theme
//  change wouldn't repaint views whose explicit inputs are unchanged. This
//  modifier closes that gap: it injects `Theme` into the environment (so
//  `@ThemeContext` / `@EnvironmentObject` views react) and — when
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
    ///         WindowGroup { ContentView().globalUITheme() }
    ///     }
    /// }
    /// ```
    func globalUITheme(reactToRuntimeChanges: Bool = true) -> some View {
        modifier(GlobalUIThemeModifier(reactToRuntimeChanges: reactToRuntimeChanges))
    }
}

private struct GlobalUIThemeModifier: ViewModifier {
    @ObservedObject private var theme = Theme.shared
    let reactToRuntimeChanges: Bool

    func body(content: Content) -> some View {
        Group {
            if reactToRuntimeChanges {
                content.id(theme.revision)
            } else {
                content
            }
        }
        .environmentObject(theme)
    }
}
