//
//  ThemeMotion.swift
//  ThemeKit
//
//  Small shared helpers: a cached CoreImage context (creating one per render is
//  expensive) and a Reduce-Motion-aware animation shorthand so components stop
//  repeating `reduceMotion ? nil : .snappy`.
//

import SwiftUI
import CoreImage

/// One shared CoreImage context for the whole library. `CIContext` is expensive to
/// build but cheap to reuse; QRCode / Barcode render through this instead of newing
/// one up per frame. Marked unsafe because `CIContext` isn't `Sendable`, but it is
/// documented thread-safe for rendering and we only ever call `createCGImage`.
enum CoreImageContext {
    nonisolated(unsafe) static let shared = CIContext()
}

/// Two-digit zero pad, e.g. `3 → "03"`. Avoids `String(format: "%02d", Int)`, which
/// passes a 64-bit `Int` where `%d` expects a 32-bit `CInt` (undefined behaviour).
/// Values ≥ 10 (and negatives) pass through unpadded.
func zeroPad2(_ value: Int) -> String { (value >= 0 && value < 10) ? "0\(value)" : "\(value)" }

public extension Animation {
    /// Returns the animation, or `nil` when Reduce Motion is on — so components can
    /// write `withAnimation(ThemeMotion.snappy.ifMotionAllowed(reduceMotion)) { … }`.
    func ifMotionAllowed(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}

/// Spring presets equivalent to the iOS 17-only `.snappy` / `.smooth` system
/// curves, back-deployed to the iOS 15.6 floor as single-path replacements
/// (ADR-0007 §D2 rule 1). Durations come from the `Motion` token ramp and the
/// damping values live *here* — call sites never inline raw curve numbers
/// (token-fed house rule), and Reduce Motion keeps composing through the same
/// `.ifMotionAllowed` / `MicroMotion` gates as before.
///
/// When the deployment floor rises past 17, these fold back into the system
/// presets (ADR-0007 §D6 deletion checklist).
package enum ThemeMotion {
    /// The `.snappy`-equivalent damping: a quick spring with a slight bounce
    /// (system `.snappy` ≈ bounce 0.15 → dampingFraction 0.85).
    private static let snappyDamping: Double = 0.85
    /// The `.smooth`-equivalent damping: settles with no bounce.
    private static let smoothDamping: Double = 1.0

    /// Back-deployed `.snappy` at its system default duration (0.5 s).
    package static var snappy: Animation {
        .spring(response: 0.5, dampingFraction: snappyDamping)
    }

    /// Back-deployed `.snappy(duration:)` at a `Motion` token duration —
    /// `.fast` (0.2 s) is the disclosure/tree/cascader tick.
    package static func snappy(_ token: Motion) -> Animation {
        .spring(response: token.duration, dampingFraction: snappyDamping)
    }

    /// Back-deployed `.smooth` at its system default duration (0.5 s).
    package static var smooth: Animation {
        .spring(response: 0.5, dampingFraction: smoothDamping)
    }

    /// Back-deployed `.smooth(duration:)` at a `Motion` token duration.
    package static func smooth(_ token: Motion) -> Animation {
        .spring(response: token.duration, dampingFraction: smoothDamping)
    }
}
