//
//  Popconfirm.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A lightweight confirmation popover anchored to its trigger element — unlike
//  the full-screen modal `Dialog`, it points at what you're confirming.
//  (Ant Popconfirm.) Apply with `.popconfirm(...)`. Anchors to any of the four
//  edges (reusing `TooltipEdge`); the confirm closure may be async, in which case
//  the OK button shows a spinner and the popover stays open until it resolves.
//

import SwiftUI

/// Shared presentation shell for both overloads: an overlay anchored to the
/// chosen edge, fixed-size card, edge placement, fade+scale transition, and
/// micro-motion animation. What the card contains is the caller's business.
private struct PopconfirmPresenter<Card: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: TooltipEdge
    let card: Card

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay(alignment: edge.alignment) {
            if isPresented {
                card
                    .fixedSize()
                    .modifier(PopconfirmPlacement(edge: edge))
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .animation(motion, value: isPresented)
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
    let onConfirm: () async -> Void
    let onCancel: (() -> Void)?

    @State private var loading = false

    func body(content: Content) -> some View {
        content.modifier(PopconfirmPresenter(isPresented: $isPresented, edge: edge, card: card))
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

/// Pushes the confirm card just outside the chosen edge of its trigger.
private struct PopconfirmPlacement: ViewModifier {
    let edge: TooltipEdge

    func body(content: Content) -> some View {
        switch edge {
        case .top: content.alignmentGuide(.top) { $0[.bottom] + 8 }
        case .bottom: content.alignmentGuide(.bottom) { $0[.top] - 8 }
        case .leading: content.alignmentGuide(.leading) { $0[.trailing] + 8 }
        case .trailing: content.alignmentGuide(.trailing) { $0[.leading] - 8 }
        }
    }
}

public extension View {
    /// Anchored confirmation popover. `edge` chooses which side of the trigger the
    /// card points from (top / bottom / leading / trailing). `onConfirm` may be
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
        onConfirm: @escaping () async -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(PopconfirmModifier(
            isPresented: isPresented, title: title, message: message,
            confirmTitle: confirmTitle, cancelTitle: cancelTitle, confirmKind: confirmKind,
            edge: edge, onConfirm: onConfirm, onCancel: onCancel
        ))
    }

    /// Anchored popover with fully custom content in place of the stock
    /// title/message/buttons layout. The card shell (white surface, hairline,
    /// elevated shadow, 260pt width) and the presentation (edge placement,
    /// transition, motion) match the standard `.popconfirm(...)`; what's inside
    /// — and how it dismisses, typically by flipping `isPresented` — is the
    /// caller's.
    func popconfirm<V: View>(
        isPresented: Binding<Bool>,
        edge: TooltipEdge = .top,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(PopconfirmPresenter(
            isPresented: isPresented, edge: edge,
            card: content().modifier(PopconfirmSurface())
        ))
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            ThemeButton("Delete") { show.toggle() }.color(.error).variant(.soft)
                .popconfirm(isPresented: $show, title: "Delete this item?", message: "This can't be undone.",
                            confirmTitle: "Delete", cancelTitle: "Cancel") {}
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
