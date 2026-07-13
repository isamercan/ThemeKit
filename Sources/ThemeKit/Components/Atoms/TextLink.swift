//
//  TextLink.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A standalone tappable text link. (daisyUI "Link"; for links inside a
/// paragraph use InlineText, for a button use LinkButton.)
public struct TextLink: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let action: () -> Void
    // Appearance/config — mutated only through the modifiers below (R2).
    private var underline: Bool = true
    private var accent: SemanticColor?

    public init(_ title: String, action: @escaping () -> Void) {   // R1
        self.title = title
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Text(title)
                .textStyle(.linkBase)
                .underline(underline)
                .foregroundStyle(accent.map { theme.resolve($0).accent } ?? theme.text(.textHero))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TextLink {
    /// Underline the link text (default true); pass `false` for a plain link.
    func underline(_ on: Bool = true) -> Self { copy { $0.underline = on } }

    /// Semantic tint for the link text; `nil` (default) uses the theme's hero
    /// text token. (daisyUI `link-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("TextLink") {
        PreviewCase("Default") { TextLink("Forgot password?") {} }
        PreviewCase("No underline") { TextLink("Learn more") {}.underline(false) }
        PreviewCase("Error accent") { TextLink("Delete account") {}.accent(.error) }
        PreviewCase("Success · plain") { TextLink("View receipt") {}.accent(.success).underline(false) }
    }
}
