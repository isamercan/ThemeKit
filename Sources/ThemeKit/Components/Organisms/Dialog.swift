//
//  Dialog.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A modal dialog (title / message / up to two actions) presented over
//  a dimmed scrim via the `.dialog(...)` modifier. Two slotted variants sit next
//  to the fixed layout: `.dialog(content:footer:)` (scrollable body + pinned
//  footer) and `.dialog(content:)` (the whole card interior is caller-drawn).
//
//  CardStyle exception: the dialog shell deliberately does NOT read
//  `@Environment(\.cardStyle)`. It is floating modal chrome — Liquid Glass /
//  Material via `glassChrome` (decorative, not a plain card fill), and ambient
//  card styles are tuned for in-flow cards (e.g. `.outlined` has a transparent
//  surface, which would leave the dialog illegible over the dimmed scrim).
//  Scrim, transition and dismissal always stay in the component. All three
//  overloads present through the shared `DialogPresentation` chrome below:
//  fade-only scrim, scale+fade card transition, optional swipe-to-dismiss —
//  all motion gated by `microAnimations` + Reduce Motion.
//

import SwiftUI

// MARK: - Shared presentation chrome (scrim + transitions + swipe-to-dismiss)

/// Scrim + card presentation shared by every `.dialog(...)` overload: a dimmed
/// fade-only scrim, a scale+fade card transition (HeroUI Dialog feel), and an
/// optional swipe-down-to-dismiss drag (HeroUI `isSwipeable`). When
/// micro-animations are off or Reduce Motion is on, the card transition
/// collapses to a plain fade and the drag spring-back snaps instantly.
private struct DialogPresentation<Card: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Swipe-down-to-dismiss enabled (callers also gate this on loading state).
    let swipeToDismiss: Bool
    /// Scrim tap handler; the closure decides whether dismissal applies.
    let onScrimTap: () -> Void
    /// Called when a drag is released past the dismiss threshold.
    let onSwipeDismiss: () -> Void
    @ViewBuilder let card: () -> Card

    @State private var dragOffset: CGFloat = 0
    @State private var cardHeight: CGFloat = 0

    // Internal swipe tuning (mirrors FeedbackToastRow's drag feel).
    /// Resting scrim dim opacity.
    private static var scrimOpacity: Double { 0.4 }
    /// Drag distance before the swipe gesture engages.
    private static var minimumDragDistance: CGFloat { 8 }
    /// Fraction of the card height a drag must pass to dismiss on release.
    private static var dismissFraction: CGFloat { 1 / 3 }

    private var motionEnabled: Bool { micro && !reduceMotion }

    var body: some View {
        ZStack {
            theme.background(.bgTertiary).opacity(Self.scrimOpacity * scrimFade)
                .ignoresSafeArea()
                .onTapGesture(perform: onScrimTap)
                .transition(.opacity)   // Scrim always fades only.

            card()
                .background(GeometryReader { geo in
                    Color.clear
                        .onAppear { cardHeight = geo.size.height }
                        .onChange(of: geo.size.height) { cardHeight = $1 }
                })
                // Drag tracking is direct manipulation, so it always follows the
                // finger; only the animated parts (transition, spring-back) are
                // motion-gated.
                .offset(y: dragOffset)
                .gesture(swipe, including: swipeToDismiss ? .all : .subviews)
                .transition(cardTransition)
                // Assistive-tech equivalent of the swipe/scrim dismissal —
                // VoiceOver's two-finger scrub closes what a swipe would.
                // Both handlers carry the caller's own gating (loading state,
                // maskClosable), so escape can never dismiss more than touch.
                .accessibilityAction(.escape) {
                    if swipeToDismiss { onSwipeDismiss() } else { onScrimTap() }
                }
        }
        .zIndex(1)
    }

    /// Card presentation transition: scale+fade normally, plain fade when
    /// micro-animations are off or Reduce Motion is on.
    private var cardTransition: AnyTransition {
        motionEnabled ? .opacity.combined(with: .scale(scale: 0.96)) : .opacity
    }

    /// Fade the scrim proportionally as the card is dragged toward dismissal.
    private var scrimFade: Double {
        guard dragOffset > 0, cardHeight > 0 else { return 1 }
        return max(0, 1 - Double(dragOffset / cardHeight))
    }

    /// Downward drag offsets the card with the finger; releasing past
    /// `dismissFraction` of the card height dismisses, anything less springs
    /// back (instantly when motion is gated off).
    private var swipe: some Gesture {
        DragGesture(minimumDistance: Self.minimumDragDistance)
            .onChanged { value in
                dragOffset = max(0, value.translation.height)
            }
            .onEnded { _ in
                if cardHeight > 0, dragOffset > cardHeight * Self.dismissFraction {
                    onSwipeDismiss()
                } else {
                    withAnimation(motionEnabled ? Motion.fast.spring : nil) { dragOffset = 0 }
                }
            }
    }
}

