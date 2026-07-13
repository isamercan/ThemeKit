//
//  WindowFrame.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Organism. An OS-window mockup — a title bar with traffic-light controls and
//  an optional centered title wrapping arbitrary content. Token-bound chrome.
//

import SwiftUI

/// The three macOS-style window control dots (decorative, token-tinted).
/// Shared by ``WindowFrame`` and ``BrowserFrame``.
struct TrafficLights: View {
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Circle().fill(theme.resolve(.error).base).frame(width: 10, height: 10)
            Circle().fill(theme.resolve(.warning).base).frame(width: 10, height: 10)
            Circle().fill(theme.resolve(.success).base).frame(width: 10, height: 10)
        }
        .accessibilityHidden(true)
    }
}

/// Organism. An OS-window frame around arbitrary content. (daisyUI "Mockup Window".)
///
/// ```swift
/// WindowFrame("Preferences") {
///     Text("Window body").padding()
/// }
/// .accent(.info)
/// ```
public struct WindowFrame<Content: View>: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let title: String?
    private let content: () -> Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var elevation: CardElevation = .soft
    private var accent: SemanticColor?

    public init(_ title: String? = nil, @ViewBuilder content: @escaping () -> Content) {   // R1
        self.title = title
        self.content = content
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    public var body: some View {
        VStack(spacing: 0) {
            titleBar
            Rectangle()
                .fill(theme.border(.borderPrimary))
                .frame(height: 1)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(theme.background(.bgBase))
        .clipShape(shape)
        .overlay(shape.stroke(theme.border(.borderPrimary), lineWidth: 1))
        .modifier(CardShadow(elevation: elevation))
        .accessibilityElement(children: .contain)
    }

    private var titleBar: some View {
        ZStack {
            if let title {
                Text(title)
                    .textStyle(.labelSm600)
                    .foregroundStyle(accent.map { theme.resolve($0).accent } ?? theme.text(.textSecondary))
                    .lineLimit(1)
            }
            HStack {
                TrafficLights()
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(accent.map { theme.resolve($0).soft } ?? theme.background(.bgSecondary))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension WindowFrame {
    /// Surface elevation: none / soft / elevated (default soft).
    func elevation(_ elevation: CardElevation) -> Self { copy { $0.elevation = elevation } }

    /// Tint the title bar with a semantic color; `nil` (default) uses neutral chrome.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("WindowFrame") {
        PreviewCase("Titled · neutral chrome") {
            WindowFrame("Settings") {
                Text("Window body content")
                    .textStyle(.bodyBase400)
                    .padding()
            }
        }
        PreviewCase("Untitled · tinted chrome + elevated") {
            WindowFrame {
                Text("Untitled window, tinted chrome")
                    .textStyle(.bodySm400)
                    .padding()
            }
            .accent(.info)
            .elevation(.elevated)
        }
        PreviewCase("Flat (no shadow)") {
            WindowFrame("Terminal") {
                Text("$ swift build")
                    .textStyle(.bodySm400)
                    .padding()
            }
            .elevation(.none)
        }
    }
}
