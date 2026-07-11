//
//  Toast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Transient edge-anchored notification built on AlertToast, shown
//  via `.toast(...)` with optional auto-dismiss (bottom edge, unless the
//  subtree `FeedbackDefaults.toastPosition` remaps it; omitted-duration
//  overloads follow `FeedbackDefaults.toastDuration`). A custom-content
//  overload reuses the same presentation (placement, transition, motion,
//  auto-dismiss) with a fully caller-owned view instead of the AlertToast row.
//

import SwiftUI

/// Shared presentation shell for both overloads: edge-anchored overlay
/// (bottom, unless `FeedbackDefaults.toastPosition` says otherwise), `md`
/// inset, move+fade transition, micro-motion animation, and the optional
/// auto-dismiss timer. What is presented is the caller's business.
private struct ToastPresentationModifier<Toast: View>: ViewModifier {
    @Binding var isPresented: Bool
    let autoDismiss: Double?
    /// Whether `autoDismiss` was passed explicitly at the call site. `false`
    /// (the omitted-argument `.toast(...)` overloads) substitutes
    /// `FeedbackDefaults.toastDuration` when one is set — `autoDismiss: nil`
    /// already means *sticky*, so omission needs its own bit.
    let usesDefaultDuration: Bool
    /// Text posted to VoiceOver when the toast appears, so assistive-technology
    /// users hear the notification. `nil` for fully custom content the caller owns.
    let announcement: String?
    let toast: Toast

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.feedbackDefaults) private var feedbackDefaults
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    /// The anchored edge — bottom classic, remappable via `FeedbackDefaults.toastPosition`.
    private var edge: Edge { feedbackDefaults.toastPosition == .top ? .top : .bottom }
    private var effectiveAutoDismiss: Double? {
        usesDefaultDuration ? (feedbackDefaults.toastDuration ?? autoDismiss) : autoDismiss
    }

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            if isPresented {
                toast
                    .padding(Theme.SpacingKey.md.value)
                    .transition(.move(edge: edge).combined(with: .opacity))
                    .onAppear {
                        if let announcement, !announcement.isEmpty {
                            AccessibilityNotification.Announcement(announcement).post()
                        }
                    }
                    .task {
                        guard let autoDismiss = effectiveAutoDismiss else { return }
                        try? await Task.sleep(nanoseconds: UInt64(autoDismiss * 1_000_000_000))
                        isPresented = false
                    }
            }
        }
        .animation(motion, value: isPresented)
    }
}

public extension View {
    func toast(
        isPresented: Binding<Bool>,
        _ title: String,
        message: String? = nil,
        type: AlertToastType = .success,
        autoDismiss: Double? = 2.5
    ) -> some View {
        modifier(ToastPresentationModifier(
            isPresented: isPresented,
            autoDismiss: autoDismiss,
            usesDefaultDuration: false,
            announcement: [title, message].compactMap { $0 }.joined(separator: ", "),
            toast: AlertToast(title).message(message).variant(type).onClose { isPresented.wrappedValue = false }
        ))
    }

    /// `.toast(isPresented:)` without the `autoDismiss:` argument — dismisses
    /// after the subtree default (`.feedbackDefaults(toastDuration:)` when set,
    /// else 2.5s). Pass `autoDismiss:` explicitly (including `nil` for sticky)
    /// to pin the toast against the defaults.
    func toast(
        isPresented: Binding<Bool>,
        _ title: String,
        message: String? = nil,
        type: AlertToastType = .success
    ) -> some View {
        modifier(ToastPresentationModifier(
            isPresented: isPresented,
            autoDismiss: 2.5,
            usesDefaultDuration: true,
            announcement: [title, message].compactMap { $0 }.joined(separator: ", "),
            toast: AlertToast(title).message(message).variant(type).onClose { isPresented.wrappedValue = false }
        ))
    }

    /// Transient edge-anchored toast with fully custom content (bottom, unless
    /// `FeedbackDefaults.toastPosition` remaps it). Presentation (placement,
    /// transition, motion, optional auto-dismiss) matches the standard
    /// `.toast(...)`; the view itself — chrome included — is the caller's.
    /// Pair with `AlertToast` + `.toastStyle(_:)` when you only want to reskin
    /// the shell rather than replace the whole toast.
    func toast<V: View>(
        isPresented: Binding<Bool>,
        autoDismiss: Double? = nil,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(ToastPresentationModifier(
            isPresented: isPresented,
            autoDismiss: autoDismiss,
            usesDefaultDuration: false,
            announcement: nil,
            toast: content()
        ))
    }

    /// Custom-content `.toast(isPresented:)` without the `autoDismiss:`
    /// argument — sticky, unless the subtree default
    /// (`.feedbackDefaults(toastDuration:)`) supplies a duration.
    func toast<V: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(ToastPresentationModifier(
            isPresented: isPresented,
            autoDismiss: nil,
            usesDefaultDuration: true,
            announcement: nil,
            toast: content()
        ))
    }
}

#Preview {
    // Presentation modifier — the presented state is pinned (`.constant(true)`,
    // sticky `autoDismiss: nil`) so each matrix cell holds one static frame.
    PreviewMatrix("Toast") {
        PreviewCase("Success") {
            Color.clear.frame(height: 110)
                .toast(isPresented: .constant(true), "Saved successfully", type: .success, autoDismiss: nil)
        }
        PreviewCase("Error · with message") {
            Color.clear.frame(height: 130)
                .toast(isPresented: .constant(true), "Upload failed",
                       message: "Check your connection and try again.", type: .danger, autoDismiss: nil)
        }
        PreviewCase("Info") {
            Color.clear.frame(height: 110)
                .toast(isPresented: .constant(true), "Copied to clipboard", type: .info, autoDismiss: nil)
        }
    }
}

#Preview("Capsule style + custom content") {
    struct Demo: View {
        @State var showStyled = true
        @State var showCustom = true
        @Environment(\.theme) private var theme
        var body: some View {
            VStack(spacing: 0) {
                // Standard toast, reskinned via the ToastStyle hook.
                Color.clear
                    .toast(isPresented: $showStyled, "Copied to clipboard", type: .info, autoDismiss: nil)
                    .toastStyle(.capsule)
                // Fully custom content through the new overload.
                Color.clear
                    .toast(isPresented: $showCustom) {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Icon(systemName: "wifi.slash").size(.sm)
                            Text("You're offline").textStyle(.labelBase600)
                            ThemeButton("Retry") { showCustom = false }.variant(.outline).size(.small)
                        }
                        .padding(Theme.SpacingKey.md.value)
                        .background(theme.background(.bgWhite),
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
                        .themeShadow(.elevated)
                    }
            }
        }
    }
    return Demo()
}
