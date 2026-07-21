//
//  BrowserFrame.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Organism. A browser-window mockup — a toolbar with traffic-light controls and
//  a URL pill wrapping arbitrary content. Token-bound chrome; composes the
//  ``TrafficLights`` dots shared with ``WindowFrame``.
//

import SwiftUI

/// Organism. A browser frame around arbitrary content. (daisyUI "Mockup Browser".)
///
/// ```swift
/// BrowserFrame(url: "https://themekit.dev") {
///     Text("Page content").padding()
/// }
/// .elevation(.elevated)
/// ```
public struct BrowserFrame<Content: View>: View {
    @Environment(\.theme) private var theme

    // Required content (R1).
    private let url: String
    private let content: () -> Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var elevation: CardElevation = .soft
    private var accent: SemanticColor?

    public init(url: String = "https://example.com", @ViewBuilder content: @escaping () -> Content) {   // R1
        self.url = url
        self.content = content
    }

    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous)
    }

    public var body: some View {
        VStack(spacing: 0) {
            toolbar
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

    private var toolbar: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            TrafficLights()
            urlPill
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(accent.map { theme.resolve($0).soft } ?? theme.background(.bgSecondary))
    }

    private var urlPill: some View {
        Text(url)
            .font(.system(.footnote, design: .monospaced))
            .foregroundStyle(accent.map { theme.resolve($0).accent } ?? theme.text(.textSecondary))
            .lineLimit(1)
            .truncationMode(.middle)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(theme.background(.bgBase), in: Capsule())
            .overlay(Capsule().stroke(theme.border(.borderPrimary), lineWidth: 1))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension BrowserFrame {
    /// Surface elevation: none / soft / elevated (default soft).
    func elevation(_ elevation: CardElevation) -> Self { copy { $0.elevation = elevation } }

    /// Tint the toolbar with a semantic color; `nil` (default) uses neutral chrome.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("BrowserFrame") {
                PreviewCase("Default") {
                    BrowserFrame(url: "https://themekit.dev/components") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Hello from the web").textStyle(.headingSm)
                            Text("Any SwiftUI content renders inside the browser chrome.")
                                .textStyle(.bodySm400)
                                .foregroundStyle(theme.text(.textSecondary))
                        }
                        .padding()
                    }
                }
                PreviewCase("Tinted + elevated") {
                    BrowserFrame {
                        Text("Default URL, tinted chrome")
                            .textStyle(.bodySm400)
                            .padding()
                    }
                    .accent(.primary)
                    .elevation(.elevated)
                }
            }
        }
    }
    return Demo()
}
