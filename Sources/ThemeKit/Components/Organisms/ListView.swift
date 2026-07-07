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
    private let rowContent: (Item) -> Row

    // Appearance/config — mutated only through the modifiers below (R2).
    private var header: String?
    private var footer: String?
    private var bordered = true
    private var loading = false
    private var split = true
    private var emptyText: String?
    private var emptySlot: AnyView?
    private var loadingSlot: AnyView?

    public init(_ items: [Item], @ViewBuilder row: @escaping (Item) -> Row) {   // R1
        self.items = items
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
                if let loadingSlot {
                    loadingSlot
                } else {
                    ForEach(0..<3, id: \.self) { index in
                        skeletonRow
                        if split && index < 2 { DividerView().size(.small).padding(.leading, Theme.SpacingKey.md.value) }
                    }
                }
            } else if items.isEmpty {
                if let emptySlot {
                    emptySlot
                } else {
                    emptyRow
                }
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ListView {
    /// Header text above the rows.
    func header(_ text: String?) -> Self { copy { $0.header = text } }

    /// Footer text below the rows.
    func footer(_ text: String?) -> Self { copy { $0.footer = text } }

    /// Draw the bordered card surface around the list.
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }

    /// Replace rows with skeleton placeholders while content loads.
    func loading(_ on: Bool = true) -> Self { copy { $0.loading = on } }

    /// Show dividers between rows (and around header/footer).
    func split(_ on: Bool = true) -> Self { copy { $0.split = on } }

    /// Text shown when there are no items (defaults to "No data").
    func emptyText(_ text: String?) -> Self { copy { $0.emptyText = text } }

    /// Custom empty-state view; when set it replaces the ``emptyText(_:)`` row.
    func empty<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.emptySlot = AnyView(content()) } }

    /// Custom loading view; when set it replaces the default skeleton rows
    /// while ``loading(_:)`` is on.
    func loadingView<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.loadingSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Row: Identifiable { let id = UUID(); let title: String; let subtitle: String }
    let rows = [Row(title: "My Account", subtitle: "Profile & security"),
                Row(title: "Notifications", subtitle: "Email & push"),
                Row(title: "Language", subtitle: "English")]
    return VStack(spacing: 24) {
        ListView(rows) { row in
            ListRow(row.title, action: {}).subtitle(row.subtitle)
        }
        .header("Settings").footer("3 items")
        ListView(rows) { _ in EmptyView() }
            .header("Loading").loading()
        ListView([Row]()) { _ in EmptyView() }
            .header("Empty slot")
            .empty {
                VStack(spacing: 8) {
                    Image(systemName: "tray")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text("Nothing here yet")
                        .textStyle(.bodySm400)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, Theme.SpacingKey.lg.value)
            }
        ListView(rows) { _ in EmptyView() }
            .header("Custom loading").loading()
            .loadingView {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, Theme.SpacingKey.lg.value)
            }
    }
    .padding()
}
