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
    private let subtitle: String?
    private let eyebrow: String?
    private let actionTitle: String?
    private let action: (() -> Void)?

    public init(
        _ text: String,
        subtitle: String? = nil,
        eyebrow: String? = nil,
        actionTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.text = text
        self.subtitle = subtitle
        self.eyebrow = eyebrow
        self.actionTitle = actionTitle
        self.action = action
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

#Preview {
    VStack(spacing: 24) {
        Title("Popular destinations", subtitle: "Where travellers go", actionTitle: "See all", action: {})
        Title("Deals", eyebrow: "Limited time")
    }
    .padding()
}
