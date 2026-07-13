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

/// Where the toast stack is anchored: an edge (centered) or a corner. Corner
/// cases are *logical* — leading/trailing, not left/right — so they mirror
/// automatically under right-to-left layouts (Ant/HeroUI's 6 placements).
public enum ToastPosition: CaseIterable {
    case top, bottom
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// The vertical screen edge this anchor belongs to — drives the insert /
    /// remove transition direction and the stacking order.
    var verticalEdge: Edge {
        switch self {
        case .top, .topLeading, .topTrailing: return .top
        case .bottom, .bottomLeading, .bottomTrailing: return .bottom
        }
    }

    /// Overlay alignment for this anchor (logical, so RTL-safe by construction).
    var overlayAlignment: Alignment {
        switch self {
        case .top: return .top
        case .bottom: return .bottom
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    /// Horizontal placement of the stack inside its full-width layer:
    /// edge cases stay centered (the historical look), corners hug their side.
    var stackAlignment: Alignment {
        switch self {
        case .top, .bottom: return .center
        case .topLeading, .bottomLeading: return .leading
        case .topTrailing, .bottomTrailing: return .trailing
        }
    }
}

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
        /// Whether `duration` was passed explicitly at the call site. `false`
        /// (the omitted-argument `toast(...)` overloads) lets the host layer
        /// substitute `FeedbackDefaults.toastDuration` when one is set —
        /// `duration: nil` already means *sticky*, so omission needs its own bit.
        let hasExplicitDuration: Bool
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
             hasExplicitDuration: Bool = true,
             position: ToastPosition? = nil, onShow: (() -> Void)? = nil,
             onDismiss: (() -> Void)? = nil, custom: AnyView? = nil) {
            self.title = title
            self.message = message
            self.kind = kind
            self.systemImage = systemImage
            self.isLoading = isLoading
            self.action = action
            self.duration = duration
            self.hasExplicitDuration = hasExplicitDuration
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
        /// Whether `duration` was passed explicitly at the call site — `false`
        /// lets the host substitute `FeedbackDefaults.toastDuration` when set.
        let hasExplicitDuration: Bool
        /// Tappable substrings of `message`; when non-empty the card renders
        /// the message via `InlineText` (the shipped links idiom).
        let links: [(substring: String, action: () -> Void)]
        /// When set, the card body renders this instead of the stock icon +
        /// title / message layout; the card chrome and dismissal are shared.
        let custom: AnyView?

        init(title: String, message: String?, kind: FeedbackKind, duration: Double,
             hasExplicitDuration: Bool = true,
             links: [(substring: String, action: () -> Void)] = [],
             custom: AnyView? = nil) {
            self.title = title
            self.message = message
            self.kind = kind
            self.duration = duration
            self.hasExplicitDuration = hasExplicitDuration
            self.links = links
            self.custom = custom
        }
    }

    /// Stacked toasts (newest last), capped at `maxVisibleToasts`.
    var toasts: [ToastItem] = []
    var activeConfirm: ConfirmRequest?
    var activeNotification: NotificationItem?
    var activeLoading: String?

    /// Stack cap (oldest drops past it). Internal setter so the `.feedbackHost`
    /// overlay can sync it from `FeedbackDefaults.maxVisibleToasts` — callers
    /// still size it via `feedbackHost(maxVisibleToasts:)` / this class's init.
    var maxVisibleToasts: Int

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

