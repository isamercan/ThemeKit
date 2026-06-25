//
//  ButtonDock.swift
//  GlobalUIComponents
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
            VStack(spacing: 0) {
                DividerView(size: .small)
                content()
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.top, Theme.SpacingKey.sm.value)
            }
            .background(Theme.shared.background(.bgWhite))
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 12) {
            ForEach(0..<12, id: \.self) { i in
                Text("Row \(i)").frame(maxWidth: .infinity, alignment: .leading).padding()
            }
        }
    }
    .buttonDock {
        ButtonGroup(.horizontal) {
            SecondaryButton("Cancel", isContentWidth: true) {}
            PrimaryButton("Continue", isContentWidth: true) {}
        }
    }
}
