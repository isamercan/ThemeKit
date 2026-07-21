//
//  ThemeContext.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A lightweight theme accessor for SwiftUI views.
///
/// Use this instead of repeating `@Environment(\.theme) private var theme`
/// in views that need app-wide theme access. Inject the theme at the root with
/// `.environment(\.theme, Theme.shared)` in pure SwiftUI flows or via
/// `ThemedHostingController` in UIKit-hosted flows.
///
/// Example:
/// ```swift
/// struct ExampleView: View {
///     @ThemeContext private var theme
/// }
/// ```
@propertyWrapper
public struct ThemeContext: DynamicProperty {
    @Environment(\.theme) private var theme

    public init() {}

    public var wrappedValue: Theme { theme }
}

// MARK: - Environment injection

private struct ThemeEnvironmentKey: EnvironmentKey {
    /// Falls back to the shared singleton, so a component reads a working theme even
    /// when nothing injected one — the singleton design stays crash-proof — while a
    /// subtree (or a preview/test) can override it with `.theme(_:)`.
    static var defaultValue: Theme { Theme.shared }
}

public extension EnvironmentValues {
    /// The active `Theme`. Defaults to `Theme.shared`; override per-subtree with
    /// `.theme(_:)`. Components read this instead of touching the singleton directly,
    /// so they can be re-themed in isolation (different brand in a subtree, a fixed
    /// theme in a preview/snapshot) without mutating global state.
    ///
    /// **What "re-themed in isolation" covers (ADR-0006).** Per-subtree `.theme(_:)`
    /// re-skins **color** completely: `theme.text(_:)` / `.background(_:)` /
    /// `.border(_:)` / `.foreground(_:)` and `theme.resolve(_:)` (the `SemanticColor`
    /// role/ladder resolver — `.solid .soft .accent .border .onSolid` and the
    /// 50…900 shade steps) all read *this* environment value, so two subtrees with
    /// different brands render correct, independent colors — including accents.
    /// **What it does not (yet) cover:** corner radius (`Theme.RadiusRole` /
    /// `RadiusKey`), spacing (`Theme.SpacingKey`), and the type scale
    /// (`TextStyle.font` / `.lineSpacing`) stay **process-global** — they resolve
    /// from `Theme.shared` regardless of a subtree override, because no shipped
    /// two-brand screen varies those per subtree and isolating them would cost a
    /// ~2000-call-site migration for a real but currently theoretical need. This is
    /// a documented, bounded limit (ADR-0006 §D5), not a silent gap: if a genuine
    /// per-subtree metric/type need appears, the same `theme.resolve(_:)`-style
    /// idiom is reserved for it.
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Re-theme this view and its descendants with a specific `Theme` instance —
    /// **color only** re-skins per subtree (semantic/brand/accent colors and every
    /// instance color accessor); corner radius, spacing, and the type scale stay
    /// process-global (they follow `Theme.shared` / the root `.themeKit()` theme).
    /// See `EnvironmentValues.theme` for the full scope (ADR-0006).
    /// At the app root prefer `.themeKit()`; use this to scope a different theme to
    /// a branch, or to pin a theme in a preview/test.
    ///
    /// A live *mutation* of `theme` after it's injected (a second `@Observable`
    /// theme reconfigured at runtime) won't repaint the subtree on its own — add
    /// `.id(theme.revision)` alongside `.theme(theme)` if that's a real need;
    /// `.themeKit()` already does this for the root.
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}
