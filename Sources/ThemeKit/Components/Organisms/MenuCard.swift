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

    public init(items: [Item]) {
        self.items = items
    }

    public var body: some View {
        Card(padding: 0) {
            VStack(spacing: 0) {
                ForEach(items) { item in
                    ListRow(item.title, action: item.action).subtitle(item.subtitle).icon(item.systemImage)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                    if item.id != items.last?.id {
                        DividerView(size: .small).padding(.leading, Theme.SpacingKey.md.value)
                    }
                }
            }
        }
    }
}

#Preview {
    MenuCard(items: [
        .init(title: "Reservations", subtitle: "Upcoming & past", systemImage: "calendar"),
        .init(title: "Payment methods", subtitle: "Cards & wallets", systemImage: "creditcard"),
        .init(title: "Help center", subtitle: "FAQ & support", systemImage: "questionmark.circle"),
    ])
    .padding()
}
