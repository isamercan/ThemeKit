//
//  PageHeader.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Screen header: optional back button, title + subtitle, trailing
/// icon actions.
///
/// Chrome is style-driven: set a ``BarStyle`` with `.barStyle(_:)` and the
/// header hands its back button (leading), title block (content) and icon
/// actions (trailing) to the style as a `.top`-edge ``BarStyleConfiguration``.
/// With no style set, the original chrome-less row renders pixel-identically
/// (the stock `DefaultBarStyle` would add a fill + hairline this header never
/// had, so the untouched default keeps the legacy layout).
public struct PageHeader: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.barStyle) private var barStyle

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
        if barStyle.isDefault {
            // No `.barStyle(_:)` set — the original chrome-less header row.
            legacyRow
        } else {
            barStyle.makeBody(configuration: configuration)
        }
    }

    // MARK: Legacy (default) layout — unchanged

    private var legacyRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            if let onBack { backButton(onBack) }

            titleBlock

            Spacer(minLength: Theme.SpacingKey.sm.value)

            actionButtons
        }
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    // MARK: BarStyle path

    private var configuration: BarStyleConfiguration {
        BarStyleConfiguration(leading: onBack.map { AnyView(backButton($0)) },
                              content: AnyView(styledContent),
                              trailing: actions.isEmpty ? nil : AnyView(trailingActions),
                              edge: .top)
    }

    /// The title block prepared for a style: it reserves the side-slot inset
    /// wherever an accessory occupies the slot the style overlays, and fills
    /// the standard bar row height.
    private var styledContent: some View {
        titleBlock
            .padding(.leading, onBack == nil
                     ? density.scale(Theme.SpacingKey.sm.value)
                     : BarMetrics.contentInset(density))
            .padding(.trailing, actions.isEmpty
                     ? density.scale(Theme.SpacingKey.sm.value)
                     : BarMetrics.contentInset(density))
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(minHeight: BarMetrics.rowHeight)
    }

    private var trailingActions: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) { actionButtons }
    }

    // MARK: Shared pieces

    private var titleBlock: some View {
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
    }

    private func backButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Icon(systemName: "chevron.left").size(.md).color(theme.text(.textPrimary))
                .mirrorsInRTL()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Back")
    }

    private var actionButtons: some View {
        ForEach(actions) { action in
            Button(action: action.handler) {
                Icon(systemName: action.systemImage).size(.md).color(theme.text(.textPrimary))
            }
            .buttonStyle(.plain)
        }
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
        PageHeader("Floating")
            .subtitle("BarStyle demo")
            .onBack {}
            .actions([.init(systemImage: "heart", handler: {})])
            .barStyle(.floating)
    }
    .padding()
}
