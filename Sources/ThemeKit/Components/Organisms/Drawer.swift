//
//  Drawer.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. An edge-anchored panel that slides in over a dimmed scrim from any
//  of the four screen edges (HeroUI "Drawer"). Two layers compose it:
//
//    • `Drawer { … }` — the panel *content chrome*: a `heading` / body / `footer`
//      slot stack with an optional close button and a grab handle. Present it
//      through a drawer presenter to get the full experience:
//
//          content.drawer(isPresented: $open, edge: .bottom) {
//              Drawer { ProfileForm() }
//                  .heading { Text("Edit Profile") }
//                  .footer  { HStack { CancelButton(); DoneButton() } }
//          }
//
//    • `.drawer(isPresented:edge:)` / `.drawerHost()` + `DrawerPresenter` — the
//      *presentation*: dimmed scrim, edge-aware glass chrome, slide-in transition
//      and drag-toward-the-edge swipe-to-dismiss (the shared `dismissDrag`,
//      ADR-7); the scrim fades as the panel is dragged away.
//
//  `edge` is a `SwiftUI.Edge`, so a drawer enters from `.bottom` (the mobile-first
//  sheet, with a grab handle), `.top`, `.leading` or `.trailing`. Passing any view
//  (not just a `Drawer`) still works — it gets the scrim + glass chrome bare.
//

import SwiftUI

// MARK: - Presenter → panel context (edge + dismiss)

/// Entry edge the presenter is sliding from — read by ``Drawer`` to place its grab
/// handle. Defaults to `.bottom` (the mobile-first sheet) for a standalone panel.
private struct DrawerEdgeKey: EnvironmentKey { static let defaultValue: Edge = .bottom }
/// Dismiss hook the presenter injects so ``Drawer``'s close button can close the
/// presentation without a local binding. A no-op for a standalone panel.
/// `@MainActor @Sendable` makes the default (and the environment value)
/// concurrency-safe while allowing it to touch main-actor UI state.
private struct DrawerDismissKey: EnvironmentKey { static let defaultValue: @MainActor @Sendable () -> Void = {} }

extension EnvironmentValues {
    var drawerEdge: Edge {
        get { self[DrawerEdgeKey.self] }
        set { self[DrawerEdgeKey.self] = newValue }
    }
    var drawerDismiss: @MainActor @Sendable () -> Void {
        get { self[DrawerDismissKey.self] }
        set { self[DrawerDismissKey.self] = newValue }
    }
}

// MARK: - Edge geometry (shared by panel + presenter)

private extension Edge {
    /// The exposed (visible) edge — opposite the entry edge — that carries the
    /// rounded corners and the grab handle.
    var drawerOpposite: Edge {
        switch self {
        case .top: return .bottom
        case .bottom: return .top
        case .leading: return .trailing
        case .trailing: return .leading
        }
    }

    var asSet: Edge.Set {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }

    /// Leading/trailing drawers are width-constrained and full-height; top/bottom
    /// sheets span the width and hug their content.
    var isHorizontalDrawer: Bool { self == .leading || self == .trailing }

    var zStackAlignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .leading: return .leading
        case .trailing: return .trailing
        }
    }
}

/// The panel's rounded shape: only the two corners on the *exposed* edge (opposite
/// the entry edge) are rounded, so the drawer reads as flush against the screen
/// edge it slid from. Corner terms are leading/trailing, so it mirrors under RTL.
private func drawerShape(entry edge: Edge, radius r: CGFloat) -> ThemeUnevenRoundedRect {
    switch edge {
    case .bottom:
        return ThemeUnevenRoundedRect(topLeadingRadius: r, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: 0, topTrailingRadius: r, style: .continuous)
    case .top:
        return ThemeUnevenRoundedRect(topLeadingRadius: 0, bottomLeadingRadius: r,
                                      bottomTrailingRadius: r, topTrailingRadius: 0, style: .continuous)
    case .leading:
        return ThemeUnevenRoundedRect(topLeadingRadius: 0, bottomLeadingRadius: 0,
                                      bottomTrailingRadius: r, topTrailingRadius: r, style: .continuous)
    case .trailing:
        return ThemeUnevenRoundedRect(topLeadingRadius: r, bottomLeadingRadius: r,
                                      bottomTrailingRadius: 0, topTrailingRadius: 0, style: .continuous)
    }
}

// MARK: - Panel (content chrome: heading / body / footer + handle + close)