struct DialogCard: View {
    @Environment(\.theme) private var theme

    let title: String
    let message: String?
    let primaryTitle: String
    let onPrimary: () -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    /// When set, the primary action uses a `ThemeButton` in this color
    /// (e.g. `.error` for destructive confirms). `nil` keeps the default primary.
    var primaryColor: SemanticColor? = nil
    /// When set, an icon header is shown (info / success / warning / error variant).
    var kind: FeedbackKind? = nil
    /// When set, a close (X) button is shown in the top-trailing corner.
    var onClose: (() -> Void)? = nil
    /// Maximum card width (default 320).
    var width: CGFloat? = nil
    /// While true the primary button spins and the secondary is disabled.
    var isPrimaryLoading: Bool = false

    var body: some View {
        VStack(spacing: Theme.SpacingKey.md.value) {
            if let kind {
                Icon(systemName: kind.systemImage).size(.xl).color(kind.semanticColor.accent)
            }
            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title)
                    .textStyle(.headingSm)
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let primaryColor {
                    ThemeButton(primaryTitle, action: onPrimary)
                        .color(primaryColor).fullWidth().loading(isPrimaryLoading)
                } else {
                    PrimaryButton(primaryTitle, action: onPrimary).loading(isPrimaryLoading)
                }
                if let secondaryTitle, let onSecondary {
                    OutlineButton(secondaryTitle, action: onSecondary).disabled(isPrimaryLoading)
                }
            }
        }
        .padding(Theme.SpacingKey.lg.value)
        .frame(maxWidth: width ?? 320)
        // Floating modal chrome → Liquid Glass on OS 26+, Material below, opaque under Reduce Transparency.
        .glassChrome(in: RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if let onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark").size(.sm).color(theme.text(.textTertiary))
                        .padding(Theme.SpacingKey.md.value)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Close"))
            }
        }
        .themeShadow(.elevated)
    }
}

private struct DialogModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let primaryTitle: String
    let onPrimary: () async -> Void
    let secondaryTitle: String?
    let onSecondary: (() -> Void)?
    let kind: FeedbackKind?
    let closable: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool
    let width: CGFloat?

    @State private var primaryLoading = false
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss && !primaryLoading,
                    onScrimTap: { if maskClosable, !primaryLoading { isPresented = false } },
                    onSwipeDismiss: { isPresented = false }
                ) {
                    DialogCard(
                        title: title, message: message,
                        primaryTitle: primaryTitle,
                        onPrimary: {
                            // Keep the dialog open with a spinner until the (possibly
                            // async) work resolves, then dismiss. (Ant Modal confirmLoading.)
                            Task {
                                primaryLoading = true
                                await onPrimary()
                                primaryLoading = false
                                isPresented = false
                            }
                        },
                        secondaryTitle: secondaryTitle,
                        onSecondary: onSecondary.map { handler in { isPresented = false; handler() } },
                        primaryColor: kind?.semanticColor,
                        kind: kind,
                        onClose: (closable && !primaryLoading) ? { isPresented = false } : nil,
                        width: width,
                        isPrimaryLoading: primaryLoading
                    )
                    .padding(Theme.SpacingKey.lg.value)
                }
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// `swipeToDismiss` adds a swipe-down-to-dismiss drag on the card
    /// (HeroUI Dialog `isSwipeable`); off by default.
    func dialog(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        primaryTitle: String,
        onPrimary: @escaping () async -> Void = {},
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil,
        kind: FeedbackKind? = nil,
        closable: Bool = false,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        width: CGFloat? = nil
    ) -> some View {
        modifier(DialogModifier(
            isPresented: isPresented, title: title, message: message,
            primaryTitle: primaryTitle, onPrimary: onPrimary,
            secondaryTitle: secondaryTitle, onSecondary: onSecondary,
            kind: kind, closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, width: width
        ))
    }
}

// MARK: - Custom content + footer slot (Ant Modal footer / scroll / afterClose)

