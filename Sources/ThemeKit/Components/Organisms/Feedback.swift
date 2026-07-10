//
//  Feedback.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Unified feedback presenter — one imperative entry point for the *global*
//  feedback levels (transient toast + modal confirm), layered on the existing
//  AlertToast / Dialog components. Inline levels (InfoBanner, Callout) stay
//  developer-placed in the view tree. See docs/feedback-patterns.md.
//
//  Install once at the app root with `.feedbackHost()`, then from anywhere:
//      @Environment(FeedbackPresenter.self) var feedback: FeedbackPresenter
//      feedback.toast("Saved", kind: .success)
//      feedback.confirm(title: "Delete?", primaryTitle: "Delete", primaryKind: .error) { … }
//
//  Custom content slots: `feedback.toast { … }` and `feedback.notify { … }`
//  present caller-drawn views through the same stacking / auto-dismiss / swipe /
//  transition infrastructure as the fixed layouts.
//
//  CardStyle exception: the toast, notification and loading shells deliberately
//  do NOT read `@Environment(\.cardStyle)`. They are floating overlay chrome on
//  top of arbitrary app content; ambient card styles are tuned for in-flow cards
//  (e.g. `.outlined` has a transparent surface, which would make these surfaces
//  illegible over whatever they cover). Scrim, stacking, gestures and dismissal
//  always stay in the component.
//

import SwiftUI

/// Semantic intent shared by every feedback surface (maps to the token system).
public enum FeedbackKind: String, CaseIterable {
    case success, info, warning, error
    /// Low-emphasis message on a muted surface (HeroUI's "default" toast),
    /// and a brand-tinted accent fed by the theme's primary color.
    case neutral, accent

    var toastType: AlertToastType {
        switch self {
        case .success: return .success
        case .info: return .info
        case .warning: return .warning
        case .error: return .danger
        case .neutral: return .neutral
        case .accent: return .accent
        }
    }

    /// Button color for a confirm dialog's primary action.
    public var semanticColor: SemanticColor {
        switch self {
        case .success: return .success
        case .info: return .primary
        case .warning: return .warning
        case .error: return .error
        case .neutral: return .neutral
        case .accent: return .primary   // accent surfaces are fed by the brand primary
        }
    }

    /// Icon shown by dialogs / notifications for this intent.
    public var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .neutral: return "bell.fill"
        case .accent: return "sparkles"
        }
    }
}

/// Which edge the toast stack is anchored to.
public enum ToastPosition { case top, bottom }

/// Imperative presenter for app-global feedback. A single shared instance is
/// injected via `.feedbackHost()`; call it from any descendant view.
@Observable
public final class FeedbackPresenter {

    public struct ToastItem: Identifiable {
        public let id = UUID()
        let title: String
        let message: String?
        let kind: FeedbackKind
        let systemImage: String?
        let isLoading: Bool
        let action: ToastAction?
        let duration: Double?
        /// Per-toast edge override; `nil` falls back to the host's default.
        let position: ToastPosition?
        /// Fired when the toast is presented.
        let onShow: (() -> Void)?
        /// Fired when the toast leaves, whatever the dismissal path (timer,
        /// swipe, close button, programmatic dismissal, overflow past the cap).
        let onDismiss: (() -> Void)?
        /// When set, the row renders this instead of the stock `AlertToast`
        /// (custom content slot); the presentation infrastructure is shared.
        let custom: AnyView?

        init(title: String, message: String?, kind: FeedbackKind, systemImage: String?,
             isLoading: Bool, action: ToastAction?, duration: Double?,
             position: ToastPosition? = nil, onShow: (() -> Void)? = nil,
             onDismiss: (() -> Void)? = nil, custom: AnyView? = nil) {
            self.title = title
            self.message = message
            self.kind = kind
            self.systemImage = systemImage
            self.isLoading = isLoading
            self.action = action
            self.duration = duration
            self.position = position
            self.onShow = onShow
            self.onDismiss = onDismiss
            self.custom = custom
        }
    }

    public struct ConfirmRequest: Identifiable {
        public let id = UUID()
        let title: String
        let message: String?
        let primaryTitle: String
        let primaryKind: FeedbackKind
        let onPrimary: () -> Void
        let secondaryTitle: String?
        let onSecondary: (() -> Void)?
    }