/// The drawer's content surface — a `heading` / body / `footer` slot stack with an
/// optional close button and (on `.bottom` / `.top`) a grab handle. Present it with
/// ``SwiftUI/View/drawer(isPresented:edge:width:dismissOnScrimTap:content:)``,
/// which supplies the dimmed scrim, edge-aware glass chrome and slide-in:
///
///     Drawer { ProfileForm() }
///         .heading { Text("Edit Profile") }
///         .footer  { HStack { CancelButton(); DoneButton() } }
///         .showsCloseButton(true)          // grab handle auto-shows on bottom/top
///
/// Content and modifiers only — the panel reads its entry edge and dismiss hook
/// from the presenter (or `.edge(_:)` / `.onClose(_:)` for a standalone panel).
public struct Drawer<Content: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.drawerEdge) private var ambientEdge
    @Environment(\.drawerDismiss) private var ambientDismiss

    private let content: () -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var headingContent: SlotContent?
    private var footerContent: SlotContent?
    private var showsCloseButton = true
    private var handleOverride: Bool?
    private var edgeOverride: Edge?
    private var onClose: (@MainActor @Sendable () -> Void)?

    public init(@ViewBuilder content: @escaping () -> Content) {   // R1 — body content only
        self.content = content
    }

    /// Resolved entry edge: an explicit `.edge(_:)` override wins, else the ambient
    /// edge the presenter injected (default `.bottom`).
    private var edge: Edge { edgeOverride ?? ambientEdge }

    /// The grab handle shows on bottom/top sheets by default; `.showsHandle(_:)` overrides.
    private var showsHandle: Bool { handleOverride ?? !edge.isHorizontalDrawer }

    public var body: some View {
        contentStack
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .overlay(alignment: edge == .top ? .bottom : .top) { handle }
            .overlay(alignment: .topTrailing) { closeButton }
    }

    private var contentStack: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let headingContent {
                headingContent
                    .textStyle(.heading2xs)
                    .foregroundStyle(theme.text(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
            }
            // Body fills the free vertical space on a full-height side drawer so the
            // footer pins to the bottom; a bottom/top sheet hugs its content instead.
            content()
                .frame(maxWidth: .infinity,
                       maxHeight: edge.isHorizontalDrawer ? .infinity : nil,
                       alignment: .topLeading)
                .padding(.top, headingContent != nil ? Theme.SpacingKey.sm.value : 0)
            if let footerContent {
                footerContent
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, Theme.SpacingKey.md.value)
            }
        }
        .padding(Theme.SpacingKey.base.value)
    }

    @ViewBuilder private var handle: some View {
        if showsHandle {
            Capsule(style: .continuous)
                .fill(theme.text(.textTertiary))
                .frame(width: 36, height: 4)
                .padding(edge == .top ? .bottom : .top, Theme.SpacingKey.sm.value)
                .accessibilityHidden(true)
        }
    }

    @ViewBuilder private var closeButton: some View {
        if showsCloseButton {
            CloseButton { (onClose ?? ambientDismiss)() }
                .controlSize(.mini)
                .padding(.top, Theme.SpacingKey.xs.value)
                .padding(.trailing, Theme.SpacingKey.xs.value)
        }
    }
}

