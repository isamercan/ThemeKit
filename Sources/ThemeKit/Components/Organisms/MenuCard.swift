//
//  MenuCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A grouped list of navigable menu links inside a card surface.
/// (Named MenuCard to avoid shadowing SwiftUI.Menu.)
public struct MenuCard: View {
    public struct Item: Identifiable {
        public let id = UUID()
        let title: String
        let subtitle: String?
        let systemImage: String?
        let action: () -> Void
        public init(title: String, subtitle: String? = nil, systemImage: String? = nil, action: @escaping () -> Void = {}) {
            self.title = title
            self.subtitle = subtitle
            self.systemImage = systemImage
            self.action = action
        }
    }

    private let items: [Item]
    private let title: String?
    private let action: () -> Void

    // Appearance/config (single-link form) — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var systemImage: String?

    public init(title: String, action: @escaping () -> Void = {}) {   // R1 — single link
        self.title = title
        self.action = action
        self.items = []
    }

    /// Data-driven list of links.
    public init(items: [Item]) {
        self.items = items
        self.title = nil
        self.action = {}
    }

    public var body: some View {
        Card {
            VStack(spacing: 0) {
                if let title {
                    ListRow(title, action: action).subtitle(subtitle).icon(systemImage)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                } else {
                    ForEach(items) { item in
                        ListRow(item.title, action: item.action).subtitle(item.subtitle).icon(item.systemImage)
                            .padding(.horizontal, Theme.SpacingKey.md.value)
                        if item.id != items.last?.id {
                            DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
                        }
                    }
                }
            }
        }
        .contentPadding(.none)   // token twin of the deprecated raw 0
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension MenuCard {
    /// Secondary line under the title (single-link form).
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Leading SF Symbol for the link (single-link form).
    func icon(_ systemImage: String?) -> Self { copy { $0.systemImage = systemImage } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("MenuCard") {
        PreviewCase("Items list") {
            MenuCard(items: [
                .init(title: "Reservations", subtitle: "Upcoming & past", systemImage: "calendar"),
                .init(title: "Payment methods", subtitle: "Cards & wallets", systemImage: "creditcard"),
                .init(title: "Help center", subtitle: "FAQ & support", systemImage: "questionmark.circle"),
            ])
        }
        PreviewCase("Single link") {
            MenuCard(title: "Settings", action: {})
                .subtitle("Preferences & account")
                .icon("gearshape")
        }
    }
}