private struct CustomDialogModifier<DialogContent: View, Footer: View>: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String?
    let closable: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool
    let width: CGFloat?
    let maxContentHeight: CGFloat
    let afterClose: (() -> Void)?
    let dialogContent: () -> DialogContent
    let footer: () -> Footer

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private func close() {
        isPresented = false
        afterClose?()
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss,
                    onScrimTap: { if maskClosable { close() } },
                    onSwipeDismiss: close
                ) {
                    VStack(spacing: 0) {
                        if title != nil || closable {
                            HStack {
                                if let title {
                                    Text(title).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary))
                                }
                                Spacer(minLength: Theme.SpacingKey.sm.value)
                                if closable {
                                    Button(action: close) {
                                        Icon(systemName: "xmark").size(.sm).color(theme.text(.textTertiary))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(String(themeKit: "Close"))
                                }
                            }
                            .padding(Theme.SpacingKey.lg.value)
                        }

                        ScrollView {
                            dialogContent()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, Theme.SpacingKey.lg.value)
                                .padding(.bottom, Theme.SpacingKey.md.value)
                        }
                        .frame(maxHeight: maxContentHeight)

                        DividerView().size(.small)

                        footer()
                            .padding(Theme.SpacingKey.lg.value)
                    }
                    .frame(maxWidth: width ?? 360)
                    .background(theme.background(.bgWhite),
                                in: RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
                    .themeShadow(.elevated)
                    .padding(Theme.SpacingKey.lg.value)
                }
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// A modal with custom scrollable content and a pinned footer slot
    /// (Ant Modal `footer` + long-content scroll + `afterClose`).
    /// `swipeToDismiss` adds a swipe-down-to-dismiss drag on the card
    /// (HeroUI Dialog `isSwipeable`); off by default.
    func dialog<DialogContent: View, Footer: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        closable: Bool = true,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        width: CGFloat? = nil,
        maxContentHeight: CGFloat = 420,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder content dialogContent: @escaping () -> DialogContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        modifier(CustomDialogModifier(
            isPresented: isPresented, title: title, closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, width: width,
            maxContentHeight: maxContentHeight, afterClose: afterClose,
            dialogContent: dialogContent, footer: footer
        ))
    }
}

// MARK: - Fully custom card interior (content-only slot)

private struct FreeformDialogModifier<DialogContent: View>: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let closable: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool
    let width: CGFloat?
    let afterClose: (() -> Void)?
    let dialogContent: () -> DialogContent

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private func close() {
        isPresented = false
        afterClose?()
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss,
                    onScrimTap: { if maskClosable { close() } },
                    onSwipeDismiss: close
                ) {
                    dialogContent()
                        .padding(Theme.SpacingKey.lg.value)
                        .frame(maxWidth: width ?? 320)
                        // Same floating modal chrome as `DialogCard`.
                        .glassChrome(in: RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
                        .overlay(alignment: .topTrailing) {
                            if closable {
                                Button(action: close) {
                                    Icon(systemName: "xmark").size(.sm).color(theme.text(.textTertiary))
                                        .padding(Theme.SpacingKey.md.value)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel(String(themeKit: "Close"))
                            }
                        }
                        .themeShadow(.elevated)
                        .padding(Theme.SpacingKey.lg.value)
                }
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// A modal whose card interior is entirely caller-drawn. Reuses the standard
    /// dialog presentation — dimmed scrim, glass card chrome, scale+fade
    /// transition, scrim-tap / close-button / optional swipe dismissal — while
    /// the content is a free slot. The fixed `title / message / actions` and
    /// `content:footer:` overloads remain unchanged next to this one.
    /// `swipeToDismiss` adds a swipe-down-to-dismiss drag on the card
    /// (HeroUI Dialog `isSwipeable`); off by default.
    func dialog<DialogContent: View>(
        isPresented: Binding<Bool>,
        closable: Bool = false,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        width: CGFloat? = nil,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> DialogContent
    ) -> some View {
        modifier(FreeformDialogModifier(
            isPresented: isPresented, closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, width: width,
            afterClose: afterClose, dialogContent: content
        ))
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            Color.gray.opacity(0.1).ignoresSafeArea()
                .dialog(isPresented: $show, title: "Delete trip?",
                        message: "This action cannot be undone.",
                        primaryTitle: "Delete", secondaryTitle: "Cancel", onSecondary: {})
        }
    }
    return Demo()
}

#Preview("Swipe to dismiss") {
    struct Demo: View {
        @State var show = true
        var body: some View {
            VStack {
                PrimaryButton("Show dialog") { show = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.1))
            .dialog(isPresented: $show, title: "Swipe to dismiss",
                    message: "Drag the card down past a third of its height to dismiss; a shorter drag springs back.",
                    primaryTitle: "OK", swipeToDismiss: true)
        }
    }
    return Demo()
}

#Preview("Custom content slot") {
    struct Demo: View {
        @Environment(\.theme) private var theme
        @State var show = true
        var body: some View {
            Color.gray.opacity(0.1).ignoresSafeArea()
                .dialog(isPresented: $show, closable: true) {
                    VStack(spacing: Theme.SpacingKey.md.value) {
                        Icon(systemName: "sparkles").size(.xl).color(theme.foreground(.fgHero))
                        Text("Rate your stay").textStyle(.headingSm)
                            .foregroundStyle(theme.text(.textPrimary))
                        Text("Any layout works here — forms, ratings, media.")
                            .textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                            .multilineTextAlignment(.center)
                        PrimaryButton("Submit") { show = false }
                    }
                }
        }
    }
    return Demo()
}
