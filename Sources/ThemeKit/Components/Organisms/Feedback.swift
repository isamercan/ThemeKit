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

import SwiftUI

/// Semantic intent shared by every feedback surface (maps to the token system).
public enum FeedbackKind: String, CaseIterable {
    case success, info, warning, error

    var toastType: AlertToastType {
        switch self {
        case .success: return .success
        case .info: return .info
        case .warning: return .warning
        case .error: return .danger
        }
    }

    /// Button color for a confirm dialog's primary action.
    public var semanticColor: SemanticColor {
        switch self {
        case .success: return .success
        case .info: return .primary
        case .warning: return .warning
        case .error: return .error
        }
    }

    /// Icon shown by dialogs / notifications for this intent.
    public var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
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
    @discardableResult
    public func toast(
        _ title: String,
        message: String? = nil,
        kind: FeedbackKind = .success,
        systemImage: String? = nil,
        action: ToastAction? = nil,
        duration: Double? = 2.5
    ) -> UUID {
        enqueue(ToastItem(title: title, message: message, kind: kind,
                          systemImage: systemImage, isLoading: false, action: action, duration: duration))
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
        if toasts.count > maxVisibleToasts { toasts.removeFirst(toasts.count - maxVisibleToasts) }
        return item.id
    }

    private func replaceToast(_ id: UUID, with item: ToastItem) {
        if let i = toasts.firstIndex(where: { $0.id == id }) { toasts[i] = item }
        else { _ = enqueue(item) }
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

    /// Show a blocking loading indicator (spinner + text). Does not auto-dismiss —
    /// call `dismissLoading()` when the work completes (Ant `message.loading`).
    public func loading(_ title: String = String(themeKit: "Loading…")) { activeLoading = title }

    public func dismissToast(_ id: UUID) { toasts.removeAll { $0.id == id } }
    public func dismissAllToasts() { toasts.removeAll() }
    public func dismissConfirm() { activeConfirm = nil }
    public func dismissNotification() { activeNotification = nil }
    public func dismissLoading() { activeLoading = nil }
}

// MARK: - Host

private struct FeedbackHostModifier: ViewModifier {
    @Environment(\.theme) private var theme

    @State private var presenter: FeedbackPresenter
    private let toastEdge: Edge

    init(maxVisibleToasts: Int, toastPosition: ToastPosition) {
        _presenter = State(wrappedValue: FeedbackPresenter(maxVisibleToasts: maxVisibleToasts))
        toastEdge = toastPosition == .top ? .top : .bottom
    }

    func body(content: Content) -> some View {
        content
            .environment(presenter)
            .overlay(alignment: .top) { notificationLayer }
            .overlay(alignment: toastEdge == .top ? .top : .bottom) { toastLayer }
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
                    Spinner(size: 28, lineWidth: 3)
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
                Icon(systemName: note.kind.systemImage, size: .md, color: note.kind.semanticColor.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(note.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if let message = note.message {
                        Text(message).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
                Spacer(minLength: 0)
                Button { presenter.dismissNotification() } label: {
                    Icon(systemName: "xmark", size: .xs, color: theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
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

    private var toastLayer: some View {
        // Newest nearest the anchored edge: bottom keeps array order, top reverses.
        let ordered = toastEdge == .top ? Array(presenter.toasts.reversed()) : presenter.toasts
        return VStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(ordered) { item in
                FeedbackToastRow(item: item, edge: toastEdge) { presenter.dismissToast(item.id) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(Theme.SpacingKey.md.value)
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
        AlertToast(item.title, message: item.message, type: item.kind.toastType,
                   systemImage: item.systemImage, isLoading: item.isLoading,
                   action: item.action, onClose: onDismiss)
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
    ///   - toastPosition: which edge the toast stack anchors to (default `.bottom`).
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
                ThemeButton("Undo (sticky + action)", variant: .outline) {
                    feedback.toast("Message deleted", kind: .info,
                                   action: ToastAction("Undo") {}, duration: nil)
                }
                ThemeButton("Async task", variant: .outline) {
                    Task {
                        await feedback.toastTask(loading: "Saving…", success: "Saved") {
                            try await Task.sleep(nanoseconds: 600_000_000)
                        }
                    }
                }
            }
            .padding()
        }
    }
    return Demo().feedbackHost(toastPosition: .bottom)
}
