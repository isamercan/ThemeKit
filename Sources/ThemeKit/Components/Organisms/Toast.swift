//
//  Toast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Transient bottom-anchored notification built on AlertToast, shown
//  via `.toast(...)` with optional auto-dismiss. A custom-content overload
//  reuses the same presentation (placement, transition, motion, auto-dismiss)
//  with a fully caller-owned view instead of the AlertToast row.
//

import SwiftUI

/// Shared presentation shell for both overloads: bottom-anchored overlay,
/// `md` inset, move+fade transition, micro-motion animation, and the optional
/// auto-dismiss timer. What is presented is the caller's business.
private struct ToastPresentationModifier<Toast: View>: ViewModifier {
    @Binding var isPresented: Bool
    let autoDismiss: Double?
    /// Text posted to VoiceOver when the toast appears, so assistive-technology
    /// users hear the notification. `nil` for fully custom content the caller owns.
    let announcement: String?
    let toast: Toast

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                toast
                    .padding(Theme.SpacingKey.md.value)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .onAppear {
                        if let announcement, !announcement.isEmpty {
                            AccessibilityNotification.Announcement(announcement).post()
                        }
                    }
                    .task {
                        guard let autoDismiss else { return }
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
            announcement: [title, message].compactMap { $0 }.joined(separator: ", "),
            toast: AlertToast(title).message(message).variant(type).onClose { isPresented.wrappedValue = false }
        ))
    }

    /// Transient bottom-anchored toast with fully custom content. Presentation
    /// (placement, transition, motion, optional auto-dismiss) matches the
    /// standard `.toast(...)`; the view itself — chrome included — is the
    /// caller's. Pair with `AlertToast` + `.toastStyle(_:)` when you only want
    /// to reskin the shell rather than replace the whole toast.
    func toast<V: View>(
        isPresented: Binding<Bool>,
        autoDismiss: Double? = nil,
        @ViewBuilder content: () -> V
    ) -> some View {
        modifier(ToastPresentationModifier(
            isPresented: isPresented,
            autoDismiss: autoDismiss,
            announcement: nil,
            toast: content()
        ))
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            Color.clear
                .toast(isPresented: $show, "Saved successfully", type: .success)
        }
    }
    return Demo()
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
