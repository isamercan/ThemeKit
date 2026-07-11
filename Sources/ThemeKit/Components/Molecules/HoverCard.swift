//
//  HoverCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A preview card that appears on long-press (touch) or pointer hover
//  (iPad/macOS), riding the shared anchored-popover engine. (HeroUI Pro "Hover
//  Card".) Self-managed — pressing/hovering is the intent, so there's no
//  binding; VoiceOver users get an explicit "Show preview" action.
//

import SwiftUI

private struct HoverCardModifier<CardContent: View>: ViewModifier {
    let edge: TooltipEdge
    let align: PopoverAlign
    let card: CardContent

    @State private var isPresented = false

    func body(content: Content) -> some View {
        content
            .onLongPressGesture(minimumDuration: 0.35) {
                Haptics.impact()
                isPresented = true
            }
            // Pointer devices (iPad trackpad, macOS): reveal on hover-in, hide
            // on hover-out. Touch falls through to the long-press above.
            .onHover { hovering in
                isPresented = hovering
            }
            .accessibilityAction(named: Text(String(themeKit: "Show preview"))) { isPresented = true }
            .modifier(AnchoredPopoverPresenter(
                isPresented: $isPresented, edge: edge, align: align,
                dismissOnOutsideTap: true, showsArrow: true,
                card: card.modifier(AnchoredCardSurface())
            ))
    }
}

public extension View {
    /// Show a preview `content` card anchored to this view on **long-press**
    /// (touch) or **pointer hover** (iPad/macOS). The card uses the standard
    /// popover shell (white surface, hairline, elevated shadow, arrow) and
    /// dismisses on an outside tap or when the pointer leaves.
    ///
    ///     Avatar(.initials("AB"))
    ///         .hoverCard(edge: .bottom) {
    ///             VStack(alignment: .leading, spacing: 4) {
    ///                 Text("Ada Byron").textStyle(.labelBase600)
    ///                 Text("Product designer").textStyle(.bodySm400)
    ///             }
    ///         }
    func hoverCard<V: View>(
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(HoverCardModifier(edge: edge, align: align, card: content()))
    }
}

#Preview {
    // Overlay component — the card only appears on long-press (touch) or
    // pointer hover, so each cell shows its resting trigger; interact in the
    // live preview to reveal the anchored card.
    PreviewMatrix("HoverCard") {
        PreviewCase("Text trigger · card below") {
            Text("Long-press / hover me")
                .textStyle(.labelBase600)
                .hoverCard(edge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Preview card").textStyle(.labelBase600)
                        Text("Long-press on touch, hover with a pointer.").textStyle(.bodySm400)
                    }
                }
        }
        PreviewCase("Icon trigger · card above") {
            Icon(systemName: "info.circle")
                .size(.lg)
                .hoverCard(edge: .top) {
                    Text("A quick contextual preview.").textStyle(.bodySm400)
                }
        }
    }
}
