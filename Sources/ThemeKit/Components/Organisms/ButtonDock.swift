//
//  ButtonDock.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Keeps action buttons pinned to the bottom of a screen via a safe-
//  area inset, with a top divider + surface.
//

import SwiftUI

public extension View {
    /// Pins `content` to the bottom edge as a docked action bar.
    func buttonDock<DockContent: View>(@ViewBuilder content: () -> DockContent) -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            ButtonDockBar(content: content())
        }
    }
}

// Extracted into a View so the dock surface resolves the injected `\.theme`.
private struct ButtonDockBar<DockContent: View>: View {
    let content: DockContent
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 0) {
            DividerView().size(.small)
            content
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.top, Theme.SpacingKey.sm.value)
        }
        .background(theme.background(.bgWhite))
    }
}

#Preview {
    // Safe-area-inset organism — docked inside a fixed-height cell.
    PreviewMatrix("ButtonDock") {
        PreviewCase("Docked actions") {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { i in
                        Text("Row \(i)").frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                }
            }
            .buttonDock {
                ButtonGroup(.horizontal) {
                    SecondaryButton("Cancel") {}
                    PrimaryButton("Continue") {}
                }
            }
            .frame(height: 280)
        }
    }
}
