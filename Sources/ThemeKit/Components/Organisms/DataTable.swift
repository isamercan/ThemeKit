//
//  DataTable.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ColumnAlign {
    case leading, center, trailing
    var alignment: Alignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

/// Type-erased, comparable sort value for a sortable column. `string` uses a
/// natural (numeric-aware) ordering so "item2" sorts before "item10".
public enum TableSortKey: Comparable {
    case number(Double)
    case string(String)
    case date(Date)

    public static func < (lhs: TableSortKey, rhs: TableSortKey) -> Bool {
        switch (lhs, rhs) {
        case let (.number(a), .number(b)): return a < b
        case let (.string(a), .string(b)): return a.localizedStandardCompare(b) == .orderedAscending
        case let (.date(a), .date(b)): return a < b
        default: return false   // mixed kinds: undefined ordering, keep stable
        }
    }
}

/// Organism. A multi-column data table with a header and optional zebra striping.
/// Supports tap-to-sort columns, row selection, and fully custom cell views.
/// (daisyUI "Table"; complements the label/value KeyValueTable.)
public struct DataTable<Row: Identifiable>: View {
    @Environment(\.theme) private var theme

    public struct Column {
        let title: String
        let align: ColumnAlign
        let sortKey: ((Row) -> TableSortKey)?
        let content: (Row) -> AnyView

        /// Custom-view cell. Pass `sortKey` to make the column tap-to-sort.
        public init<V: View>(
            _ title: String,
            align: ColumnAlign = .leading,
            sortKey: ((Row) -> TableSortKey)? = nil,
            @ViewBuilder content: @escaping (Row) -> V
        ) {
            self.title = title
            self.align = align
            self.sortKey = sortKey
            self.content = { AnyView(content($0)) }
        }

        /// Plain-text cell convenience.
        public init(
            _ title: String,
            align: ColumnAlign = .leading,
            sortKey: ((Row) -> TableSortKey)? = nil,
            value: @escaping (Row) -> String
        ) {
            self.init(title, align: align, sortKey: sortKey) { row in
                DefaultTextCell(text: value(row))
            }
        }
    }

    private let columns: [Column]
    private let rows: [Row]
    private let striped: Bool
    private let selection: Binding<Set<Row.ID>>?
    private let pageSize: Int?
    private let isLoading: Bool
    private let onRowTap: ((Row) -> Void)?

    @State private var sortColumn: Int?
    @State private var sortAscending = true
    @State private var currentPage = 1

    public init(
        columns: [Column],
        rows: [Row],
        striped: Bool = true,
        selection: Binding<Set<Row.ID>>? = nil,
        pageSize: Int? = nil,
        isLoading: Bool = false,
        onRowTap: ((Row) -> Void)? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.striped = striped
        self.selection = selection
        self.pageSize = pageSize
        self.isLoading = isLoading
        self.onRowTap = onRowTap
    }

    private var displayRows: [Row] {
        guard let c = sortColumn, columns.indices.contains(c), let key = columns[c].sortKey else { return rows }
        let sorted = rows.sorted { key($0) < key($1) }
        return sortAscending ? sorted : sorted.reversed()
    }

    private var isInteractive: Bool { selection != nil || onRowTap != nil }

