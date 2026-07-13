//
//  InlineText.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. Body text with tappable inline links. Improves on the reference
/// UnderlineText by using AttributedString + openURL routing instead of manual
/// NSRange math.
public struct InlineText: View {
    @Environment(\.theme) private var theme

    private let text: String
    private let links: [(substring: String, action: () -> Void)]

    // Appearance/config — mutated only through the modifiers below (R2).
    private var baseColor: Color? = nil
    // ADR-0006: the token overload stores the `SemanticColor` (not a resolved
    // `Color`) so it re-resolves against the environment theme in `body`.
    private var semanticColor: SemanticColor? = nil
    private var style: TextStyle = .bodySm400

    public init(_ text: String, links: [(substring: String, action: () -> Void)] = []) {   // R1
        self.text = text
        self.links = links
    }

    public var body: some View {
        Text(attributed)
            .environment(\.openURL, OpenURLAction { url in
                guard url.scheme == "inline",
                      let index = Int(url.absoluteString.replacingOccurrences(of: "inline:", with: "")),
                      links.indices.contains(index) else { return .systemAction }
                links[index].action()
                return .handled
            })
    }

    private var attributed: AttributedString {
        var string = AttributedString(text)
        string.font = style.font
        string.foregroundColor = semanticColor.map { theme.resolve($0).base } ?? baseColor ?? theme.text(.textSecondary)
        for (index, link) in links.enumerated() {
            if let range = string.range(of: link.substring) {
                string[range].foregroundColor = theme.text(.textHero)
                string[range].underlineStyle = .single
                string[range].link = URL(string: "inline:\(index)")
            }
        }
        return string
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InlineText {
    /// Semantic base text color; `nil` (default) uses the theme's secondary text color.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.semanticColor = color; $0.baseColor = nil } }

    /// Raw base text color (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ color: Color?) -> Self { copy { $0.baseColor = color; $0.semanticColor = nil } }

    /// Typography token for the body text. Named `inlineStyle` so it doesn't
    /// shadow the kit-wide `.textStyle(_:)` view modifier.
    func inlineStyle(_ style: TextStyle) -> Self { copy { $0.style = style } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("InlineText") {
        PreviewCase("Links") {
            InlineText("By continuing you accept the Terms and the Privacy Policy.",
                       links: [("Terms", { print("terms") }), ("Privacy Policy", { print("privacy") })])
        }
        PreviewCase("Plain") { InlineText("A plain sentence with no anchors.") }
        PreviewCase("Accent + style") {
            InlineText("Read the Guidelines before publishing.", links: [("Guidelines", {})])
                .accent(.primary)
                .inlineStyle(.bodyBase400)
        }
    }
}
