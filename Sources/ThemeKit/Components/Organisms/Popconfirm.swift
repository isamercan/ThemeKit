//
//  Popconfirm.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A lightweight confirmation popover anchored to its trigger element — unlike
//  the full-screen modal `Dialog`, it points at what you're confirming.
//  (Ant Popconfirm.) Apply with `.popconfirm(...)` — controlled via an
//  `isPresented:` binding, or uncontrolled (omit the binding: tapping the
//  anchor presents it, via `ControllableState`). Anchors to any of the four
//  edges (reusing `TooltipEdge`), slides along that edge with `align`, dismisses
//  on an outside tap (HeroUI Popover `closeOnPress`; opt out with
//  `dismissOnOutsideTap: false`), and can point at the trigger with
//  `showsArrow`. The confirm closure may be async, in which case the OK button
//  shows a spinner and the popover stays open until it resolves.
//
//  `.themePopover(...)` reuses the same surface/presenter for a plain titled
//  card (HeroUI Popover.Title/Description/Close) with no confirm buttons.
//

import SwiftUI

/// Shared presentation shell for all overloads (`.popconfirm` and
/// `.themePopover`): an overlay anchored to the chosen edge, fixed-size card,
/// edge placement with `align`, fade+scale transition, micro-motion animation,
/// an optional arrow pointing at the trigger, and — while presented — a
/// transparent tap-catcher behind the card that dismisses on an outside tap.
/// What the card contains is the caller's business.
private struct PopconfirmPresenter<Card: View>: ViewModifier {
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
                        .modifier(PopconfirmPlacement(edge: edge))
                        .transition(.opacity.combined(with: .scale(scale: 0.96)))
                        // While the card is up, keep VoiceOver inside it so the
                        // dimmed trigger/background isn't reachable; a two-finger
                        // scrub triggers the same dismissal as an outside tap
                        // (and, like it, is suppressed while pinned or loading).
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
    /// anchor-facing side — filled with the card surface, hairline-stroked on
    /// the two exposed edges, and overlapping the card border by 1pt so the
    /// seam opens like a speech bubble.
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

/// The Popconfirm card chrome — `md` padding on a fixed 260pt-wide white
/// surface with a small continuous corner, a 1pt hairline, and the elevated
/// token shadow. One source of truth so the standard and custom-content
/// overloads stay pixel-aligned.
private struct PopconfirmSurface: ViewModifier {
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

private struct PopconfirmModifier: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let confirmKind: FeedbackKind
    let edge: TooltipEdge
    let align: PopoverAlign
    let dismissOnOutsideTap: Bool
    let showsArrow: Bool
    let onConfirm: () async -> Void
    let onCancel: (() -> Void)?

    @State private var loading = false

    func body(content: Content) -> some View {
        content.modifier(PopconfirmPresenter(
            isPresented: $isPresented, edge: edge, align: align,
            // While the async confirm runs the popover must stay open (Cancel
            // is disabled for the same reason), so outside taps are ignored.
            dismissOnOutsideTap: dismissOnOutsideTap && !loading, showsArrow: showsArrow, card: card
        ))
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "exclamationmark.circle.fill").size(.sm).color(theme.foreground(.systemcolorsFgWarning))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if let message {
                        Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
            }
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Spacer(minLength: 0)
                ThemeButton(cancelTitle) {
                    isPresented = false; onCancel?()
                }
                .variant(.outline).size(.small).disabled(loading)
                ThemeButton(confirmTitle) {
                    Task {
                        loading = true
                        await onConfirm()
                        loading = false
                        isPresented = false
                    }
                }
                .color(confirmKind.semanticColor).size(.small).loading(loading)
            }
        }
        .modifier(PopconfirmSurface())
    }
}

/// Self-managed (uncontrolled) Popconfirm: the anchor tap presents the card,
/// no external binding needed (ADR-4). `ControllableState`'s projected binding
/// feeds the controlled `.popconfirm` path, so both entry points share one
/// presentation implementation — mirroring `SelfTooltip` over `BindingTooltip`.
private struct SelfPopconfirmModifier: ViewModifier {
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let confirmKind: FeedbackKind
    let edge: TooltipEdge
    let align: PopoverAlign
    let dismissOnOutsideTap: Bool
    let showsArrow: Bool
    let onConfirm: () async -> Void
    let onCancel: (() -> Void)?

    @ControllableState private var isPresented = false

    func body(content: Content) -> some View {
        content
            .contentShape(Rectangle())
            .onTapGesture { isPresented.toggle() }
            .popconfirm(isPresented: $isPresented, title: title, message: message,
                        confirmTitle: confirmTitle, cancelTitle: cancelTitle,
                        confirmKind: confirmKind, edge: edge, align: align,
                        dismissOnOutsideTap: dismissOnOutsideTap, showsArrow: showsArrow,
                        onConfirm: onConfirm, onCancel: onCancel)
    }
}

