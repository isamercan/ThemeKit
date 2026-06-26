//
//  Toast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Transient bottom-anchored notification built on AlertToast, shown
//  via `.toast(...)` with optional auto-dismiss.
//

import SwiftUI

private struct ToastModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let type: AlertToastType
    let autoDismiss: Double?

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion) }

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if isPresented {
                AlertToast(title, message: message, type: type, onClose: { isPresented = false })
                    .padding(Theme.SpacingKey.md.value)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
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
        modifier(ToastModifier(isPresented: isPresented, title: title, message: message, type: type, autoDismiss: autoDismiss))
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
