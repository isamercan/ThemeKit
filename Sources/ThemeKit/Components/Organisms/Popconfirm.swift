//
//  Popconfirm.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A lightweight confirmation popover anchored to its trigger element — unlike
//  the full-screen modal `Dialog`, it points at what you're confirming.
//  (Ant Popconfirm.) Apply with `.popconfirm(...)`.
//

import SwiftUI

private struct PopconfirmModifier: ViewModifier {
    @Binding var isPresented: Bool
    let title: String
    let message: String?
    let confirmTitle: String
    let cancelTitle: String
    let confirmKind: FeedbackKind
    let edge: TooltipEdge
    let onConfirm: () -> Void
    let onCancel: (() -> Void)?

    func body(content: Content) -> some View {
        content.overlay(alignment: edge == .top ? .top : .bottom) {
            if isPresented {
                card
                    .fixedSize()
                    .alignmentGuide(edge == .top ? .top : .bottom) { d in
                        edge == .top ? d[.bottom] + 8 : d[.top] - 8
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(1)
            }
        }
        .animation(Motion.fast.animation, value: isPresented)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: "exclamationmark.circle.fill", size: .sm, color: Theme.shared.foreground(.systemcolorsFgWarning))
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).textStyle(.labelBase600).foregroundStyle(Theme.shared.text(.textPrimary))
                    if let message {
                        Text(message).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                }
            }
            HStack(spacing: Theme.SpacingKey.sm.value) {
                Spacer(minLength: 0)
                ThemeButton(cancelTitle, variant: .outline, size: .small) {
                    isPresented = false; onCancel?()
                }
                ThemeButton(confirmTitle, color: confirmKind.semanticColor, size: .small) {
                    isPresented = false; onConfirm()
                }
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(width: 260)
        .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.elevated)
    }
}

public extension View {
    /// Anchored confirmation popover. `edge` chooses above (.top) or below (.bottom) the trigger.
    func popconfirm(
        isPresented: Binding<Bool>,
        title: String,
        message: String? = nil,
        confirmTitle: String = String(themeKit: "Yes"),
        cancelTitle: String = String(themeKit: "No"),
        confirmKind: FeedbackKind = .error,
        edge: TooltipEdge = .top,
        onConfirm: @escaping () -> Void,
        onCancel: (() -> Void)? = nil
    ) -> some View {
        modifier(PopconfirmModifier(
            isPresented: isPresented, title: title, message: message,
            confirmTitle: confirmTitle, cancelTitle: cancelTitle, confirmKind: confirmKind,
            edge: edge, onConfirm: onConfirm, onCancel: onCancel
        ))
    }
}

#Preview {
    struct Demo: View {
        @State var show = true
        var body: some View {
            ThemeButton("Delete", color: .error, variant: .soft) { show.toggle() }
                .popconfirm(isPresented: $show, title: "Bu öğeyi sil?", message: "Geri alınamaz.",
                            confirmTitle: "Sil", cancelTitle: "Vazgeç") {}
                .padding(80)
        }
    }
    return Demo()
}