    private var pageCount: Int { Self.pageCount(rowCount: displayRows.count, pageSize: pageSize) }
    private var pagedRows: [Row] {
        Array(displayRows[Self.pageRange(rowCount: displayRows.count, pageSize: pageSize, page: currentPage)])
    }
    private func clampPage() { if currentPage > pageCount { currentPage = pageCount } }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            tableCard
            if pageSize != nil, pageCount > 1 {
                HStack {
                    Spacer()
                    Pagination(current: $currentPage, total: pageCount)
                }
            }
        }
        .onChange(of: rows.count) { _, _ in clampPage() }
        .onChange(of: sortColumn) { _, _ in currentPage = 1 }
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            headerRow
            if isLoading {
                loadingRow
            } else if displayRows.isEmpty {
                emptyRow
            } else {
                // Lazy so an unpaginated table (pageSize == nil) over many rows only
                // builds visible rows when scrolled; a no-op when paged/standalone.
                LazyVStack(spacing: 0) {
                    ForEach(Array(pagedRows.enumerated()), id: \.element.id) { index, row in
                        dataRow(row, index: index)
                    }
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: 1)
        )
    }

    // MARK: - Header

    private var headerRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                headerCell(column, index: index)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(theme.background(.bgElevatorPrimary))
    }

    @ViewBuilder
    private func headerCell(_ column: Column, index: Int) -> some View {
        let title = HStack(spacing: 4) {
            Text(column.title)
                .textStyle(.labelSm700)
                .foregroundStyle(theme.text(.textSecondary))
            if column.sortKey != nil {
                Icon(systemName: sortColumn == index ? (sortAscending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down",
                     size: .xs,
                     color: sortColumn == index ? theme.text(.textPrimary) : theme.text(.textTertiary))
            }
        }
        .frame(maxWidth: .infinity, alignment: column.align.alignment)

        if column.sortKey != nil {
            Button { toggleSort(index) } label: { title }
                .buttonStyle(.plain)
        } else {
            title
        }
    }

    private func toggleSort(_ index: Int) {
        if sortColumn == index { sortAscending.toggle() }
        else { sortColumn = index; sortAscending = true }
    }

    // MARK: - Rows

    @ViewBuilder
    private func dataRow(_ row: Row, index: Int) -> some View {
        let isSelected = selection?.wrappedValue.contains(row.id) ?? false
        let base = HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                column.content(row)
                    .frame(maxWidth: .infinity, alignment: column.align.alignment)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(rowBackground(index: index, isSelected: isSelected))

        if isInteractive {
            base.contentShape(Rectangle()).onTapGesture { handleTap(row) }
        } else {
            base
        }
    }

    private func rowBackground(index: Int, isSelected: Bool) -> Color {
        if isSelected { return theme.background(.systemcolorsBgInfoLight) }
        if striped && index % 2 == 1 { return theme.background(.bgElevatorPrimary).opacity(0.5) }
        return theme.background(.bgWhite)
    }

    private func handleTap(_ row: Row) {
        if let selection {
            if selection.wrappedValue.contains(row.id) { selection.wrappedValue.remove(row.id) }
            else { selection.wrappedValue.insert(row.id) }
        }
        onRowTap?(row)
    }

    private var emptyRow: some View {
        Text(String(themeKit: "No data"))
            .textStyle(.bodyBase400)
            .foregroundStyle(theme.text(.textTertiary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.SpacingKey.lg.value)
            .background(theme.background(.bgWhite))
    }

    private var loadingRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Spinner(size: IconSize.sm.value, lineWidth: 2)
            Text(String(themeKit: "Loading…"))
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textTertiary))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Theme.SpacingKey.lg.value)
        .background(theme.background(.bgWhite))
    }

    // MARK: - Pure paging (extracted for testing)

    /// Number of pages for `rowCount` items at `pageSize` (1 when paging is off).
    static func pageCount(rowCount: Int, pageSize: Int?) -> Int {
        guard let size = pageSize, size > 0, rowCount > 0 else { return 1 }
        return (rowCount + size - 1) / size
    }

    /// Index range of the rows shown on `page` (clamped); the full range when off.
    static func pageRange(rowCount: Int, pageSize: Int?, page: Int) -> Range<Int> {
        guard let size = pageSize, size > 0, rowCount > 0 else { return 0..<rowCount }
        let clamped = min(max(page, 1), pageCount(rowCount: rowCount, pageSize: size))
        let start = (clamped - 1) * size
        return start..<min(start + size, rowCount)
    }
}

// The plain-text column's default cell, as a View so it resolves the injected
// `\.theme` (the `Column` value type that builds it has no environment).
private struct DefaultTextCell: View {
    let text: String
    @Environment(\.theme) private var theme

    var body: some View {
        Text(text)
            .textStyle(.bodyBase400)
            .foregroundStyle(theme.text(.textPrimary))
    }
}

#Preview {
    struct Booking: Identifiable { let id = UUID(); let hotel: String; let nights: Int; let price: Double }
    struct Demo: View {
        @State private var selected: Set<UUID> = []
        let rows = [
            Booking(hotel: "Grand Hotel", nights: 3, price: 4250),
            Booking(hotel: "Sea Resort", nights: 5, price: 7800),
            Booking(hotel: "City Inn", nights: 2, price: 1900),
        ]
        var body: some View {
            DataTable(columns: [
                .init("Hotel", sortKey: { .string($0.hotel) }) { $0.hotel },
                .init("Nights", align: .center, sortKey: { .number(Double($0.nights)) }) { "\($0.nights)" },
                .init("Price", align: .trailing, sortKey: { .number($0.price) }) { row in
                    Text("₺\(Int(row.price))").textStyle(.labelSm700)
                },
            ], rows: rows, selection: $selected)
            .padding()
        }
    }
    return Demo()
}
