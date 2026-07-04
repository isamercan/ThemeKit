//
//  ComponentDensity.swift
//  ThemeKit
//
//  ThemeKit sizing has two complementary axes, on purpose:
//
//   • DENSITY (this file) — the *spacing* axis. Set once on a subtree
//     (`.componentDensity(.compact)`) and every component tightens or relaxes its
//     intrinsic spacing/padding together. It scales gaps, not type or control heights.
//   • SIZE (per-component `.size(_:)`) — the *dimension* axis. Discrete tiers
//     (`.small`/`.medium`/`.large`) pick type ramp + control height for one component.
//
//  They stack: `PriceTag(x).size(.large)` inside a `.componentDensity(.compact)`
//  screen is a large price with tight surrounding spacing.
//

import SwiftUI

/// How tightly components pack their intrinsic spacing and padding.
public enum ComponentDensity: String, CaseIterable, Sendable {
    /// Dense — dashboards, data-heavy lists.
    case compact
    /// The default balance.
    case regular
    /// Airy — marketing surfaces, onboarding.
    case spacious

    /// Multiplier applied to a component's intrinsic spacing/padding.
    public var spacingScale: CGFloat {
        switch self {
        case .compact: return 0.8
        case .regular: return 1
        case .spacious: return 1.25
        }
    }

    /// Scales an intrinsic spacing/padding value for this density.
    public func scale(_ value: CGFloat) -> CGFloat { value * spacingScale }
}

private struct ComponentDensityKey: EnvironmentKey {
    static let defaultValue: ComponentDensity = .regular
}

public extension EnvironmentValues {
    /// The active component density for this subtree (default `.regular`).
    var componentDensity: ComponentDensity {
        get { self[ComponentDensityKey.self] }
        set { self[ComponentDensityKey.self] = newValue }
    }
}

public extension View {
    /// Sets the packing density for every ThemeKit component in this subtree.
    ///
    /// ```swift
    /// FlightResultsList().componentDensity(.compact)
    /// ```
    func componentDensity(_ density: ComponentDensity) -> some View {
        environment(\.componentDensity, density)
    }
}