    /// `toast(_:)` without the `duration:` argument — the toast auto-dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set
    /// on the host's environment, else 2.5s). `duration: nil` already means
    /// *sticky*, so omission is its own overload; pass `duration:` explicitly
    /// (including `nil`) to pin a toast against the defaults.
    @discardableResult
    public func toast(
        _ title: String,
        message: String? = nil,
        kind: FeedbackKind = .success,
        systemImage: String? = nil,
        action: ToastAction? = nil,
        position: ToastPosition? = nil,
        onShow: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) -> UUID {
        enqueue(ToastItem(title: title, message: message, kind: kind,
                          systemImage: systemImage, isLoading: false, action: action,
                          duration: 2.5, hasExplicitDuration: false, position: position,
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

    /// Custom-content `toast {}` without the `duration:` argument — auto-dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set,
    /// else 2.5s). Pass `duration:` explicitly (including `nil` for sticky) to
    /// pin the toast against the defaults.
    @discardableResult
    public func toast<Content: View>(
        position: ToastPosition? = nil,
        onShow: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> UUID {
        enqueue(ToastItem(title: "", message: nil, kind: .info, systemImage: nil,
                          isLoading: false, action: nil, duration: 2.5,
                          hasExplicitDuration: false, position: position,
                          onShow: onShow, onDismiss: onDismiss,
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

    /// `notify(_:)` without the `duration:` argument — the card auto-dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set
    /// on the host's environment, else 4s).
    public func notify(_ title: String, message: String? = nil, kind: FeedbackKind = .info) {
        activeNotification = NotificationItem(title: title, message: message, kind: kind,
                                              duration: 4, hasExplicitDuration: false)
    }

    /// `notify(_:)` with tappable inline substrings in the message — rendered
    /// via `InlineText` (API symmetry with `Callout.links` / `AlertToast`'s
    /// `message(_:links:)`). Additive overload; existing `notify` calls are
    /// untouched.
    public func notify(_ title: String, message: String,
                       links: [(substring: String, action: () -> Void)],
                       kind: FeedbackKind = .info, duration: Double = 4) {
        activeNotification = NotificationItem(title: title, message: message, kind: kind,
                                              duration: duration, links: links)
    }

    /// Links `notify(_:)` without the `duration:` argument — auto-dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set,
    /// else 4s).
    public func notify(_ title: String, message: String,
                       links: [(substring: String, action: () -> Void)],
                       kind: FeedbackKind = .info) {
        activeNotification = NotificationItem(title: title, message: message, kind: kind,
                                              duration: 4, hasExplicitDuration: false, links: links)
    }

    /// Present a notification card with fully custom body content. Same top-edge
    /// card chrome, close button, transition and auto-dismiss as `notify(_:)`.
    public func notify<Content: View>(duration: Double = 4, @ViewBuilder content: () -> Content) {
        activeNotification = NotificationItem(title: "", message: nil, kind: .info,
                                              duration: duration, custom: AnyView(content()))
    }

    /// Custom-content `notify {}` without the `duration:` argument — auto-dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set, else 4s).
    public func notify<Content: View>(@ViewBuilder content: () -> Content) {
        activeNotification = NotificationItem(title: "", message: nil, kind: .info, duration: 4,
                                              hasExplicitDuration: false, custom: AnyView(content()))
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
    /// Subtree house defaults (`.feedbackDefaults(...)` applied around the host);
    /// they sit between a per-toast argument and the host's own parameters.
    @Environment(\.feedbackDefaults) private var feedbackDefaults

    @State private var presenter: FeedbackPresenter
    private let defaultPosition: ToastPosition
    private let defaultCap: Int

    /// Effective default edge: `FeedbackDefaults.toastPosition` when set, else
    /// the `feedbackHost(toastPosition:)` parameter. A per-toast `position:`
    /// still wins over both.
    private var effectiveDefaultPosition: ToastPosition {
        feedbackDefaults.toastPosition ?? defaultPosition
    }

    /// Effective anchor for the notification card:
    /// `FeedbackDefaults.notificationPosition` when set, else the historical
    /// top edge. (The card spans the full width, so corner anchors matter for
    /// their vertical edge; the alignment is logical and RTL-safe regardless.)
    private var effectiveNotificationPosition: ToastPosition {
        feedbackDefaults.notificationPosition ?? .top
    }

    /// Insert/remove animation for the toast stack — `FeedbackDefaults.toastMotion`
    /// when set (else the stock `.base`), as a spring, gated the `MicroMotion`
    /// way: `nil` (state applies instantly, no motion) when micro-animations
    /// are off or the system Reduce Motion setting is on.
    private var toastStackAnimation: Animation? {
        guard micro && !reduceMotion else { return nil }
        return (feedbackDefaults.toastMotion ?? .base).spring
    }

    /// HeroUI-style stack depth: each toast behind the newest peeks out by a few
    /// points and recedes at ~0.97 scale per depth step. Fixed chrome constants
    /// (no semantic token exists for a stack-depth transform).
    private let stackPeek: CGFloat = 6
    private let stackScale: CGFloat = 0.97
    private var depthOn: Bool { micro && !reduceMotion }

    init(maxVisibleToasts: Int, toastPosition: ToastPosition) {
        _presenter = State(wrappedValue: FeedbackPresenter(maxVisibleToasts: maxVisibleToasts))
        defaultPosition = toastPosition
        defaultCap = maxVisibleToasts
    }

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .overlay(alignment: effectiveNotificationPosition.overlayAlignment) { notificationLayer }
            .overlay(alignment: .top) { toastLayer(.top) }
            .overlay(alignment: .bottom) { toastLayer(.bottom) }
            .overlay(alignment: .topLeading) { toastLayer(.topLeading) }
            .overlay(alignment: .topTrailing) { toastLayer(.topTrailing) }
            .overlay(alignment: .bottomLeading) { toastLayer(.bottomLeading) }
            .overlay(alignment: .bottomTrailing) { toastLayer(.bottomTrailing) }
            .overlay { confirmLayer }
            .overlay { loadingLayer }
            .animation(toastStackAnimation, value: presenter.toasts.map(\.id))
            .animation(Motion.base.animation, value: presenter.activeConfirm?.id)
            .animation(Motion.base.animation, value: presenter.activeNotification?.id)
            .animation(Motion.fast.animation, value: presenter.activeLoading)
            // The presenter is constructed in `init`, where the environment isn't
            // readable — sync the stack cap from `FeedbackDefaults` here instead.
            .onChange(of: feedbackDefaults.maxVisibleToasts, initial: true) { _, cap in
                presenter.maxVisibleToasts = max(1, cap ?? defaultCap)
            }
    }

    @ViewBuilder
    private var loadingLayer: some View {
        if let title = presenter.activeLoading {
            ZStack {
                Backdrop(fade: 0.7).ignoresSafeArea()   // shared themable scrim (bgBackdrop token)
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
                    Icon(systemName: note.kind.systemImage).size(.md).color(theme.resolve(note.kind.semanticColor).accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(note.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                        if let message = note.message {
                            if note.links.isEmpty {
                                Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                            } else {
                                // Tappable substrings via the shipped links idiom;
                                // InlineText's default base color is textSecondary,
                                // matching the plain-message line above.
                                InlineText(message, links: note.links).inlineStyle(.bodySm400)
                            }
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
            .transition(.move(edge: effectiveNotificationPosition.verticalEdge).combined(with: .opacity))
            .task(id: note.id) {
                // Omitted-duration `notify(...)` falls back to the subtree default.
                let duration = note.hasExplicitDuration
                    ? note.duration
                    : (feedbackDefaults.toastDuration ?? note.duration)
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if presenter.activeNotification?.id == note.id { presenter.dismissNotification() }
            }
        }
    }

    /// The toast stack anchored to one edge. Items route by their *effective*
    /// position — the per-toast override, then `FeedbackDefaults.toastPosition`,
    /// then the host's `toastPosition:` parameter.
    @ViewBuilder
    private func toastLayer(_ position: ToastPosition) -> some View {
        let stack = presenter.toasts.filter { ($0.position ?? effectiveDefaultPosition) == position }
        if !stack.isEmpty {
            let edge = position.verticalEdge
            let isTop = edge == .top
            // Newest nearest the anchored edge: bottom keeps array order, top reverses.
            let ordered = isTop ? Array(stack.reversed()) : stack
            VStack(spacing: (feedbackDefaults.toastSpacing ?? .sm).value) {
                ForEach(Array(ordered.enumerated()), id: \.element.id) { index, item in
                    // Depth 0 = the newest toast; ones behind it recede with a
                    // subtle scale + peek offset toward the anchored edge.
                    // Static (flat stack) under Reduce Motion / micro-animations off.
                    let depth = isTop ? index : ordered.count - 1 - index
                    FeedbackToastRow(item: item, edge: edge) { presenter.dismissToast(item.id) }
                        .scaleEffect(depthOn ? pow(stackScale, CGFloat(depth)) : 1,
                                     anchor: isTop ? .top : .bottom)
                        .offset(y: depthOn ? CGFloat(depth) * stackPeek * (isTop ? -1 : 1) : 0)
                        .zIndex(Double(-depth))   // newest draws above what it overlaps
                }
            }
            // Edge anchors stay centered (the historical look); corner anchors
            // hug their logical side, mirroring under RTL by construction.
            .frame(maxWidth: .infinity, alignment: position.stackAlignment)
            .padding((feedbackDefaults.toastOffset ?? .md).value)
        }
    }

    @ViewBuilder
    private var confirmLayer: some View {
        if let confirm = presenter.activeConfirm {
            ZStack {
                Backdrop()
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
                .accessibilityAddTraits(.isModal)   // VoiceOver ignores the dimmed content behind it
                .accessibilityAction(.escape) { presenter.dismissConfirm() }   // two-finger scrub dismisses
            }
            .transition(.opacity)
        }
    }
}

/// One stacked toast row: a solid AlertToast with elevation, auto-dismiss, and a
/// drag-toward-the-edge swipe-to-dismiss gesture (the shared `dismissDrag`,
/// ADR-7 — 60pt release threshold, fading over 120pt, the row's historical feel).
private struct FeedbackToastRow: View {
    let item: FeedbackPresenter.ToastItem
    let edge: Edge
    let onDismiss: () -> Void

    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// Read here (inside the view tree) because `FeedbackPresenter.toast(...)`
    /// is called from outside it — the omitted-duration overloads resolve their
    /// effective duration at this host layer.
    @Environment(\.feedbackDefaults) private var feedbackDefaults

    /// 0…1 dismissal progress reported by `dismissDrag` — fades the row out as
    /// it is dragged toward its anchored edge.
    @State private var dragProgress: Double = 0

    /// 1…0 fraction of the auto-dismiss countdown still remaining — drives the
    /// timeout progress bar. Updated by the countdown loop itself, so dragging
    /// pauses the bar together with the timer.
    @State private var remainingFraction: Double = 1

    /// Fixed chrome: hairline height of the timeout progress bar (no semantic
    /// token exists for a meter hairline — cf. `stackPeek` above).
    private let progressBarHeight: CGFloat = 2

    /// Explicit `duration:` (including `nil` = sticky) wins; the omitted-argument
    /// overloads fall back to `FeedbackDefaults.toastDuration`, then the stock 2.5s.
    private var effectiveDuration: Double? {
        item.hasExplicitDuration ? item.duration : (feedbackDefaults.toastDuration ?? item.duration)
    }

    /// HeroUI `shouldShowTimeoutProgress`: opt-in via `FeedbackDefaults`, only
    /// meaningful when a countdown exists (suppressed for sticky toasts), and
    /// suppressed under Reduce Motion — it is a continuously animating drain.
    private var showsTimeoutProgress: Bool {
        feedbackDefaults.showsTimeoutProgress == true
            && effectiveDuration != nil
            && !reduceMotion
    }

    var body: some View {
        swipeableRow
            .opacity(1 - dragProgress)
            .transition(.move(edge: edge).combined(with: .opacity))
            .onAppear { if feedbackDefaults.hapticsOnShow == true { Haptics.tap() } }
            .task(id: item.id) {
                guard let duration = effectiveDuration else { return }   // nil = sticky
                // Pause the auto-dismiss countdown while the user is dragging the
                // toast (reading / inspecting it) — Ant `pauseOnHover` semantics.
                // Previously the fixed sleep fired mid-drag and dismissed the toast.
                let tick = 0.05
                var remaining = duration
                while remaining > 0 {
                    try? await Task.sleep(nanoseconds: UInt64(tick * 1_000_000_000))
                    if Task.isCancelled { return }
                    if dragProgress == 0 {
                        remaining -= tick
                        // Drain the timeout bar from the same countdown so it
                        // pauses with the timer while the toast is dragged.
                        if showsTimeoutProgress { remainingFraction = max(0, remaining / duration) }
                    }
                }
                onDismiss()
            }
    }

    /// Thin drain bar along the toast's bottom edge showing how much of the
    /// auto-dismiss countdown remains. Purely decorative (hidden from
    /// accessibility); anchored `.leading` so it drains RTL-correctly.
    @ViewBuilder private var timeoutProgress: some View {
        if showsTimeoutProgress {
            Capsule()
                .fill(item.kind.toastType.foreground(theme).opacity(0.4))
                .frame(height: progressBarHeight)
                .scaleEffect(x: max(0, min(1, remainingFraction)), anchor: .leading)
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.bottom, Theme.SpacingKey.xs.value)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The row with the swipe-to-dismiss gesture, unless the subtree default
    /// `FeedbackDefaults.swipeToDismiss` is `false`.
    @ViewBuilder private var swipeableRow: some View {
        let base = row
            .overlay(alignment: .bottom) { timeoutProgress }
            .themeShadow(.elevated)
        if feedbackDefaults.swipeToDismiss ?? true {
            base.dismissDrag(edge: edge,
                             threshold: .points(60),
                             progressSpan: 120,
                             progress: $dragProgress,
                             onDismiss: onDismiss)
        } else {
            base
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

}

public extension View {
    /// Installs the shared `FeedbackPresenter` and its toast/confirm overlays.
    /// Apply once near the app root, above any view that calls `feedback`.
    ///
    /// - Parameters:
    ///   - maxVisibleToasts: how many stacked toasts stay on screen (oldest drops).
    ///   - toastPosition: the default edge the toast stack anchors to (default
    ///     `.bottom`); a toast can override it per-call via `toast(position:)`.
    ///
    /// Subtree house defaults set with `.feedbackDefaults(...)` *around* this
    /// host sit between a per-toast argument and these parameters: per-call →
    /// `FeedbackDefaults` → `feedbackHost(...)` parameter.
    func feedbackHost(maxVisibleToasts: Int = 3, toastPosition: ToastPosition = .bottom) -> some View {
        modifier(FeedbackHostModifier(maxVisibleToasts: maxVisibleToasts, toastPosition: toastPosition))
    }
}

private struct Seeded: View {
    let seed: (FeedbackPresenter) -> Void
    var body: some View { Trigger(seed: seed).feedbackHost(toastPosition: .bottom) }

    struct Trigger: View {
        @Environment(FeedbackPresenter.self) private var feedback: FeedbackPresenter
        let seed: (FeedbackPresenter) -> Void
        var body: some View {
            Color.clear.frame(height: 240).onAppear { seed(feedback) }
        }
    }
}

#Preview("Toasts: stack / action / task") {
    // Imperative presenter — each cell installs its own `.feedbackHost()` and
    // seeds *sticky* feedback in `onAppear` (interactive flows live in the demo).
    PreviewMatrix("Feedback") {
        PreviewCase("Toast stack · success / neutral / accent") {
            Seeded { f in
                f.toast("Saved", kind: .success, duration: nil)
                f.toast("Notifications paused", kind: .neutral, duration: nil)
                f.toast("Pro features unlocked", kind: .accent, duration: nil)
            }
        }
        PreviewCase("Sticky toast with action (Undo)") {
            Seeded { f in
                f.toast("Message deleted", kind: .info,
                        action: ToastAction("Undo") {}, duration: nil)
            }
        }
        PreviewCase("Confirm dialog · destructive") {
            Seeded { f in
                f.confirm(title: "Delete trip?", message: "This action cannot be undone.",
                          primaryTitle: "Delete", primaryKind: .error)
            }
        }
        PreviewCase("Blocking loading") {
            Seeded { f in f.loading() }
        }
    }
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
