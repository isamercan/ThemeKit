//
//  MicroMotion.swift
//  ThemeKit
//  Created by İsa Mercan on 26.06.2026.
//
//  Theme-wide + per-component switch for the library's built-in micro-animations.
//  Components animate only *micro* state changes — a press scale, a selection
//  slide, a value tick — never showy motion. This switch turns that motion off
//  globally or for one component; the system Reduce Motion setting always wins.
//
//    RootView().microAnimations(false)   // theme-wide off
//    SomeComponent().microAnimations(false)   // just this one off
//
//  Inside a component, resolve the effective animation with:
//    @Environment(\.microAnimations) var micro
//    @Environment(\.accessibilityReduceMotion) var reduceMotion
//    .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: state)
//

import SwiftUI

private struct MicroAnimationsKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {
    /// Whether ThemeKit components play their built-in micro-animations.
    /// Defaults to `true`. Set it once at the app root for a theme-wide switch,
    /// or on any view/component to override just that subtree. The system
    /// **Reduce Motion** setting disables motion regardless of this flag.
    var microAnimations: Bool {
        get { self[MicroAnimationsKey.self] }
        set { self[MicroAnimationsKey.self] = newValue }
    }
}

public extension View {
    /// Enable or disable ThemeKit micro-animations for this view and its children.
    ///
    /// - At the app root it's a **theme-wide** switch.
    /// - On a single component it overrides **just that one**.
    ///
    /// Reduce Motion still wins, so motion-sensitive users are always honored.
    func microAnimations(_ enabled: Bool) -> some View {
        environment(\.microAnimations, enabled)
    }
}

/// Resolves the effective micro-animation, honoring both the `microAnimations`
/// switch and the system Reduce Motion setting.
public enum MicroMotion {
    /// The animation to use, or `nil` when motion is off (switch off *or* Reduce
    /// Motion on). Pass the result straight to `.animation(_:value:)` — a `nil`
    /// animation makes the state change apply instantly, with no motion.
    public static func animation(
        _ token: Motion = .fast,
        enabled: Bool,
        reduceMotion: Bool
    ) -> Animation? {
        (enabled && !reduceMotion) ? token.animation : nil
    }
}

/// A subtle, gated press-scale for tappable surfaces that aren't already driven by
/// a ThemeKit `ButtonStyle`. Micro by design (default 0.97). Reads `microAnimations`
/// + Reduce Motion from the environment and snaps (no motion) when either is off.
public extension View {
    func microPressScale(_ isPressed: Bool, scale: CGFloat = 0.97) -> some View {
        modifier(MicroPressScale(isPressed: isPressed, scale: scale))
    }
}

private struct MicroPressScale: ViewModifier {
    let isPressed: Bool
    let scale: CGFloat
    @Environment(\.microAnimations) private var enabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var on: Bool { enabled && !reduceMotion }

    func body(content: Content) -> some View {
        content
            .scaleEffect(on && isPressed ? scale : 1)
            .animation(on ? Motion.instant.animation : nil, value: isPressed)
    }
}
