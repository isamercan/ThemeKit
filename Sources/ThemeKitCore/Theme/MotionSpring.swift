//
//  MotionSpring.swift
//  ThemeKit
//  Created by İsa Mercan on 05.10.2026.
//
//  Physical spring tokens, named by what they move. Each is a stiffness and a damping ratio —
//  the numbers Jetpack Compose and Material 3 use — so an iOS and an Android app can share one
//  motion language: `response = 2π / √stiffness`, `dampingFraction = dampingRatio`, and the
//  animation is `.interpolatingSpring(stiffness:damping:)` with `damping = 2 · ratio · √stiffness`
//  (iOS 15.6 floor). Gate them like the rest: `MicroMotion.animation(.layout, enabled:reduceMotion:)`.
//

import SwiftUI

public enum MotionSpring: String, CaseIterable, Sendable {
    /// A value or a colour settling — a chevron's turn, a fill's change. Compose's `spring()`.
    case value
    /// Something appearing, growing or moving into place — a section opening, a list's rows,
    /// a scroll to a field. Compose's visibility, size and slide default.
    case layout
    /// A sheet or a panel rising. Material 3's default spatial spring.
    case sheet
    /// A scrim or a fade under a sheet. Material 3's default effects spring.
    case effect
    /// A sheet or a panel leaving. Material 3's fast effects spring.
    case exit
    /// One beat of a shake.
    case nudge
    /// A shake coming to rest, with a little bounce.
    case settle

    /// How stiff the spring is (mass 1).
    public var stiffness: Double {
        switch self {
        case .value, .settle: return 1500
        case .layout: return 400
        case .sheet: return 700
        case .effect: return 1600
        case .exit: return 3800
        case .nudge: return 6000
        }
    }

    /// 1 is critically damped (no overshoot); below 1 bounces.
    public var dampingRatio: Double {
        switch self {
        case .sheet: return 0.9
        case .settle: return 0.5
        default: return 1
        }
    }

    /// SwiftUI's `response`: the undamped period, `2π / √stiffness` seconds.
    public var response: Double { 2 * .pi / stiffness.squareRoot() }

    /// The spring as an animation.
    public var animation: Animation {
        .interpolatingSpring(mass: 1, stiffness: stiffness, damping: 2 * dampingRatio * stiffness.squareRoot())
    }
}