/// Pushes the confirm card just outside the chosen edge of its trigger,
/// separated by the small spacing token.
private struct PopconfirmPlacement: ViewModifier {
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

/// The stock titled-popover card: title + optional message with the standard
/// close affordance, on the shared Popconfirm surface. (HeroUI
/// Popover.Title/Description/Close on Popover.Content.)
private struct ThemePopoverModifier: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let edge: TooltipEdge
    let align: PopoverAlign
    let dismissOnOutsideTap: Bool
    let showsArrow: Bool

    func body(content: Content) -> some View {
        content.modifier(PopconfirmPresenter(
            isPresented: $isPresented, edge: edge, align: align,
            dismissOnOutsideTap: dismissOnOutsideTap, showsArrow: showsArrow, card: card
        ))
    }

    private var card: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                if let message {
                    Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            CloseButton { isPresented = false }.controlSize(.mini)
        }
        .modifier(PopconfirmSurface())
    }
}

public extension View {
    /// Anchored confirmation popover. `edge` chooses which side of the trigger the
    /// card points from (top / bottom / leading / trailing) and `align` slides it
    /// along that edge. While open, tapping anywhere outside the card dismisses
    /// it (HeroUI Popover `closeOnPress`; `dismissOnOutsideTap: false` opts out),
    /// and `showsArrow` adds a pointer toward the trigger. `onConfirm` may be
    /// async — while it runs the OK button spins, Cancel is disabled, and the
    /// popover stays open; it dismisses once the work completes.
    func popconfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = String(themeKit: "Yes"),
        cancelTitle: String = String(themeKit: "No"),
        confirmKind: FeedbackKind = .error,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false,
        onConfirm: @escaping () async -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(PopconfirmModifier(
            isPresented: isPresented, title: title, message: message,
            confirmTitle: confirmTitle, cancelTitle: cancelTitle, confirmKind: confirmKind,
            edge: edge, align: align, dismissOnOutsideTap: dismissOnOutsideTap,
            showsArrow: showsArrow, onConfirm: onConfirm, onCancel: onCancel
        ))
    }

    /// Self-managed confirmation popover — tapping the anchor presents it, so
    /// no external state is needed (the uncontrolled counterpart of
    /// `popconfirm(isPresented:...)`; ADR-4). Everything else matches the
    /// controlled overload: outside taps dismiss (unless opted out), tapping
    /// the anchor again toggles it closed when `dismissOnOutsideTap` is off,
    /// and an async `onConfirm` keeps the card open with a spinner until it
    /// resolves. To *observe or drive* the state from outside, use the
    /// `isPresented:` overload instead — the `Binding` is the change channel.
    func popconfirm(
        title: String,
        message: String? = nil,
        confirmTitle: String = String(themeKit: "Yes"),
        cancelTitle: String = String(themeKit: "No"),
        confirmKind: FeedbackKind = .error,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false,
        onConfirm: @escaping () async -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(SelfPopconfirmModifier(
            title: title, message: message,
            confirmTitle: confirmTitle, cancelTitle: cancelTitle, confirmKind: confirmKind,
            edge: edge, align: align, dismissOnOutsideTap: dismissOnOutsideTap,
            showsArrow: showsArrow, onConfirm: onConfirm, onCancel: onCancel
        ))
    }

    /// Anchored popover with fully custom content in place of the stock
    /// title/message/buttons layout. The card shell (white surface, hairline,
    /// elevated shadow, 260pt width) and the presentation (edge placement,
    /// `align`, outside-tap dismissal, optional arrow, transition, motion)
    /// match the standard `.popconfirm(...)`; what's inside — and how else it
    /// dismisses, typically by flipping `isPresented` — is the caller's.
    func popconfirm<V: View>(
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(PopconfirmPresenter(
            isPresented: isPresented, edge: edge, align: align,
            dismissOnOutsideTap: dismissOnOutsideTap, showsArrow: showsArrow,
            card: content().modifier(PopconfirmSurface())
        ))
    }

    /// Stock titled popover: a title, an optional message and the standard
    /// close button on the same anchored card as `.popconfirm(...)` — for
    /// contextual explanations that need no confirm/cancel decision. (HeroUI
    /// Popover with Title/Description/Close.)
    ///
    /// Named `themePopover` rather than overloading SwiftUI's own
    /// `popover(isPresented:...)`: an overload distinguished only by the
    /// `title:`/`message:` labels would be legal, but it reads as the native
    /// UIKit-backed popover while presenting an in-canvas ThemeKit card, and
    /// it risks source ambiguity if SwiftUI ever grows similar labels. The
    /// `theme` prefix follows `ThemeButton`/`themeShadow` precedent.
    func themePopover(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        edge: TooltipEdge = .top,
        align: PopoverAlign = .center,
        dismissOnOutsideTap: Bool = true,
        showsArrow: Bool = false
    ) -> some View {
        modifier(ThemePopoverModifier(
            isPresented: isPresented, title: title, message: message, edge: edge,
            align: align, dismissOnOutsideTap: dismissOnOutsideTap, showsArrow: showsArrow
        ))
    }
}

