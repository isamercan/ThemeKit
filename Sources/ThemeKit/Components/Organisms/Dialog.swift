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
//  HeroUI Modal parity axes shared by every overload: `backdrop:` (`.dim` /
//  `.blur` / `.transparent`), `size:` (a named max-width ramp `.sm…​.xl` + `.full`),
//  and `placement:` (`.center` / `.top` / `.bottom`). The `content:footer:`
//  overload also frosts its scroll edges (HeroUI `ScrollShadow`) and takes an
//  optional custom `header:` slot in place of the plain title string.
//

import SwiftUI

// MARK: - Modal parity axes (backdrop / size / placement)

/// A named max-width for a dialog card (HeroUI Modal `size`). An explicit
/// `width:` always overrides this; `.full` stretches the card edge-to-edge
/// within the presentation insets.
public enum DialogSize: String, CaseIterable, Sendable {
    case sm, md, lg, xl, full

    /// Max card width in points; `.full` fills the available width (`.infinity`).
    var width: CGFloat {
        switch self {
        case .sm: return 320
        case .md: return 400
        case .lg: return 480
        case .xl: return 560
        case .full: return .infinity
        }
    }
}

/// Where a dialog card sits over the scrim (HeroUI Modal `placement`). `.top` /
/// `.bottom` inset the card off the anchored screen edge and dismiss toward it.
public enum DialogPlacement: String, CaseIterable, Sendable {
    case center, top, bottom

    var alignment: Alignment {
        switch self {
        case .center: return .center
        case .top: return .top
        case .bottom: return .bottom
        }
    }

    /// The edge a swipe dismisses toward — up for a top card, down otherwise.
    var dragEdge: Edge { self == .top ? .top : .bottom }

    /// Which screen edge to inset the card off (none when centered).
    var edgeInset: Edge.Set {
        switch self {
        case .center: return []
        case .top: return .top
        case .bottom: return .bottom
        }
    }
}

/// Resolves a card's max width: an explicit `width` wins, then a named `size`,
/// then the overload's own legacy default. `.full` yields `.infinity`.
private func dialogMaxWidth(_ width: CGFloat?, _ size: DialogSize?, default legacyDefault: CGFloat) -> CGFloat {
    if let width { return width }
    if let size { return size.width }
    return legacyDefault
}

// MARK: - Shared presentation chrome (scrim + transitions + swipe-to-dismiss)

/// Scrim + card presentation shared by every `.dialog(...)` overload: a dimmed
/// fade-only scrim, a scale+fade card transition (HeroUI Dialog feel), and an
/// optional swipe-down-to-dismiss drag (HeroUI `isSwipeable`) via the shared
/// `dismissDrag` (ADR-7 — this presentation is its reference feel). When
/// micro-animations are off or Reduce Motion is on, the card transition
/// collapses to a plain fade and the drag spring-back snaps instantly.
struct DialogPresentation<Card: View>: View {
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Swipe-down-to-dismiss enabled (callers also gate this on loading state).
    let swipeToDismiss: Bool
    /// Scrim look (`.dim` / `.blur` / `.transparent`).
    let backdrop: BackdropStyle
    /// Where the card sits over the scrim (`.center` / `.top` / `.bottom`).
    let placement: DialogPlacement
    /// Scrim tap handler; the closure decides whether dismissal applies.
    let onScrimTap: () -> Void
    /// Called when a drag is released past the dismiss threshold.
    let onSwipeDismiss: () -> Void
    @ViewBuilder let card: () -> Card

    /// 0…1 dismissal progress reported by `dismissDrag` — fades the scrim as
    /// the card is dragged toward dismissal.
    @State private var dragProgress: Double = 0

    private var motionEnabled: Bool { micro && !reduceMotion }

    var body: some View {
        ZStack(alignment: placement.alignment) {
            Backdrop(fade: 1 - dragProgress)
                .material(backdrop)
                .onTapGesture(perform: onScrimTap)
                .transition(.opacity)   // Scrim always fades only.

            card()
                // The drag offsets the card toward the placement edge with the
                // finger; releasing past a third of the card height dismisses,
                // anything less springs back (instantly when motion is gated off).
                .dismissDrag(edge: placement.dragEdge,
                             isEnabled: swipeToDismiss,
                             progress: $dragProgress,
                             onDismiss: onSwipeDismiss)
                .transition(cardTransition)
                // Top / bottom placements inset the card off the anchored edge.
                .padding(placement.edgeInset, Theme.SpacingKey.xl.value)
                // Modal presenter: VoiceOver ignores the dimmed scrim and the
                // background content behind the card while the dialog is up.
                .accessibilityAddTraits(.isModal)
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
                Icon(systemName: kind.systemImage).size(.xl).color(theme.resolve(kind.semanticColor).accent)
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
    let backdrop: BackdropStyle
    let size: DialogSize?
    let placement: DialogPlacement
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
                    backdrop: backdrop,
                    placement: placement,
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
                        width: dialogMaxWidth(width, size, default: 320),
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
    ///
    /// - `backdrop`: scrim style — `.dim` (default), `.blur`, or `.transparent`.
    /// - `size`: a named max-width ramp (`.sm…​.xl` + `.full`); `width:` overrides it.
    /// - `placement`: `.center` (default), `.top`, or `.bottom`.
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
        backdrop: BackdropStyle = .dim,
        size: DialogSize? = nil,
        placement: DialogPlacement = .center,
        width: CGFloat? = nil
    ) -> some View {
        modifier(DialogModifier(
            isPresented: isPresented, title: title, message: message,
            primaryTitle: primaryTitle, onPrimary: onPrimary,
            secondaryTitle: secondaryTitle, onSecondary: onSecondary,
            kind: kind, closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, backdrop: backdrop, size: size,
            placement: placement, width: width
        ))
    }
}

// MARK: - Custom content + footer slot (Ant Modal footer / scroll / afterClose)

private struct CustomDialogModifier<DialogContent: View, Footer: View>: ViewModifier {
    @Environment(\.theme) private var theme

