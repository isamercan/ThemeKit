//
//  Shadows.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Shadow tokens from the Figma design system, now JSON-driven per theme so a
//  theme switch also changes elevation feel. SwiftUI drop shadows can't express
//  spread / inner / background-blur, so composite effects are approximated with
//  one or more layered drop shadows. Falls back to the in-code layers below
//  when a theme doesn't define them.
//

import SwiftUI

public enum ShadowStyle: String, CaseIterable {
    case elevated
    case tabBar
    case soft

    // Shadow color tokens (Shadow %3 / %5 / %8) and tab-bar shadow.
    private static let shadow3 = Color(hex: "3352a408")
    private static let shadow5 = Color(hex: "3352a40d")
    private static let shadow8 = Color(hex: "3352a414")

    /// Resolved layers from the active theme; falls back to the in-code spec.
    var layers: [Theme.ResolvedShadowLayer] {
        Theme.shared.shadow(self) ?? fallbackLayers
    }

    private var fallbackLayers: [Theme.ResolvedShadowLayer] {
        switch self {
        case .elevated:
            return [
                .init(color: Self.shadow8, radius: 8, x: 0, y: 6),
                .init(color: Self.shadow5, radius: 14, x: 0, y: 9),
                .init(color: Self.shadow3, radius: 24, x: 0, y: 12),
            ]
        case .tabBar:
            return [.init(color: Color(hex: "0009291a"), radius: 8, x: 0, y: 0)]
        case .soft:
            return [.init(color: Self.shadow8, radius: 6, x: 0, y: 2)]
        }
    }
}

private struct ThemeShadowModifier: ViewModifier {
    let style: ShadowStyle

    func body(content: Content) -> some View {
        style.layers.reduce(AnyView(content)) { view, layer in
            AnyView(view.shadow(color: layer.color, radius: layer.radius, x: layer.x, y: layer.y))
        }
    }
}

public extension View {
    /// Applies a design-system shadow token from the active theme.
    func themeShadow(_ style: ShadowStyle) -> some View {
        modifier(ThemeShadowModifier(style: style))
    }
}
