//
//  ButtonDock.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Keeps action buttons pinned to the bottom of a screen via a safe-
//  area inset, with a top divider + surface.
//
//  The bar's chrome is drawn by the active ``ButtonDockChromeStyle`` when one
//  is set with `.buttonDockChromeStyle(_:)`; the pinning stays here either way.
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
    @Environment(\.buttonDockChromeStyle) private var chromeStyle

    var body: some View {
        if chromeStyle.isDefault {
            ButtonDockSurface { content }
        } else {
            ButtonDockChromeHost(style: chromeStyle, content: AnyView(content))
        }
    }
}

#Preview {
    /// Proof of external implementability: a host-shaped dock with rounded top
    /// corners, its own padding ramp and an upward shadow.
    struct CardButtonDockStyle: ButtonDockChromeStyle {
        func makeBody(configuration: ButtonDockChromeStyleConfiguration) -> some View {
            CardButtonDockBody(configuration: configuration)
        }
    }
    struct CardButtonDockBody: View {
        let configuration: ButtonDockChromeStyleConfiguration
        @Environment(\.theme) private var theme

        private var shape: ThemeUnevenRoundedRect {
            ThemeUnevenRoundedRect(topLeadingRadius: Theme.RadiusRole.box.value,
                                   topTrailingRadius: Theme.RadiusRole.box.value)
        }

        var body: some View {
            configuration.content
                .frame(maxWidth: .infinity)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.top, Theme.SpacingKey.md.value)
                .padding(.bottom, max(Theme.SpacingKey.xl.value, configuration.safeAreaBottomInset))
                .background(theme.background(.bgWhite), in: shape)
                .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
                .themeShadow(.elevated)
        }
    }

    // Safe-area-inset organism — docked inside a fixed-height cell.
    return PreviewMatrix("ButtonDock") {
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
        PreviewCase("Custom ButtonDockChromeStyle") {
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(0..<6, id: \.self) { i in
                        Text("Row \(i)").frame(maxWidth: .infinity, alignment: .leading).padding()
                    }
                }
            }
            .buttonDock {
                HStack {
                    PriceTag(1249)
                    Spacer(minLength: Theme.SpacingKey.md.value)
                    PrimaryButton("Continue") {}
                }
            }
            .buttonDockChromeStyle(CardButtonDockStyle())
            .frame(height: 280)
        }
    }
}