    @Binding var isPresented: Bool
    let title: String?
    /// Custom header slot; `nil` → the built-in `title` string (or no header).
    let customHeader: SlotContent?
    let closable: Bool
    let maskClosable: Bool
    let swipeToDismiss: Bool
    let backdrop: BackdropStyle
    let size: DialogSize?
    let placement: DialogPlacement
    let width: CGFloat?
    let maxContentHeight: CGFloat
    let afterClose: (() -> Void)?
    let dialogContent: () -> DialogContent
    let footer: () -> Footer

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private var hasHeader: Bool { customHeader != nil || title != nil || closable }

    private func close() {
        isPresented = false
        afterClose?()
    }

    func body(content: Content) -> some View {
        content.overlay {
            if isPresented {
                DialogPresentation(
                    swipeToDismiss: swipeToDismiss,
                    backdrop: backdrop,
                    placement: placement,
                    onScrimTap: { if maskClosable { close() } },
                    onSwipeDismiss: close
                ) {
                    VStack(spacing: 0) {
                        if hasHeader {
                            HStack {
                                if let customHeader {
                                    // The slot styles itself, but a bare `Text`
                                    // header inherits the title's look by default.
                                    customHeader
                                        .textStyle(.headingSm)
                                        .foregroundStyle(theme.text(.textPrimary))
                                } else if let title {
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

                        // HeroUI ScrollShadow: frost the clipped scroll edges so
                        // long content visibly fades into the header / footer.
                        // Only on OSes where ScrollShadow can OBSERVE the scroll
                        // (iOS 18 / macOS 15+) — below that its `.auto` degrades to
                        // always-on scrims, which would paint permanent top+bottom
                        // gradients over a short, non-scrollable body. There, fall
                        // back to the plain ScrollView (the pre-scroll-shadow look).
                        if #available(iOS 18.0, macOS 15.0, *) {
                            ScrollShadow {
                                ScrollView {
                                    dialogContent()
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, Theme.SpacingKey.lg.value)
                                        .padding(.bottom, Theme.SpacingKey.md.value)
                                }
                                .frame(maxHeight: maxContentHeight)
                            }
                            .fadeColor(.bgWhite)
                        } else {
                            ScrollView {
                                dialogContent()
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, Theme.SpacingKey.lg.value)
                                    .padding(.bottom, Theme.SpacingKey.md.value)
                            }
                            .frame(maxHeight: maxContentHeight)
                        }

                        DividerView().size(.small)

                        footer()
                            .padding(Theme.SpacingKey.lg.value)
                    }
                    .frame(maxWidth: dialogMaxWidth(width, size, default: 360))
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
    /// (Ant Modal `footer` + long-content scroll + `afterClose`). The scroll
    /// edges frost (HeroUI `ScrollShadow`) so long content fades into the chrome.
    /// `swipeToDismiss` adds a swipe-down-to-dismiss drag on the card
    /// (HeroUI Dialog `isSwipeable`); off by default.
    ///
    /// - `backdrop`: scrim style — `.dim` (default), `.blur`, or `.transparent`.
    /// - `size`: a named max-width ramp (`.sm…​.xl` + `.full`); `width:` overrides it.
    /// - `placement`: `.center` (default), `.top`, or `.bottom`.
    func dialog<DialogContent: View, Footer: View>(
        isPresented: Binding<Bool>,
        title: String? = nil,
        closable: Bool = true,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        backdrop: BackdropStyle = .dim,
        size: DialogSize? = nil,
        placement: DialogPlacement = .center,
        width: CGFloat? = nil,
        maxContentHeight: CGFloat = 420,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder content dialogContent: @escaping () -> DialogContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        modifier(CustomDialogModifier(
            isPresented: isPresented, title: title, customHeader: nil,
            closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, backdrop: backdrop, size: size,
            placement: placement, width: width,
            maxContentHeight: maxContentHeight, afterClose: afterClose,
            dialogContent: dialogContent, footer: footer
        ))
    }

    /// The same scrollable-content + pinned-footer modal, but with a fully custom
    /// `header:` slot in place of the plain title string (HeroUI's `ModalHeader`
    /// slot) — put an icon, a subtitle, a stepper, anything. The close button (if
    /// `closable`) still floats top-trailing beside the slot.
    ///
    /// - `backdrop`: scrim style — `.dim` (default), `.blur`, or `.transparent`.
    /// - `size`: a named max-width ramp (`.sm…​.xl` + `.full`); `width:` overrides it.
    /// - `placement`: `.center` (default), `.top`, or `.bottom`.
    func dialog<Header: View, DialogContent: View, Footer: View>(
        isPresented: Binding<Bool>,
        closable: Bool = true,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        backdrop: BackdropStyle = .dim,
        size: DialogSize? = nil,
        placement: DialogPlacement = .center,
        width: CGFloat? = nil,
        maxContentHeight: CGFloat = 420,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder header: @escaping () -> Header,
        @ViewBuilder content dialogContent: @escaping () -> DialogContent,
        @ViewBuilder footer: @escaping () -> Footer
    ) -> some View {
        modifier(CustomDialogModifier(
            isPresented: isPresented, title: nil, customHeader: SlotContent(header),
            closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, backdrop: backdrop, size: size,
            placement: placement, width: width,
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
    let backdrop: BackdropStyle
    let size: DialogSize?
    let placement: DialogPlacement
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
                    backdrop: backdrop,
                    placement: placement,
                    onScrimTap: { if maskClosable { close() } },
                    onSwipeDismiss: close
                ) {
                    dialogContent()
                        .padding(Theme.SpacingKey.lg.value)
                        .frame(maxWidth: dialogMaxWidth(width, size, default: 320))
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
    ///
    /// - `backdrop`: scrim style — `.dim` (default), `.blur`, or `.transparent`.
    /// - `size`: a named max-width ramp (`.sm…​.xl` + `.full`); `width:` overrides it.
    /// - `placement`: `.center` (default), `.top`, or `.bottom`.
    func dialog<DialogContent: View>(
        isPresented: Binding<Bool>,
        closable: Bool = false,
        maskClosable: Bool = true,
        swipeToDismiss: Bool = false,
        backdrop: BackdropStyle = .dim,
        size: DialogSize? = nil,
        placement: DialogPlacement = .center,
        width: CGFloat? = nil,
        afterClose: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> DialogContent
    ) -> some View {
        modifier(FreeformDialogModifier(
            isPresented: isPresented, closable: closable, maskClosable: maskClosable,
            swipeToDismiss: swipeToDismiss, backdrop: backdrop, size: size,
            placement: placement, width: width,
            afterClose: afterClose, dialogContent: content
        ))
    }
}

#Preview {
    // Presentation organism — each cell pins `isPresented: .constant(true)` so a
    // single frame shows the presented card (scrim + chrome) per color scheme.
    PreviewMatrix("Dialog") {
        PreviewCase("Confirm · two actions") {
            Color.clear.frame(height: 300)
                .dialog(isPresented: .constant(true), title: "Delete trip?",
                        message: "This action cannot be undone.",
                        primaryTitle: "Delete", secondaryTitle: "Cancel", onSecondary: {})
        }
        PreviewCase("Error kind · closable") {
            Color.clear.frame(height: 320)
                .dialog(isPresented: .constant(true), title: "Payment failed",
                        message: "Your card was declined. Try another method.",
                        primaryTitle: "Retry", secondaryTitle: "Cancel", onSecondary: {},
                        kind: .error, closable: true)
        }
        PreviewCase("Content + pinned footer slot") {
            Color.clear.frame(height: 340)
                .dialog(isPresented: .constant(true), title: "Trip details") {
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                        ForEach(1...4, id: \.self) { i in
                            Text("Detail line \(i)").textStyle(.bodyBase400)
                        }
                    }
                } footer: {
                    PrimaryButton("Done") {}
                }
        }
        PreviewCase("Blur backdrop · lg size") {
            Color.clear.frame(height: 300)
                .dialog(isPresented: .constant(true), title: "Enable notifications?",
                        message: "We'll only ping you about gate changes and delays.",
                        primaryTitle: "Allow", secondaryTitle: "Not now", onSecondary: {},
                        backdrop: .blur, size: .lg)
        }
        PreviewCase("Bottom placement") {
            Color.clear.frame(height: 340)
                .dialog(isPresented: .constant(true), title: "Sign out?",
                        message: "You'll need to log in again next time.",
                        primaryTitle: "Sign out", secondaryTitle: "Cancel", onSecondary: {},
                        placement: .bottom)
        }
        PreviewCase("Custom header slot") {
            Color.clear.frame(height: 340)
                .dialog(isPresented: .constant(true)) {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        Icon(systemName: "airplane.departure").size(.md)
                        VStack(alignment: .leading) {
                            Text("Flight IST → LHR").textStyle(.headingSm)
                            Text("Today · 14:20").textStyle(.bodySm400)
                        }
                    }
                } content: {
                    Text("Custom header slots hold icons, subtitles, steppers — anything.")
                        .textStyle(.bodyBase400)
                } footer: {
                    PrimaryButton("Got it") {}
                }
        }
    }
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
