//
//  GlassChrome.swift
//  ThemeKit
//
//  Liquid Glass for *chrome* surfaces (bars, floating panels, toasts) — never for
//  content. Adopts `.glassEffect` on OS 26+, falls back to a `Material` on 17–25,
//  and honours Reduce Transparency with an opaque token fill. Additive and gated, so
//  it ships on the iOS 17 minimum without breaking older runtimes.
//

import SwiftUI

private struct GlassChromeModifier<S: Shape>: ViewModifier {
    let shape: S
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        surface(content)
    }

    @ViewBuilder
    private func surface(_ content: Content) -> some View {
        if reduceTransparency {
            // Accessibility: no translucency — a solid, theme-aware fill.
            content.background(theme.background(.bgWhite), in: shape)
        } else if #available(iOS 26.0, macOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            // iOS 17–25 / macOS 14–25: the closest native translucent chrome.
            content.background(.regularMaterial, in: shape)
        }
    }
}

public extension View {
    /// Applies Liquid Glass to a **chrome** surface (a bar, floating panel, toast),
    /// clipped to `shape`. Resolves to `.glassEffect` on OS 26+, a `Material` on
    /// earlier OSes, and an opaque theme fill under Reduce Transparency. Use on
    /// chrome only — never on content, where translucency hurts legibility.
    func glassChrome<S: Shape>(in shape: S = Capsule()) -> some View {
        modifier(GlassChromeModifier(shape: shape))
    }
}