#Preview {
    // Presentation overlay — the "open" cells pin the card with a constant
    // `isPresented:` inside a taller padded frame so the anchored card stays
    // within the matrix cell.
    PreviewMatrix("Popconfirm") {
        PreviewCase("Pinned open · top edge (default)") {
            ThemeButton("Delete") {}.color(.error).variant(.soft)
                .popconfirm(isPresented: .constant(true), title: "Delete this item?", message: "This can't be undone.",
                            confirmTitle: "Delete", cancelTitle: "Cancel") {}
                .padding(.top, 130)
                .frame(maxWidth: .infinity)
        }
        PreviewCase("Pinned open · bottom edge + arrow") {
            ThemeButton("Remove card") {}.color(.error).variant(.outline)
                .popconfirm(isPresented: .constant(true), title: "Remove this card?",
                            confirmTitle: "Remove", cancelTitle: "Keep",
                            edge: .bottom, showsArrow: true) {}
                .padding(.bottom, 120)
                .frame(maxWidth: .infinity)
        }
        PreviewCase("Titled popover · pinned open") {
            ThemeButton("What's this?") {}.variant(.outline)
                .themePopover(isPresented: .constant(true), title: "Flexible fare",
                              message: "Change your flight up to 2 hours before departure at no extra cost.",
                              edge: .top, showsArrow: true)
                .padding(.top, 120)
                .frame(maxWidth: .infinity)
        }
        PreviewCase("Trigger at rest (uncontrolled — tap in live preview)") {
            ThemeButton("Clear history") {}.color(.error).variant(.soft)
                .popconfirm(title: "Clear browsing history?",
                            message: "This removes it from every signed-in device.",
                            confirmTitle: "Clear", cancelTitle: "Keep") {}
        }
    }
}

#Preview("Self-managed (uncontrolled)") {
    // No binding: tapping the anchor presents the card; tapping outside (or
    // Cancel / confirm) dismisses it. Use the `isPresented:` overload to
    // observe or drive the state from outside.
    VStack(spacing: 140) {
        ThemeButton("Clear history") {}.color(.error).variant(.soft)
            .popconfirm(title: "Clear browsing history?",
                        message: "This removes it from every signed-in device.",
                        confirmTitle: "Clear", cancelTitle: "Keep") {}
        Icon(systemName: "trash")
            .popconfirm(title: "Delete draft?", edge: .bottom, showsArrow: true) {}
    }
    .padding(80)
}

#Preview("Arrow + align + outside tap") {
    struct Demo: View {
        @State var arrow = true
        @State var pinned = true
        var body: some View {
            VStack(spacing: 140) {
                // Arrow pointing at the trigger; default outside-tap dismissal.
                ThemeButton("Remove card") { arrow.toggle() }.color(.error).variant(.outline)
                    .popconfirm(isPresented: $arrow, title: "Remove this card?",
                                confirmTitle: "Remove", cancelTitle: "Keep",
                                edge: .bottom, showsArrow: true) {}
                // Start-aligned, and pinned open: outside taps don't dismiss it.
                ThemeButton("Sign out") { pinned.toggle() }.variant(.soft)
                    .popconfirm(isPresented: $pinned, title: "Sign out of this device?",
                                edge: .top, align: .start, dismissOnOutsideTap: false) {}
            }
            .padding(80)
        }
    }
    return Demo()
}

#Preview("Titled popover") {
    struct Demo: View {
        @State var top = true
        @State var end = true
        var body: some View {
            VStack(spacing: 160) {
                ThemeButton("What's this?") { top.toggle() }.variant(.outline)
                    .themePopover(isPresented: $top, title: "Flexible fare",
                                  message: "Change your flight up to 2 hours before departure at no extra cost.",
                                  edge: .top, showsArrow: true)
                ThemeButton("End-aligned") { end.toggle() }.variant(.soft)
                    .themePopover(isPresented: $end, title: "Heads up",
                                  message: "This card hangs from the trigger's trailing edge.",
                                  edge: .bottom, align: .end)
            }
            .padding(80)
        }
    }
    return Demo()
}

#Preview("Custom content") {
    struct Demo: View {
        @State var show = true
        @State var rating = 4
        var body: some View {
            ThemeButton("Rate this stay") { show.toggle() }.variant(.outline)
                .popconfirm(isPresented: $show) {
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                        Text("How was your stay?").textStyle(.labelBase600)
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            ForEach(1...5, id: \.self) { star in
                                Button { rating = star } label: {
                                    Icon(systemName: star <= rating ? "star.fill" : "star").size(.sm)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        ThemeButton("Send") { show = false }.size(.small)
                    }
                }
                .padding(80)
        }
    }
    return Demo()
}
