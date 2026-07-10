//
//  AnchoredPopover.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The shared presentation engine behind every anchored card in the kit —
//  `.popconfirm`, the titled and custom-content `.themePopover`, and (Wave 2/3)
//  HoverCard / the context-menu preview. Extracted from Popconfirm so those
//  siblings ride one presenter instead of re-deriving edge placement, outside-
//  tap dismissal, the arrow and the card shell. Internal — not public surface.
//

import SwiftUI

/// Overlay anchored to the chosen edge of its trigger: a fixed-size card placed
/// with `align`, a fade+scale transition, micro-motion animation, an optional
/// arrow pointing at the trigger, and — while presented — a transparent
/// tap-catcher behind the card that dismisses on an outside tap. What the card
/// contains is the caller's business.
struct AnchoredPopoverPresenter<Card: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: TooltipEdge
    var align: PopoverAlign = .center
    var dismissOnOutsideTap: Bool = true
    var showsArrow: Bool = false
    let card: Card

    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .overlay { // Behind the card overlay below; only mounted while open.
                if isPresented && dismissOnOutsideTap {
                    PopoverTapCatcher { isPresented = false }
                }
            }
            .overlay(alignment: edge.alignment(align)) {
                if isPresented {
                    decoratedCard
                        .modifier(AnchoredPopoverPlacement(edge: edge))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        // While the card is up, keep VoiceOver inside it so the
                        // dimmed trigger/background isn't reachable; a two-finger
                        // scrub triggers the same dismissal as an outside tap.
                        .accessibilityAddTraits(.isModal)
                        .accessibilityAction(.escape) {
                            if dismissOnOutsideTap { isPresented = false }
                        }
                        .zIndex(1)
                }
            }
            .animation(motion, value: isPresented)
    }

    /// The fixed-size card, optionally with the shared tooltip arrow on its
    /// anchor-facing side — filled with the card surface, hairline-stroked, and
    /// overlapping the card border by 1pt so the seam opens like a speech bubble.
    @ViewBuilder private var decoratedCard: some View {
        let sized = card.fixedSize()
        if showsArrow {
            let arrow = TooltipArrow(edge: edge)
                .fill(theme.background(.bgWhite))
                .overlay(TooltipArrow(edge: edge).stroke(theme.border(.borderPrimary), lineWidth: 1))
                // Path apex is drawn in absolute coordinates; mirror it with
                // the layout so it keeps pointing at the trigger under RTL.
                .flipsForRightToLeftLayoutDirection(true)
                .frame(width: edge.isVertical ? 14 : 7, height: edge.isVertical ? 7 : 14)
                .zIndex(1) // Draw over the card's border along the shared base.
            switch edge {
            case .top: VStack(spacing: -1) { sized; arrow }
            case .bottom: VStack(spacing: -1) { arrow; sized }
            case .leading: HStack(spacing: -1) { sized; arrow }
            case .trailing: HStack(spacing: -1) { arrow; sized }
            }
        } else {
            sized
        }
    }
}

/// The anchored-card chrome — `md` padding on a fixed 260pt-wide white surface
/// with a small continuous corner, a 1pt hairline, and the elevated token
/// shadow. One source of truth so every overload stays pixel-aligned.
struct AnchoredCardSurface: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(Theme.SpacingKey.md.value)
            .frame(width: 260)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
            .themeShadow(.elevated)
    }
}

/// Pushes the card just outside the chosen edge of its trigger, separated by
/// the small spacing token.
struct AnchoredPopoverPlacement: ViewModifier {
    let edge: TooltipEdge

    private var gap: CGFloat { Theme.SpacingKey.sm.value }

    func body(content: Content) -> some View {
        switch edge {
        case .top: content.alignmentGuide(.top) { $0[.bottom] + gap }
        case .bottom: content.alignmentGuide(.bottom) { $0[.top] - gap }
        case .leading: content.alignmentGuide(.leading) { $0[.trailing] + gap }
        case .trailing: content.alignmentGuide(.trailing) { $0[.leading] - gap }
        }
    }
}

public extension View {
    /// Anchored popover with fully custom content on the standard card shell —
    /// the `.popconfirm` engine under the *popover* name, for non-confirmation
    /// content (a filter panel, a mini form, a rich tooltip). Same placement
    /// (`edge` + `align`), outside-tap dismissal, optional arrow and motion as
    /// the titled `themePopover(isPresented:title:message:...)`.
    func themePopover<V: View>(
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(AnchoredPopoverPresenter(
            isPresented: isPresented, edge: edge, align: align,
            dismissOnOutsideTap: dismissOnOutsideTap, showsArrow: showsArrow,
            card: content().modifier(AnchoredCardSurface())
        ))
    }
}
