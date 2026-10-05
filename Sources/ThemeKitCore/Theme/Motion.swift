//
//  Motion.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Motion tokens — durations + easing presets for consistent animation.
//

import SwiftUI

public enum Motion: String, CaseIterable {
    case instant
    case fast
    case base
    case slow
    case slower

    /// Duration in seconds.
    public var duration: Double {
        switch self {
        case .instant: return 0.10
        case .fast: return 0.20
        case .base: return 0.30
        case .slow: return 0.45
        case .slower: return 0.60
        }
    }

    /// Standard eased animation for this duration.
    public var animation: Animation {
        .easeInOut(duration: duration)
    }

    /// Spring suited to interactive, emphasized transitions.
    public var spring: Animation {
        .spring(response: duration, dampingFraction: 0.82)
    }

    /// Material's standard curve, `(0.4, 0, 0.2, 1)` — quick to start, long to settle; Compose's
    /// `FastOutSlowInEasing`. For a change that moves within the screen: a panel opening, a chevron
    /// turning. Same platform motion on both apps when a design system pairs them.
    public var standard: Animation {
        .timingCurve(0.4, 0, 0.2, 1, duration: duration)
    }

    /// The entering curve, `(0, 0, 0.2, 1)` — Compose's `LinearOutSlowInEasing`.
    public var decelerate: Animation {
        .timingCurve(0, 0, 0.2, 1, duration: duration)
    }

    /// The leaving curve, `(0.4, 0, 1, 1)` — Compose's `FastOutLinearInEasing`.
    public var accelerate: Animation {
        .timingCurve(0.4, 0, 1, 1, duration: duration)
    }
}
