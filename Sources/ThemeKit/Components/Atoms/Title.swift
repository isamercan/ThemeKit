//
//  Title.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A section title: optional eyebrow, title + optional subtitle, and an
/// optional trailing action (e.g. "See all").
public struct Title: View {
    @Environment(\.theme) private var theme

    private let text: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var subtitle: String? = nil
    private var eyebrow: String? = nil
    private var actionTitle: String? = nil
    private var action: (() -> Void)? = nil

    public init(_ text: String) {   // R1
        self.text = text
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                if let eyebrow {
                    Text(eyebrow.uppercased())
                        .textStyle(.overline500)
                        .foregroundStyle(theme.text(.textHero))
                }
                Text(text)
                    .textStyle(.headingBase)
                    .foregroundStyle(theme.text(.textPrimary))
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle).textStyle(.linkBase).foregroundStyle(theme.text(.textHero))
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Title {
    /// Secondary line rendered under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Uppercased kicker rendered above the title.
    func eyebrow(_ text: String?) -> Self { copy { $0.eyebrow = text } }

    /// Trailing action link (e.g. "See all") and its tap handler.
    func action(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.actionTitle = title; $0.action = action }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 24) {
        Title("Popular destinations").subtitle("Where travellers go").action("See all", action: {})
        Title("Deals").eyebrow("Limited time")
    }
    .padding()
}
