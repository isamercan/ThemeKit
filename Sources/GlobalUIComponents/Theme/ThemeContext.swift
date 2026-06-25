//
//  ThemeContext.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// A lightweight theme accessor for SwiftUI views.
///
/// Use this instead of repeating `@EnvironmentObject private var theme: Theme`
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
    @EnvironmentObject private var theme: Theme

    public init() {}

    public var wrappedValue: Theme { theme }
}
