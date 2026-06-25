//
//  LayoutDirection.swift
//  GlobalUIComponents
//
//  Right-to-left (RTL) support helpers.
//
//  SwiftUI already mirrors the *layout* for RTL languages (Arabic, Hebrew, Farsi):
//  `HStack`s reverse, `.leading`/`.trailing` swap, `.padding(.leading)` follows
//  the reading direction. What it does NOT do is flip directional *glyphs* — a
//  `chevron.right` disclosure arrow keeps pointing right even when the whole UI
//  reads right-to-left, where it should point left.
//
//  `mirrorsInRTL()` fixes exactly those glyphs. Apply it to disclosure chevrons,
//  previous/next and back arrows, and "read more" arrows. Leave purely vertical
//  glyphs (up/down chevrons) and symmetric icons (↔) alone — mirroring them is a
//  no-op at best and wrong at worst.
//

import SwiftUI

struct MirrorsInRTL: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        content.scaleEffect(
            x: layoutDirection == .rightToLeft ? -1 : 1,
            y: 1,
            anchor: .center
        )
    }
}

public extension View {
    /// Horizontally mirrors this view when the layout direction is right-to-left.
    ///
    /// Use on directional glyphs that must point the other way in RTL locales —
    /// disclosure chevrons, previous/next controls, back and "read more" arrows.
    /// Don't use it on vertical chevrons (up/down) or symmetric icons.
    func mirrorsInRTL() -> some View {
        modifier(MirrorsInRTL())
    }
}
