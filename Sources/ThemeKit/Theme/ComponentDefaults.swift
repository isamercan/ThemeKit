//
//  ComponentDefaults.swift
//  ThemeKit
//
//  A subtree-level "house style" for components — default accent, corner radius and
//  elevation. Set it once with `.componentDefaults(...)` and components read it as
//  their default when the corresponding modifier isn't set explicitly. Additive and
//  Open/Closed: a per-call modifier still wins; this only fills the default.
//
//  ```swift
//  BookingScreen()
//      .componentDefaults(radius: .field, elevation: .soft, accent: .turquoise)
//  ```
//

import SwiftUI

public struct ComponentDefaults: Equatable {
    public var radius: Theme.RadiusRole?
    public var elevation: CardElevation?
    public var accent: SemanticColor?
    public init(radius: Theme.RadiusRole? = nil, elevation: CardElevation? = nil, accent: SemanticColor? = nil) {
        self.radius = radius
        self.elevation = elevation
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
    /// Sets the house-style defaults for ThemeKit components in this subtree. Only
    /// the provided fields are set; a component's explicit modifier still overrides.
    func componentDefaults(radius: Theme.RadiusRole? = nil, elevation: CardElevation? = nil, accent: SemanticColor? = nil) -> some View {
        transformEnvironment(\.componentDefaults) { d in
            if let radius { d.radius = radius }
            if let elevation { d.elevation = elevation }
            if let accent { d.accent = accent }
        }
    }
}

// CardElevation lives in Card.swift; ComponentDefaults references it.
