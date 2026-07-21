//
//  ThemeUnevenRoundedRect.swift
//  ThemeKitCore
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): SwiftUI's
//  `UnevenRoundedRectangle` is iOS 16-only, so this per-corner rounded
//  rectangle is the one the package draws with, on every OS. Same corner
//  vocabulary and parameter order as the system convenience init
//  (`topLeadingRadius:bottomLeadingRadius:bottomTrailingRadius:
//  topTrailingRadius:style:`), so call sites migrate by renaming the type.
//
//  Fidelity notes (deliberate, documented):
//  - Corners are drawn as circular arcs; the accepted `style:` parameter keeps
//    signature parity but `.continuous` (squircle) smoothing is approximated —
//    indistinguishable at the token radii the library uses.
//  - Leading/trailing corner semantics mirror under RTL on iOS 17+ (pinned via
//    `layoutDirectionBehavior`, matching the system shape). Below iOS 17
//    custom shapes have no direction behavior, so leading renders left — the
//    shared limitation of every custom `Shape` on those OSes.
//  - `InsettableShape` is not adopted (no call site uses `strokeBorder`).
//
//  When the deployment floor rises past 16 this file is a deletion-checklist
//  entry (ADR-0007 §D6): rename call sites back to `UnevenRoundedRectangle`.
//

import SwiftUI

/// A rectangle with individually rounded corners, usable on the iOS 15.6
/// floor (`SwiftUI.UnevenRoundedRectangle` is iOS 16+). Corner terms are
/// leading/trailing; radii that together exceed an edge are scaled down
/// proportionally, like the system shape.
public struct ThemeUnevenRoundedRect: Shape {
    public var topLeadingRadius: CGFloat
    public var bottomLeadingRadius: CGFloat
    public var bottomTrailingRadius: CGFloat
    public var topTrailingRadius: CGFloat

    /// Accepted for signature parity with the system init; corner smoothing is
    /// drawn as circular arcs regardless (see the file header).
    public var style: RoundedCornerStyle

    public init(topLeadingRadius: CGFloat = 0,
                bottomLeadingRadius: CGFloat = 0,
                bottomTrailingRadius: CGFloat = 0,
                topTrailingRadius: CGFloat = 0,
                style: RoundedCornerStyle = .continuous) {
        self.topLeadingRadius = topLeadingRadius
        self.bottomLeadingRadius = bottomLeadingRadius
        self.bottomTrailingRadius = bottomTrailingRadius
        self.topTrailingRadius = topTrailingRadius
        self.style = style
    }

    public func path(in rect: CGRect) -> Path {
        // Clamp: never negative, and scale all four down proportionally when
        // two radii sharing an edge would overlap (the CSS/system rule).
        var tl = max(0, topLeadingRadius)
        var tr = max(0, topTrailingRadius)
        var bl = max(0, bottomLeadingRadius)
        var br = max(0, bottomTrailingRadius)
        let scale = min(1,
                        rect.width / max(tl + tr, .ulpOfOne),
                        rect.width / max(bl + br, .ulpOfOne),
                        rect.height / max(tl + bl, .ulpOfOne),
                        rect.height / max(tr + br, .ulpOfOne))
        tl *= scale; tr *= scale; bl *= scale; br *= scale

        // Leading = minX in path space; RTL mirroring is the shape-level
        // behavior pinned below (iOS 17+), exactly like the system shape.
        var path = Path()
        path.move(to: CGPoint(x: rect.minX + tl, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - tr, y: rect.minY))
        if tr > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - tr, y: rect.minY + tr),
                        radius: tr,
                        startAngle: .degrees(-90), endAngle: .degrees(0),
                        clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - br))
        if br > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - br, y: rect.maxY - br),
                        radius: br,
                        startAngle: .degrees(0), endAngle: .degrees(90),
                        clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX + bl, y: rect.maxY))
        if bl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bl, y: rect.maxY - bl),
                        radius: bl,
                        startAngle: .degrees(90), endAngle: .degrees(180),
                        clockwise: false)
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + tl))
        if tl > 0 {
            path.addArc(center: CGPoint(x: rect.minX + tl, y: rect.minY + tl),
                        radius: tl,
                        startAngle: .degrees(180), endAngle: .degrees(270),
                        clockwise: false)
        }
        path.closeSubpath()
        return path
    }

    /// The four radii animate, matching the system shape's animatability.
    public var animatableData: AnimatablePair<AnimatablePair<CGFloat, CGFloat>,
                                             AnimatablePair<CGFloat, CGFloat>> {
        get {
            AnimatablePair(AnimatablePair(topLeadingRadius, bottomLeadingRadius),
                           AnimatablePair(bottomTrailingRadius, topTrailingRadius))
        }
        set {
            topLeadingRadius = newValue.first.first
            bottomLeadingRadius = newValue.first.second
            bottomTrailingRadius = newValue.second.first
            topTrailingRadius = newValue.second.second
        }
    }

    /// Leading/trailing corners mirror under RTL from iOS 17 (where shape-level
    /// direction behavior exists), matching `UnevenRoundedRectangle`.
    @available(iOS 17.0, macOS 14.0, *)
    public var layoutDirectionBehavior: LayoutDirectionBehavior {
        .mirrors
    }
}