// MARK: - Panel modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Drawer {
    /// Heading slot (HeroUI `DrawerHeader`) — a title or custom top layout. Plain
    /// text inherits the heading type style and primary text color.
    func heading<H: View>(@ViewBuilder _ heading: () -> H) -> Self {
        copy { $0.headingContent = SlotContent(heading) }
    }

    /// Footer slot (HeroUI `DrawerFooter`) — trailing-aligned actions such as
    /// Cancel / Save / Apply, divided from the body by a gap.
    func footer<F: View>(@ViewBuilder _ footer: () -> F) -> Self {
        copy { $0.footerContent = SlotContent(footer) }
    }

    /// Toggles the top-trailing close button (default on). Hide it only when the
    /// footer already offers a strong, obvious dismiss action.
    func showsCloseButton(_ shows: Bool = true) -> Self { copy { $0.showsCloseButton = shows } }

    /// Overrides the grab-handle visibility. Defaults to shown on `.bottom` / `.top`
    /// sheets and hidden on `.leading` / `.trailing` side drawers.
    func showsHandle(_ shows: Bool) -> Self { copy { $0.handleOverride = shows } }

    /// Explicit entry edge for a standalone panel (previews, custom hosts). When the
    /// panel is presented via `.drawer(edge:)` the presenter supplies this for you.
    func edge(_ edge: Edge) -> Self { copy { $0.edgeOverride = edge } }

    /// Close action for the close button when the panel isn't driven by a presenter
    /// binding. Falls back to the presenter's own dismiss when unset.
    func onClose(_ action: @escaping @MainActor @Sendable () -> Void) -> Self { copy { $0.onClose = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Presentation (scrim + edge-aware glass chrome + drag-to-dismiss)

/// Shared scrim + sliding panel with drag-to-dismiss (the shared `dismissDrag`,
/// ADR-7); the scrim fades as the panel is dragged away. Used by both the
/// declarative modifier and the imperative host.
private struct DrawerContainer<DrawerContent: View>: View {
    let edge: Edge
    let width: CGFloat
    let dismissOnScrimTap: Bool
    let onDismiss: @MainActor @Sendable () -> Void
    @ViewBuilder let content: () -> DrawerContent

    /// 0…1 dismissal progress reported by `dismissDrag`: 0 at rest, 1 when the panel
    /// is dragged its full extent toward its entry edge.
    @State private var dragProgress: Double = 0

    var body: some View {
        ZStack(alignment: edge.zStackAlignment) {
            Backdrop(fade: 1 - dragProgress)
                .onTapGesture { if dismissOnScrimTap { onDismiss() } }
                .accessibilityLabel(String(themeKit: "Close"))
                .accessibilityAddTraits(dismissOnScrimTap ? .isButton : [])
                .accessibilityHidden(!dismissOnScrimTap)

            panel
                // Presenter context the `Drawer` panel reads for its handle + close.
                .environment(\.drawerEdge, edge)
                .environment(\.drawerDismiss, onDismiss)
                // Only dragging toward the panel's own edge (i.e. to close) engages;
                // releasing past a third of the extent dismisses.
                .dismissDrag(edge: edge,
                             threshold: .fraction(0.33),
                             minimumDragDistance: 10,   // DragGesture's stock distance, the historical tuning
                             progress: $dragProgress,
                             onDismiss: onDismiss)
                .transition(.move(edge: edge))
                // Modal: hide the dimmed background from VoiceOver; scrub-to-dismiss.
                .accessibilityAddTraits(.isModal)
                .accessibilityAction(.escape) { onDismiss() }
        }
        .zIndex(1)
    }

    /// The presented content in edge-aware glass chrome: rounded on the exposed
    /// edge, extended under the safe area on the flush edges, elevated. Side drawers
    /// take `width` and fill the height; top/bottom sheets span the width and hug.
    private var panel: some View {
        content()
            .frame(maxWidth: edge.isHorizontalDrawer ? width : .infinity,
                   maxHeight: edge.isHorizontalDrawer ? .infinity : nil,
                   alignment: .topLeading)
            .background {
                Color.clear
                    // Chrome surface → Liquid Glass on OS 26+, Material below, opaque under Reduce Transparency.
                    .glassChrome(in: drawerShape(entry: edge, radius: Theme.RadiusRole.box.value))
                    // Reach the physical screen edges the panel is flush against,
                    // while the content above stays clear of notch / home indicator.
                    .ignoresSafeArea(edges: Edge.Set.all.subtracting(edge.drawerOpposite.asSet))
            }
            .themeShadow(.elevated)
    }
}

private struct DrawerModifier<DrawerContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: Edge
    let width: CGFloat
    let dismissOnScrimTap: Bool
    @ViewBuilder let content: () -> DrawerContent

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    func body(content base: Content) -> some View {
        base.overlay {
            if isPresented {
                DrawerContainer(edge: edge, width: width, dismissOnScrimTap: dismissOnScrimTap,
                                onDismiss: { isPresented = false }, content: content)
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    /// Presents `content` as an edge-anchored drawer over a dimmed scrim. Drag the
    /// panel toward its entry edge (or tap the scrim) to dismiss. Wrap the content in
    /// a ``Drawer`` for the slotted heading / body / footer chrome, or pass any view
    /// for a bare panel.
    ///
    /// - Parameters:
    ///   - edge: the screen edge the drawer enters from — `.bottom` (mobile sheet),
    ///     `.top`, `.leading` or `.trailing`. Defaults to `.leading`.
    ///   - width: panel width for `.leading` / `.trailing` drawers; ignored for
    ///     `.bottom` / `.top`, which span the width and hug their content height.
    func drawer<DrawerContent: View>(
        isPresented: Binding<Bool>,
        edge: Edge = .leading,
        width: CGFloat = 300,
        dismissOnScrimTap: Bool = true,
        @ViewBuilder content: @escaping () -> DrawerContent
    ) -> some View {
        modifier(DrawerModifier(isPresented: isPresented, edge: edge, width: width,
                                dismissOnScrimTap: dismissOnScrimTap, content: content))
    }
}

// MARK: - Imperative presenter

/// Imperative drawer presenter. Install once with `.drawerHost()`, then from any
/// descendant view:
///
///     @EnvironmentObject var drawer: DrawerPresenter
///     drawer.present(edge: .bottom) { Drawer { MenuView() } }
///     drawer.dismiss()
///
/// > Important: iOS 15.6-floor migration (ADR-0007 §D4). `DrawerPresenter` is an
/// > `ObservableObject` (the iOS-17 `@Observable` pattern no longer applies):
/// > read it with `@EnvironmentObject` — `@Environment(DrawerPresenter.self)`
/// > will not compile — and if you own an instance yourself, hold it as
/// > `@StateObject` (NOT `@State`: with `@State` it still compiles but views
/// > silently stop updating).
@MainActor
public final class DrawerPresenter: ObservableObject {

    struct Request: Identifiable {
        let id = UUID()
        let edge: Edge
        let width: CGFloat
        let dismissOnScrimTap: Bool
        let content: AnyView
    }

    @Published var current: Request?

    public init() {}

    /// Open a drawer. Replaces any visible drawer.
    public func present<C: View>(
        edge: Edge = .leading,
        width: CGFloat = 300,
        dismissOnScrimTap: Bool = true,
        @ViewBuilder _ content: () -> C
    ) {
        current = Request(edge: edge, width: width, dismissOnScrimTap: dismissOnScrimTap, content: AnyView(content()))
    }

    public func dismiss() { current = nil }

    public var isPresented: Bool { current != nil }
}

private struct DrawerHostModifier: ViewModifier {
    @StateObject private var presenter = DrawerPresenter()
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .environmentObject(presenter)
            .overlay {
                if let request = presenter.current {
                    DrawerContainer(edge: request.edge, width: request.width,
                                    dismissOnScrimTap: request.dismissOnScrimTap,
                                    onDismiss: { presenter.dismiss() }) { request.content }
                }
            }
            .animation(motion, value: presenter.current?.id)
    }
}

public extension View {
    /// Installs the shared `DrawerPresenter`. Apply once near the app root, above any
    /// view that calls `drawer.present(…)`.
    func drawerHost() -> some View {
        modifier(DrawerHostModifier())
    }
}

#Preview("Declarative") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            // Presentation organism — each cell pins `isPresented: .constant(true)` so a
            // single frame shows the slid-in panel (scrim + glass chrome) per color scheme.

            func bodyText() -> some View {
                Text("Lorem ipsum dolor sit amet consectetur. Duis purus viverra nulla feugiat orci. Convallis blandit a habitasse aenean pellentesque.")
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
            func actions() -> some View {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    ThemeButton("Cancel") {}.variant(.ghost).size(.small)
                    ThemeButton("Done") {}.size(.small)
                }
            }

            return PreviewMatrix("Drawer") {
                PreviewCase("Bottom sheet · handle (pinned open)") {
                    Color.clear.frame(height: 300)
                        .drawer(isPresented: .constant(true), edge: .bottom) {
                            Drawer { bodyText() }
                                .heading { Text(verbatim: "Bottom drawer") }
                                .footer { actions() }
                        }
                }
                PreviewCase("Top sheet") {
                    Color.clear.frame(height: 300)
                        .drawer(isPresented: .constant(true), edge: .top) {
                            Drawer { bodyText() }
                                .heading { Text(verbatim: "Top drawer") }
                                .footer { actions() }
                        }
                }
                PreviewCase("Trailing · full height") {
                    Color.clear.frame(height: 380)
                        .drawer(isPresented: .constant(true), edge: .trailing, width: 300) {
                            Drawer { bodyText() }
                                .heading { Text(verbatim: "Right drawer") }
                                .footer { actions() }
                        }
                }
                PreviewCase("Leading · full height") {
                    Color.clear.frame(height: 380)
                        .drawer(isPresented: .constant(true), edge: .leading, width: 300) {
                            Drawer { bodyText() }
                                .heading { Text(verbatim: "Left drawer") }
                                .footer { actions() }
                        }
                }
            }
        }
    }
    return Demo()
}

#Preview("Imperative host") {
    struct Demo: View {
        @EnvironmentObject var drawer: DrawerPresenter
        var body: some View {
            PrimaryButton("Present (bottom)") {
                drawer.present(edge: .bottom) {
                    Drawer {
                        Text(verbatim: "Opened from the shared DrawerPresenter — no local binding.")
                            .textStyle(.bodyBase400)
                    }
                    .heading { Text(verbatim: "Menu") }
                    .footer { ThemeButton("Close") { drawer.dismiss() }.size(.small) }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    return Demo().drawerHost()
}
