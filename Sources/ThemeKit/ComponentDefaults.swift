//
//  ComponentDefaults.swift
//  ThemeKit
//
//  A subtree-level "house style" for components — a default accent. Set it once
//  with `.componentDefaults(accent:)` and components read it as their default
//  when the corresponding modifier isn't set explicitly. Additive and
//  Open/Closed: a per-call modifier still wins; this only fills the default.
//
//  ```swift
//  BookingScreen()
//      .componentDefaults(accent: .turquoise)
//  ```
//

import SwiftUI

public struct ComponentDefaults: Equatable {
    public var accent: SemanticColor?
    public init(accent: SemanticColor? = nil) {
        self.accent = accent
    }
}

private struct ComponentDefaultsKey: EnvironmentKey {
    nonisolated(unsafe) static let defaultValue = ComponentDefaults()   // immutable empty default — safe
}

public extension EnvironmentValues {
    var componentDefaults: ComponentDefaults {
        get { self[ComponentDefaultsKey.self] }
        set { self[ComponentDefaultsKey.self] = newValue }
    }
}

public extension View {
    /// Sets the house-style default accent for ThemeKit components in this
    /// subtree; a component's explicit `.accent(_:)` modifier still overrides.
    func componentDefaults(accent: SemanticColor? = nil) -> some View {
        transformEnvironment(\.componentDefaults) { d in
            if let accent { d.accent = accent }
        }
    }
}