    public struct NotificationItem: Identifiable {
        public let id = UUID()
        let title: String
        let message: String?
        let kind: FeedbackKind
        let duration: Double
        /// When set, the card body renders this instead of the stock icon +
        /// title / message layout; the card chrome and dismissal are shared.
        let custom: AnyView?

        init(title: String, message: String?, kind: FeedbackKind, duration: Double, custom: AnyView? = nil) {
            self.title = title
            self.message = message
            self.kind = kind
            self.duration = duration
            self.custom = custom
        }
    }

    /// Stacked toasts (newest last), capped at `maxVisibleToasts`.
    var toasts: [ToastItem] = []
    var activeConfirm: ConfirmRequest?
    var activeNotification: NotificationItem?
    var activeLoading: String?

    private let maxVisibleToasts: Int

    public init(maxVisibleToasts: Int = 3) {
        self.maxVisibleToasts = max(1, maxVisibleToasts)
    }

    /// Show a transient toast. Multiple toasts stack (the oldest drops past the
    /// visible cap). Pass `duration: nil` for a sticky toast — e.g. one with an
    /// `action` the user must reach (Undo). Returns the id for manual dismissal.
    ///
    /// - Parameters:
    ///   - position: which edge this toast anchors to; `nil` (default) uses the
    ///     host's `toastPosition`.
    ///   - onShow: called when the toast is presented.
    ///   - onDismiss: called when the toast leaves, on every dismissal path —
    ///     auto-dismiss timer, swipe, close button, `dismissToast(_:)` /
    ///     `dismissAllToasts()`, or being pushed past the visible cap.
    @discardableResult
    public func toast(
        _ title: String,
        message: String? = nil,
        kind: FeedbackKind = .success,
        systemImage: String? = nil,
        action: ToastAction? = nil,
        duration: Double? = 2.5,
        position: ToastPosition? = nil,
        onShow: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> UUID {
        enqueue(ToastItem(title: title, message: message, kind: kind,
                          systemImage: systemImage, isLoading: false, action: action,
                          duration: duration, position: position,
                          onShow: onShow, onDismiss: onDismiss))
    }

    /// Show a transient toast with fully custom content. Same stacking, cap,
    /// auto-dismiss (pass `duration: nil` for sticky), elevation shadow,
    /// swipe-to-dismiss, per-toast `position` and lifecycle callbacks as
    /// `toast(_:)` — only the row's visuals are yours.
    /// Returns the id for manual dismissal via `dismissToast(_:)`.
    @discardableResult
    public func toast<Content: View>(
        duration: Double? = 2.5,
        position: ToastPosition? = nil,
        onShow: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> UUID {
        enqueue(ToastItem(title: "", message: nil, kind: .info, systemImage: nil,
                          isLoading: false, action: nil, duration: duration,
                          position: position, onShow: onShow, onDismiss: onDismiss,
                          custom: AnyView(content())))
    }

    /// Present a loading toast (spinner), run async work, then morph the *same*
    /// toast into a success or failure result. Mirrors imperative toast task APIs.
    @MainActor
    public func toastTask(
        loading loadingTitle: String,
        success successTitle: String,
        failure: @escaping (Error) -> String = { _ in String(themeKit: "Something went wrong") },
        duration: Double? = 2.5,
        perform operation: @escaping () async throws -> Void
    ) async {
        let id = enqueue(ToastItem(title: loadingTitle, message: nil, kind: .info,
                                   systemImage: nil, isLoading: true, action: nil, duration: nil))
        do {
            try await operation()
            replaceToast(id, with: ToastItem(title: successTitle, message: nil, kind: .success,
                                             systemImage: nil, isLoading: false, action: nil, duration: duration))
        } catch {
            replaceToast(id, with: ToastItem(title: failure(error), message: nil, kind: .error,
                                             systemImage: nil, isLoading: false, action: nil, duration: duration))
        }
    }

    @discardableResult
    private func enqueue(_ item: ToastItem) -> UUID {
        toasts.append(item)
        if toasts.count > maxVisibleToasts {
            let overflow = Set(toasts.prefix(toasts.count - maxVisibleToasts).map(\.id))
            removeToasts { overflow.contains($0.id) }
        }
        item.onShow?()
        return item.id
    }

    private func replaceToast(_ id: UUID, with item: ToastItem) {
        if let i = toasts.firstIndex(where: { $0.id == id }) {
            toasts[i].onDismiss?()   // the old toast leaves the screen in place
            toasts[i] = item
            item.onShow?()
        } else {
            _ = enqueue(item)
        }
    }

    /// The single removal point for toasts. Every dismissal path — the
    /// auto-dismiss timer, swipe, the close button, `dismissToast(_:)`,
    /// `dismissAllToasts()`, and overflow past the visible cap — funnels
    /// through here, so each removed toast's `onDismiss` always reports.
    private func removeToasts(where shouldRemove: (ToastItem) -> Bool) {
        let removed = toasts.filter(shouldRemove)
        guard !removed.isEmpty else { return }
        toasts.removeAll(where: shouldRemove)
        removed.forEach { $0.onDismiss?() }
    }

    /// Present a modal confirmation dialog with a primary (and optional secondary) action.
    public func confirm(
        title: String,
        message: String? = nil,
        primaryTitle: String,
        primaryKind: FeedbackKind = .info,
        onPrimary: @escaping () -> Void = {},
        secondaryTitle: String? = String(themeKit: "Cancel"),
        onSecondary: (() -> Void)? = nil
    ) {
        activeConfirm = ConfirmRequest(
            title: title, message: message, primaryTitle: primaryTitle, primaryKind: primaryKind,
            onPrimary: onPrimary, secondaryTitle: secondaryTitle, onSecondary: onSecondary
        )
    }

    /// Present a richer notification card (title + message + icon) at the top.
    public func notify(_ title: String, message: String? = nil, kind: FeedbackKind = .info, duration: Double = 4) {
        activeNotification = NotificationItem(title: title, message: message, kind: kind, duration: duration)
    }

    /// Present a notification card with fully custom body content. Same top-edge
    /// card chrome, close button, transition and auto-dismiss as `notify(_:)`.
    public func notify<Content: View>(duration: Double = 4, @ViewBuilder content: () -> Content) {
        activeNotification = NotificationItem(title: "", message: nil, kind: .info,
                                              duration: duration, custom: AnyView(content()))
    }

    /// Show a blocking loading indicator (spinner + text). Does not auto-dismiss —
    /// call `dismissLoading()` when the work completes (Ant `message.loading`).
    public func loading(_ title: String = String(themeKit: "Loading…")) { activeLoading = title }

    public func dismissToast(_ id: UUID) { removeToasts { $0.id == id } }
    public func dismissAllToasts() { removeToasts { _ in true } }
    public func dismissConfirm() { activeConfirm = nil }
    public func dismissNotification() { activeNotification = nil }
    public func dismissLoading() { activeLoading = nil }
}

// MARK: - Host

private struct FeedbackHostModifier: ViewModifier {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var presenter: FeedbackPresenter
    private let defaultPosition: ToastPosition

    /// HeroUI-style stack depth: each toast behind the newest peeks out by a few
    /// points and recedes at ~0.97 scale per depth step. Fixed chrome constants
    /// (no semantic token exists for a stack-depth transform).
    private let stackPeek: CGFloat = 6
    private let stackScale: CGFloat = 0.97
    private var depthOn: Bool { micro && !reduceMotion }

    init(maxVisibleToasts: Int, toastPosition: ToastPosition) {
        _presenter = State(wrappedValue: FeedbackPresenter(maxVisibleToasts: maxVisibleToasts))
        defaultPosition = toastPosition
    }

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .overlay(alignment: .top) { notificationLayer }
            .overlay(alignment: .top) { toastLayer(.top) }
            .overlay(alignment: .bottom) { toastLayer(.bottom) }
            .overlay { confirmLayer }
            .overlay { loadingLayer }
            .animation(Motion.base.spring, value: presenter.toasts.map(\.id))
            .animation(Motion.base.animation, value: presenter.activeConfirm?.id)
            .animation(Motion.base.animation, value: presenter.activeNotification?.id)
            .animation(Motion.fast.animation, value: presenter.activeLoading)
    }

    @ViewBuilder
    private var loadingLayer: some View {
        if let title = presenter.activeLoading {
            ZStack {
                theme.background(.bgTertiary).opacity(0.3).ignoresSafeArea()
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    Spinner().size(28).lineWidth(3)
                    Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                }
                .padding(Theme.SpacingKey.lg.value)
                .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                .themeShadow(.elevated)
            }
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var notificationLayer: some View {
        if let note = presenter.activeNotification {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                if let custom = note.custom {
                    custom
                } else {
                    Icon(systemName: note.kind.systemImage).size(.md).color(note.kind.semanticColor.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                        if let message = note.message {
                            Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                        }
                    }
                }
                Spacer(minLength: 0)
                Button { presenter.dismissNotification() } label: {
                    Icon(systemName: "xmark").size(.xs).color(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Close"))
            }
            .padding(Theme.SpacingKey.md.value)
            .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            .themeShadow(.elevated)
            .padding(Theme.SpacingKey.md.value)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: note.id) {
                try? await Task.sleep(nanoseconds: UInt64(note.duration * 1_000_000_000))
                if presenter.activeNotification?.id == note.id { presenter.dismissNotification() }
            }
        }
    }

    /// The toast stack anchored to one edge. Items route by their *effective*
    /// position — the per-toast override, falling back to the host default.
    @ViewBuilder
    private func toastLayer(_ position: ToastPosition) -> some View {
        let stack = presenter.toasts.filter { ($0.position ?? defaultPosition) == position }
        if !stack.isEmpty {
            let edge: Edge = position == .top ? .top : .bottom
            // Newest nearest the anchored edge: bottom keeps array order, top reverses.
            let ordered = position == .top ? Array(stack.reversed()) : stack
            VStack(spacing: Theme.SpacingKey.sm.value) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                    // Depth 0 = the newest toast; ones behind it recede with a
                    // subtle scale + peek offset toward the anchored edge.
                    // Static (flat stack) under Reduce Motion / micro-animations off.
                    let depth = position == .top ? index : ordered.count - 1 - index
                    FeedbackToastRow(item: item, edge: edge) { presenter.dismissToast(item.id) }
                        .scaleEffect(depthOn ? pow(stackScale, CGFloat(depth)) : 1,
                                     anchor: position == .top ? .top : .bottom)
                        .offset(y: depthOn ? CGFloat(depth) * stackPeek * (position == .top ? -1 : 1) : 0)
                        .zIndex(Double(-depth))   // newest draws above what it overlaps
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(Theme.SpacingKey.md.value)
        }
    }

    @ViewBuilder
    private var confirmLayer: some View {
        if let confirm = presenter.activeConfirm {
            ZStack {
                theme.background(.bgTertiary).opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture { presenter.dismissConfirm() }
                DialogCard(
                    title: confirm.title,
                    message: confirm.message,
                    primaryTitle: confirm.primaryTitle,
                    onPrimary: { confirm.onPrimary(); presenter.dismissConfirm() },
                    secondaryTitle: confirm.secondaryTitle,
                    onSecondary: confirm.secondaryTitle == nil ? nil : { confirm.onSecondary?(); presenter.dismissConfirm() },
                    primaryColor: confirm.primaryKind.semanticColor
                )
                .padding(Theme.SpacingKey.lg.value)
            }
            .transition(.opacity)
        }
    }
}

/// One stacked toast row: a solid AlertToast with elevation, auto-dismiss, and a
/// drag-toward-the-edge swipe-to-dismiss gesture.
private struct FeedbackToastRow: View {
    let item: FeedbackPresenter.ToastItem
    let edge: Edge
    let onDismiss: () -> Void

    @State private var offset: CGFloat = 0

    var body: some View {
        row
            .themeShadow(.elevated)
            .offset(y: offset)
            .opacity(dragOpacity)
            .gesture(swipe)
            .transition(.move(edge: edge).combined(with: .opacity))
            .task(id: item.id) {
                guard let duration = item.duration else { return }   // nil = sticky
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                onDismiss()
            }
    }

    /// Stock `AlertToast`, or the caller-drawn view for custom-content toasts.
    @ViewBuilder
    private var row: some View {
        if let custom = item.custom {
            custom
        } else {
            AlertToast(item.title)
                .message(item.message)
                .variant(item.kind.toastType)
                .icon(item.systemImage)
                .loading(item.isLoading)
                .action(item.action)
                .onClose(onDismiss)
        }
    }

    /// Fade the row out as it is dragged toward its anchored edge.
    private var dragOpacity: Double {
        let towardEdge = (edge == .bottom && offset > 0) || (edge == .top && offset < 0)
        guard towardEdge else { return 1 }
        return max(0, 1 - Double(abs(offset)) / 120)
    }

    private var swipe: some Gesture {
        DragGesture(minimumDistance: 8)
            .onChanged { value in
                let dy = value.translation.height
                if (edge == .bottom && dy > 0) || (edge == .top && dy < 0) { offset = dy }
            }
            .onEnded { _ in
                if abs(offset) > 60 {
                    onDismiss()
                } else {
                    withAnimation(Motion.fast.animation) { offset = 0 }
                }
            }
    }
}

public extension View {
    /// Installs the shared `FeedbackPresenter` and its toast/confirm overlays.
    /// Apply once near the app root, above any view that calls `feedback`.
    ///
    /// - Parameters:
    ///   - maxVisibleToasts: how many stacked toasts stay on screen (oldest drops).
    ///   - toastPosition: the default edge the toast stack anchors to (default
    ///     `.bottom`); a toast can override it per-call via `toast(position:)`.
    func feedbackHost(maxVisibleToasts: Int = 3, toastPosition: ToastPosition = .bottom) -> some View {
        modifier(FeedbackHostModifier(maxVisibleToasts: maxVisibleToasts, toastPosition: toastPosition))
    }
}

#Preview("Toasts: stack / action / task") {
    struct Demo: View {
        @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
        var body: some View {
            VStack(spacing: 12) {
                ThemeButton("Stack ×3") {
                    for i in 1 ... 3 { feedback.toast("Toast #\(i)", kind: .success) }
                }
                ThemeButton("Neutral / accent") {
                    feedback.toast("Notifications paused", kind: .neutral)
                    feedback.toast("Pro features unlocked", kind: .accent)
                }
                .variant(.outline)
                ThemeButton("Top override + callbacks") {
                    feedback.toast("Heads up", kind: .info, position: .top,
                                   onShow: { print("shown") },
                                   onDismiss: { print("dismissed") })
                }
                .variant(.outline)
                ThemeButton("Undo (sticky + action)") {
                    feedback.toast("Message deleted", kind: .info,
                                   action: ToastAction("Undo") {}, duration: nil)
                }
                .variant(.outline)
                ThemeButton("Async task") {
                    Task {
                        await feedback.toastTask(loading: "Saving…", success: "Saved") {
                            try await Task.sleep(nanoseconds: 600_000_000)
                        }
                    }
                }
                .variant(.outline)
            }
            .padding()
        }
    }
    return Demo().feedbackHost(toastPosition: .bottom)
}

#Preview("Custom content slots") {
    struct Demo: View {
        @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
        @Environment(\.theme) private var theme
        var body: some View {
            VStack(spacing: 12) {
                ThemeButton("Custom toast") {
                    feedback.toast {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Spinner().size(16).lineWidth(2)
                            Text("Syncing 3 of 7 trips…")
                                .textStyle(.labelBase600)
                                .foregroundStyle(theme.text(.textPrimary))
                        }
                        .padding(Theme.SpacingKey.md.value)
                        .background(theme.background(.bgWhite), in: Capsule())
                    }
                }
                ThemeButton("Custom notification") {
                    feedback.notify {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Icon(systemName: "airplane.departure").size(.md).color(theme.foreground(.fgHero))
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Flight update").textStyle(.labelBase600)
                                    .foregroundStyle(theme.text(.textPrimary))
                                Text("Gate changed to B12 — boarding at 14:20.")
                                    .textStyle(.bodySm400)
                                    .foregroundStyle(theme.text(.textSecondary))
                            }
                        }
                    }
                }
                .variant(.outline)
            }
            .padding()
        }
    }
    return Demo().feedbackHost()
}
