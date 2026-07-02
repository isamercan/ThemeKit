//
//  PageHeader.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Screen header: optional back button, title + subtitle, trailing
/// icon actions.
public struct PageHeader: View {
    @Environment(\.theme) private var theme

    public struct Action: Identifiable {
        public let id = UUID()
        let systemImage: String
        let handler: () -> Void
        public init(systemImage: String, handler: @escaping () -> Void) {
            self.systemImage = systemImage
            self.handler = handler
        }
    }

    private let title: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var onBack: (() -> Void)?
    private var actions: [Action] = []
    private var tags: [Tag] = []

    /// A status tag shown next to the title. (Ant PageHeader `tags`.)
    public struct Tag: Identifiable {
        public let id = UUID()
        let text: String
        let style: BadgeStyle?
        public init(_ text: String, style: BadgeStyle? = nil) {
            self.text = text
            self.style = style
        }
    }

    public init(_ title: String) {   // R1
        self.title = title
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let onBack {
                Button(action: onBack) {
                    Icon(systemName: "chevron.left").size(.md).color(theme.text(.textPrimary))
                        .mirrorsInRTL()
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(title)
                        .textStyle(.headingSm)
                        .foregroundStyle(theme.text(.textPrimary))
                    ForEach(tags) { tag in
                        ThemeKit.Tag(tag.text).tagStyle(tag.style)
                    }
                }
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                }
            }

            Spacer(minLength: Theme.SpacingKey.sm.value)

            ForEach(actions) { action in
                Button(action: action.handler) {
                    Icon(systemName: action.systemImage).size(.md).color(theme.text(.textPrimary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PageHeader {
    /// Secondary line under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Status tags shown next to the title (Ant PageHeader `tags`).
    func tags(_ tags: [Tag]) -> Self { copy { $0.tags = tags } }

    /// Show a leading back button invoking `action`.
    func onBack(_ action: (() -> Void)?) -> Self { copy { $0.onBack = action } }

    /// Trailing icon actions.
    func actions(_ actions: [Action]) -> Self { copy { $0.actions = actions } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 16) {
        PageHeader("Search results")
            .subtitle("128 hotels")
            .onBack {}
            .actions([.init(systemImage: "slider.horizontal.3", handler: {}),
                      .init(systemImage: "heart", handler: {})])
        PageHeader("Settings")
    }
    .padding()
}
