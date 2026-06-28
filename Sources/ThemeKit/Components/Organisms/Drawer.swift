//
//  Drawer.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A side drawer that slides in over a dimmed scrim. Two entry points:
//    • `.drawer(isPresented:edge:)` — declarative, binding-driven.
//    • `.drawerHost()` + `@Environment(DrawerPresenter.self)` — imperative; open a
//      drawer from anywhere without a local binding.
//  Both support drag-toward-the-edge swipe-to-dismiss and scrim tap-to-dismiss.
//  (daisyUI "Drawer".)
//

import SwiftUI

/// Shared scrim + sliding panel with drag-to-dismiss; the scrim fades as the
/// panel is dragged away. Used by both the declarative modifier and the host.
private struct DrawerContainer<DrawerContent: View>: View {
    @Environment(\.theme) private var theme

    let edge: HorizontalEdge
    let width: CGFloat
    let dismissOnScrimTap: Bool
    let onDismiss: () -> Void
    @ViewBuilder let content: () -> DrawerContent

    @State private var dragX: CGFloat = 0
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    var body: some View {
        ZStack(alignment: edge == .leading ? .leading : .trailing) {
            theme.background(.bgTertiary).opacity(0.4 * scrimFactor)
                .ignoresSafeArea()
                .onTapGesture { if dismissOnScrimTap { onDismiss() } }

            content()
                .frame(maxWidth: width, maxHeight: .infinity, alignment: .topLeading)
                .frame(maxHeight: .infinity)
                // Side-panel chrome → Liquid Glass on OS 26+, Material below, opaque under Reduce Transparency.
                .glassChrome(in: Rectangle())
                .ignoresSafeArea()
                .offset(x: dragX)
                .gesture(dragGesture)
                .transition(.move(edge: edge == .leading ? .leading : .trailing))
        }
        .zIndex(1)
    }

    /// Scrim opacity multiplier: 1 at rest, 0 when dragged a full width away.
    private var scrimFactor: Double {
        1 - min(abs(dragX) / width, 1)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                let dx = value.translation.width
                // Only allow dragging toward the panel's own edge (i.e. to close).
                dragX = edge == .leading ? min(0, dx) : max(0, dx)
            }
            .onEnded { _ in
                if abs(dragX) > width * 0.33 {
                    onDismiss()
                } else {
                    withAnimation(motion) { dragX = 0 }
                }
            }
    }
}

private struct DrawerModifier<DrawerContent: View>: ViewModifier {
    @Binding var isPresented: Bool
    let edge: HorizontalEdge
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
    /// Presents `content` as a side drawer over a scrim. Drag the panel toward its
    /// edge (or tap the scrim) to dismiss.
    func drawer<DrawerContent: View>(
        isPresented: Binding<Bool>,
        edge: HorizontalEdge = .leading,
        width: CGFloat = 300,
        dismissOnScrimTap: Bool = true,
        @ViewBuilder content: @escaping () -> DrawerContent
    ) -> some View {
        modifier(DrawerModifier(isPresented: isPresented, edge: edge, width: width,
                                dismissOnScrimTap: dismissOnScrimTap, content: content))
    }
}

// MARK: - Imperative presenter

/// Imperative side-drawer presenter. Install once with `.drawerHost()`, then from
/// any descendant view:
///
///     @Environment(DrawerPresenter.self) var drawer: DrawerPresenter
///     drawer.present(edge: .leading) { MenuView() }
///     drawer.dismiss()
@Observable
public final class DrawerPresenter {

    struct Request: Identifiable {
        let id = UUID()
        let edge: HorizontalEdge
        let width: CGFloat
        let dismissOnScrimTap: Bool
        let content: AnyView
    }

    var current: Request?

    public init() {}

    /// Open a drawer. Replaces any visible drawer.
    public func present<C: View>(
        edge: HorizontalEdge = .leading,
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
    @State private var presenter = DrawerPresenter()
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content
            .environment(presenter)
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
    /// Installs the shared `DrawerPresenter`. Apply once near the app root, above
    /// any view that calls `drawer.present(…)`.
    func drawerHost() -> some View {
        modifier(DrawerHostModifier())
    }
}

#Preview("Declarative") {
    struct Demo: View {
        @State private var open = false
        var body: some View {
            ZStack {
                PrimaryButton("Open drawer") { open = true }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .drawer(isPresented: $open) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Menu").textStyle(.headingSm)
                    ListRow("Account", leadingSystemImage: "person.circle", action: {})
                    ListRow("Settings", leadingSystemImage: "gearshape", action: {})
                    Spacer()
                }
                .padding()
                .padding(.top, 60)
            }
        }
    }
    return Demo()
}

#Preview("Imperative host") {
    struct Demo: View {
        @Environment(DrawerPresenter.self) var drawer: DrawerPresenter
        var body: some View {
            PrimaryButton("Present (trailing)") {
                drawer.present(edge: .trailing) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Filters").textStyle(.headingSm)
                        Spacer()
                    }
                    .padding()
                    .padding(.top, 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
    return Demo().drawerHost()
}
