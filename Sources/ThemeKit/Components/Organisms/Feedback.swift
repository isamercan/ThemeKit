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
//      @EnvironmentObject var feedback: FeedbackPresenter
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

/// Imperative presenter for app-global feedback. A single shared instance is
/// injected via `.feedbackHost()`; call it from any descendant view.
public final class FeedbackPresenter: ObservableObject {

    public struct ToastItem: Identifiable, Equatable {
        public let id = UUID()
        let title: String
        let message: String?
        let kind: FeedbackKind
        let duration: Double
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

    @Published var activeToast: ToastItem?
    @Published var activeConfirm: ConfirmRequest?
    @Published var activeNotification: NotificationItem?
    @Published var activeLoading: String?

    public init() {}

    /// Show a transient toast (auto-dismisses). Replaces any visible toast.
    public func toast(_ title: String, message: String? = nil, kind: FeedbackKind = .success, duration: Double = 2.5) {
        activeToast = ToastItem(title: title, message: message, kind: kind, duration: duration)
    }

    /// Present a modal confirmation dialog with a primary (and optional secondary) action.
    public func confirm(
        title: String,
        message: String? = nil,
        primaryTitle: String,
        primaryKind: FeedbackKind = .info,
        onPrimary: @escaping () -> Void = {},
        secondaryTitle: String? = String(globalUIComponents: "Cancel"),
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
    public func loading(_ title: String = String(globalUIComponents: "Loading…")) { activeLoading = title }

    public func dismissToast() { activeToast = nil }
    public func dismissConfirm() { activeConfirm = nil }
    public func dismissNotification() { activeNotification = nil }
    public func dismissLoading() { activeLoading = nil }
}

// MARK: - Host

private struct FeedbackHostModifier: ViewModifier {
    @StateObject private var presenter = FeedbackPresenter()

    func body(content: Content) -> some View {
        content
            .environmentObject(presenter)
            .overlay(alignment: .top) { notificationLayer }
            .overlay(alignment: .bottom) { toastLayer }
            .overlay { confirmLayer }
            .overlay { loadingLayer }
            .animation(Motion.base.animation, value: presenter.activeToast)
            .animation(Motion.base.animation, value: presenter.activeConfirm?.id)
            .animation(Motion.base.animation, value: presenter.activeNotification?.id)
            .animation(Motion.fast.animation, value: presenter.activeLoading)
    }

    @ViewBuilder
    private var loadingLayer: some View {
        if let title = presenter.activeLoading {
            ZStack {
                Theme.shared.background(.bgTertiary).opacity(0.3).ignoresSafeArea()
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    Spinner(size: 28, lineWidth: 3)
                    Text(title).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
                }
                .padding(Theme.SpacingKey.lg.value)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
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
                    Text(note.title).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
                    if let message = note.message {
                        Text(message).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
                Spacer(minLength: 0)
                Button { presenter.dismissNotification() } label: {
                    Icon(systemName: "xmark", size: .xs, color: Theme.shared.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
            .padding(Theme.SpacingKey.md.value)
            .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            .themeShadow(.elevated)
            .padding(Theme.SpacingKey.md.value)
            .transition(.move(edge: .top).combined(with: .opacity))
            .task(id: note.id) {
                try? await Task.sleep(nanoseconds: UInt64(note.duration * 1_000_000_000))
                if presenter.activeNotification?.id == note.id { presenter.dismissNotification() }
            }
        }
    }

    @ViewBuilder
    private var toastLayer: some View {
        if let toast = presenter.activeToast {
            AlertToast(toast.title, message: toast.message, type: toast.kind.toastType,
                       onClose: { presenter.dismissToast() })
                .padding(Theme.SpacingKey.md.value)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: toast.id) {
                    try? await Task.sleep(nanoseconds: UInt64(toast.duration * 1_000_000_000))
                    if presenter.activeToast?.id == toast.id { presenter.dismissToast() }
                }
        }
    }

    @ViewBuilder
    private var confirmLayer: some View {
        if let confirm = presenter.activeConfirm {
            ZStack {
                Theme.shared.background(.bgTertiary).opacity(0.4)
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

public extension View {
    /// Installs the shared `FeedbackPresenter` and its toast/confirm overlays.
    /// Apply once near the app root, above any view that calls `feedback`.
    func feedbackHost() -> some View {
        modifier(FeedbackHostModifier())
    }
}
