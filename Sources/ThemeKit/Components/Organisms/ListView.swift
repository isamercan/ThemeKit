//
//  ListView.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Ant-style List container: optional header/footer, bordered surface, row
/// dividers (split), and a loading (skeleton) state. Generic over the item +
/// row content; pairs naturally with `ListRow`.
public struct ListView<Item: Identifiable, Row: View>: View {
    @Environment(\.theme) private var theme

    private let items: [Item]
    private let header: String?
    private let footer: String?
    private let bordered: Bool
    private let loading: Bool
    private let split: Bool
    private let emptyText: String?
    private let rowContent: (Item) -> Row

    public init(
        _ items: [Item],
        header: String? = nil,
        footer: String? = nil,
        bordered: Bool = true,
        loading: Bool = false,
        split: Bool = true,
        emptyText: String? = nil,
        @ViewBuilder row: @escaping (Item) -> Row
    ) {
        self.items = items
        self.header = header
        self.footer = footer
        self.bordered = bordered
        self.loading = loading
        self.split = split
        self.emptyText = emptyText
        self.rowContent = row
    }

    public var body: some View {
        VStack(spacing: 0) {
            if let header {
                Text(header)
                    .textStyle(.labelBase600)
                    .foregroundStyle(theme.text(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
                if split { DividerView().size(.small) }
            }

            if loading {
                ForEach(0..<3, id: \.self) { index in
                    skeletonRow
                    if split && index < 2 { DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value) }
                }
            } else if items.isEmpty {
                emptyRow
            } else {
                // Lazy so a long list inside a ScrollView only builds visible rows
                // (a no-op cost when used standalone / unscrolled).
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        rowContent(item)
                            .padding(.horizontal, Theme.SpacingKey.md.value)
                            .padding(.vertical, Theme.SpacingKey.sm.value)
                        if split && index < items.count - 1 {
                            DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value)
                        }
                    }
                }
            }

            if let footer {
                if split { DividerView().size(.small) }
                Text(footer)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
            }
        }
        .background(bordered ? theme.background(.bgWhite) : .clear,
                   in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
        .overlay {
            if bordered {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .stroke(theme.border(.borderPrimary), lineWidth: 1)
            }
        }
    }

    private var emptyRow: some View {
        Text(emptyText ?? String(themeKit: "No data"))
            .textStyle(.bodySm400)
            .foregroundStyle(theme.text(.textTertiary))
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.lg.value)
    }

    private var skeletonRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Circle().fill(theme.background(.bgSecondaryLight)).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4).fill(theme.background(.bgSecondaryLight)).frame(width: 140, height: 12)
                RoundedRectangle(cornerRadius: 4).fill(theme.background(.bgSecondaryLight)).frame(width: 90, height: 10)
            }
            Spacer()
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .skeleton(true)
    }
}

#Preview {
    struct Row: Identifiable { let id = UUID(); let title: String; let subtitle: String }
    let rows = [Row(title: "My Account", subtitle: "Profile & security"),
                Row(title: "Notifications", subtitle: "Email & push"),
                Row(title: "Language", subtitle: "English")]
    return VStack(spacing: 24) {
        ListView(rows, header: "Settings", footer: "3 items") { row in
            ListRow(row.title, action: {}).subtitle(row.subtitle)
        }
        ListView(rows, header: "Loading", loading: true) { _ in EmptyView() }
    }
    .padding()
}
