//
//  DynamicType.swift
//  GlobalUIComponents
//
//  Dynamic Type helpers for the design system.
//
//  The type ramp itself already scales: `TextStyle.font` is built with
//  `relativeTo:`, so every `.textStyle(_:)` grows and shrinks with the user's
//  preferred text size. What these helpers fix is the *container* — a control
//  whose height is a hard constant will clip its own label the moment the user
//  bumps their text size. Use `scaledControlHeight` instead of `.frame(height:)`
//  for anything that holds text.
//

import SwiftUI

/// A control height that scales with Dynamic Type.
///
/// Uses `minHeight` semantics: at the default text size it is identical to the
/// old fixed value, but it is free to grow so large-text labels are never
/// clipped.
struct ScaledControlHeight: ViewModifier {
    // Backing storage is initialized in `init` below (with `relativeTo: .body`),
    // so the attribute itself carries no arguments here.
    @ScaledMetric private var height: CGFloat
    private let alignment: Alignment

    init(_ base: CGFloat, alignment: Alignment) {
        _height = ScaledMetric(wrappedValue: base, relativeTo: .body)
        self.alignment = alignment
    }

    func body(content: Content) -> some View {
        content.frame(minHeight: height, alignment: alignment)
    }
}

public extension View {
    /// Replaces a hard-coded control height with one that scales with Dynamic
    /// Type. At the default text size the control is `base` points tall
    /// (unchanged); at larger accessibility sizes it grows so its text never
    /// clips. Prefer this over `.frame(height:)` for any control that holds text.
    func scaledControlHeight(_ base: CGFloat, alignment: Alignment = .center) -> some View {
        modifier(ScaledControlHeight(base, alignment: alignment))
    }

    /// Clamps Dynamic Type to a sensible range for controls that physically
    /// cannot grow without breaking their layout — fixed grids (OTP boxes),
    /// dense data rows, tightly packed numeric displays.
    ///
    /// This is the escape hatch, not the default: reach for it only when growth
    /// genuinely isn't possible. Everything else should use `scaledControlHeight`
    /// (or padding) and be allowed to grow. Defaults cap at the first
    /// accessibility size, which keeps text legible without shattering layout.
    func dynamicTypeClamp(
        _ range: ClosedRange<DynamicTypeSize> = .xSmall ... .accessibility1
    ) -> some View {
        dynamicTypeSize(range)
    }
}
