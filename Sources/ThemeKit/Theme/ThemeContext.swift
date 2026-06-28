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
/// `.environmentObject(Theme.shared)` in pure SwiftUI flows or via
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
    var theme: Theme {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

public extension View {
    /// Re-theme this view and its descendants with a specific `Theme` instance.
    /// At the app root prefer `.themeKit()`; use this to scope a different theme to
    /// a branch, or to pin a theme in a preview/test.
    func theme(_ theme: Theme) -> some View {
        environment(\.theme, theme)
    }
}
