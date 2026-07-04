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

public extension Animation {
    /// Returns the animation, or `nil` when Reduce Motion is on — so components can
    /// write `withAnimation(.snappy.ifMotionAllowed(reduceMotion)) { … }`.
    func ifMotionAllowed(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : self
    }
}
