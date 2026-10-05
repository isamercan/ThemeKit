//
//  ComponentMotion.swift
//  ThemeKit
//  Created by İsa Mercan on 05.10.2026.
//
//  Opt-in motion for two components whose default stays as it was:
//
//  - `accordionMotion(_:)` — the spring an `Accordion` opens and closes on (`MotionSpring.layout` is
//    Compose's expand), instead of the eased `Motion.base`.
//  - `tooltipScalesIn(_:)` — a tooltip grows out of its arrow as it appears, instead of only fading.
//
//  Both are gated like every micro-animation: Reduce Motion or `microAnimations(false)` snap.
//

import SwiftUI

private struct AccordionMotionKey: EnvironmentKey {
    static let defaultValue: MotionSpring? = nil
}

private struct TooltipScalesInKey: EnvironmentKey {
    static let defaultValue = false
}

public extension EnvironmentValues {
    /// The spring accordions open and close on; `nil` (the default) keeps `Motion.base`.
    var accordionMotion: MotionSpring? {
        get { self[AccordionMotionKey.self] }
        set { self[AccordionMotionKey.self] = newValue }
    }

    /// Whether tooltips grow out of their arrow as they appear. `false` by default: they fade.
    var tooltipScalesIn: Bool {
        get { self[TooltipScalesInKey.self] }
        set { self[TooltipScalesInKey.self] = newValue }
    }
}

public extension View {
    /// Opens and closes the accordions in this subtree on `spring` — `.layout` for Compose's expand.
    /// `nil` keeps the default eased motion.
    func accordionMotion(_ spring: MotionSpring?) -> some View {
        environment(\.accordionMotion, spring)
    }

    /// Lets the tooltips in this subtree grow out of their arrow, on `MotionSpring.layout`.
    func tooltipScalesIn(_ on: Bool = true) -> some View {
        environment(\.tooltipScalesIn, on)
    }
}

extension TooltipEdge {
    /// Where the bubble's arrow is, as a point in the bubble — what it grows from: the bubble's
    /// side facing the anchor, at `align` along it.
    func arrowAnchor(_ align: PopoverAlign, layoutDirection: LayoutDirection) -> UnitPoint {
        let isRTL = layoutDirection == .rightToLeft
        let along: CGFloat
        switch align {
        case .start: along = isRTL ? 1 : 0
        case .center: along = 0.5
        case .end: along = isRTL ? 0 : 1
        }
        switch self {
        case .top: return UnitPoint(x: along, y: 1)
        case .bottom: return UnitPoint(x: along, y: 0)
        case .leading: return UnitPoint(x: isRTL ? 0 : 1, y: 0.5)
        case .trailing: return UnitPoint(x: isRTL ? 1 : 0, y: 0.5)
        }
    }
}
