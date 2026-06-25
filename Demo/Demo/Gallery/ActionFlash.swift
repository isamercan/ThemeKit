//
//  ActionFlash.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  A global, dependency-light "did fire" toast for the demo gallery: any
//  component callback can call `flash("…")` to surface a top banner confirming
//  the action ran — so every interactive component is visibly testable.
//

import SwiftUI
import GlobalUIComponents

/// Singleton bus so any demo callback can post without threading an env object.
final class DemoActionBus: ObservableObject {
    static let shared = DemoActionBus()
    struct Event: Identifiable, Equatable { let id = UUID(); let text: String }
    @Published var current: Event?
    private init() {}
    @MainActor func flash(_ text: String) { current = Event(text: text) }
}

/// Surfaces a top toast confirming a component callback fired.
@MainActor func flash(_ text: String) {
    Haptics.tap()
    DemoActionBus.shared.flash(text)
}

struct ActionFlashOverlay: ViewModifier {
    @ObservedObject private var bus = DemoActionBus.shared

    func body(content: Content) -> some View {
        content.overlay(alignment: .top) {
            if let event = bus.current {
                FlashToast(text: event.text)
                    .id(event.id)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .task(id: event.id) {
                        try? await Task.sleep(nanoseconds: 1_600_000_000)
                        if bus.current?.id == event.id {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) { bus.current = nil }
                        }
                    }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: bus.current)
    }
}

private struct FlashToast: View {
    let text: String
    var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Theme.shared.foreground(.systemcolorsFgSuccess))
            Text(text)
                .textStyle(.labelBase600)
                .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                .lineLimit(1)
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value + 2)
        .background(Theme.shared.background(.bgTertiary), in: Capsule())
        .themeShadow(.elevated)
        .padding(.top, Theme.SpacingKey.sm.value)
    }
}
