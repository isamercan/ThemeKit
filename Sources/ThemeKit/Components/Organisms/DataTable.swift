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
    private let selection: Binding<Set<Row.ID>>?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var striped = true
    private var pageSize: Int?
    private var isLoading = false
    private var onRowTap: ((Row) -> Void)?
    private var emptySlot: AnyView?
    private var loadingSlot: AnyView?
    private var headerSlot: AnyView?
    private var footerSlot: AnyView?

    @State private var sortColumn: Int?
    @State private var sortAscending = true
    @State private var currentPage = 1

    public init(columns: [Column], rows: [Row], selection: Binding<Set<Row.ID>>? = nil) {   // R1
        self.columns = columns
        self.rows = rows
        self.selection = selection
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
            if let headerSlot { headerSlot }
            tableCard
            if pageSize != nil, pageCount > 1 {
                HStack {
                    Spacer()
                    Pagination(current: $currentPage, total: pageCount)
                }
            }
            if let footerSlot { footerSlot }
        }
        .onChange(of: rows.count) { _, _ in clampPage() }
        .onChange(of: sortColumn) { _, _ in currentPage = 1 }
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            headerRow
            if isLoading {
                if let loadingSlot {
                    loadingSlot
                        .frame(maxWidth: .infinity)
                        .background(theme.background(.bgWhite))
                } else {
                    loadingRow
                }
            } else if displayRows.isEmpty {
                if let emptySlot {
                    emptySlot
                        .frame(maxWidth: .infinity)
                        .background(theme.background(.bgWhite))
                } else {
                    emptyRow
                }
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
                Icon(systemName: sortColumn == index ? (sortAscending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down")
                    .size(.xs)
                    .color(sortColumn == index ? theme.text(.textPrimary) : theme.text(.textTertiary))
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
            Spinner().size(IconSize.sm.value).lineWidth(2)
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DataTable {
    /// Zebra striping on alternate rows (on by default; pass `false` to disable).
    func striped(_ on: Bool = true) -> Self { copy { $0.striped = on } }

    /// Paginate rows at `size` per page (nil turns paging off).
    func pageSize(_ size: Int?) -> Self { copy { $0.pageSize = size } }

    /// Replace rows with a loading placeholder while content loads.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Callback invoked when a row is tapped (also makes rows interactive).
    func onRowTap(_ action: ((Row) -> Void)?) -> Self { copy { $0.onRowTap = action } }

    /// Custom empty-state view shown inside the card when there are no rows
    /// (replaces the default "No data" row).
    func empty<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.emptySlot = AnyView(content()) } }

    /// Custom loading view shown inside the card while ``loading(_:)`` is on
    /// (replaces the default spinner row).
    func loadingView<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.loadingSlot = AnyView(content()) } }

    /// A view rendered above the table card (outside the column-title strip) —
    /// e.g. a title, search field, or toolbar.
    func header<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.headerSlot = AnyView(content()) } }

    /// A view rendered below the table card (after pagination when present) —
    /// e.g. a summary line or legend.
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
            VStack(spacing: 24) {
                DataTable(columns: [
                    .init("Hotel", sortKey: { .string($0.hotel) }) { $0.hotel },
                    .init("Nights", align: .center, sortKey: { .number(Double($0.nights)) }) { "\($0.nights)" },
                    .init("Price", align: .trailing, sortKey: { .number($0.price) }) { row in
                        Text("$\(Int(row.price))").textStyle(.labelSm700)
                    },
                ], rows: rows, selection: $selected)
                .header {
                    HStack {
                        Text("Bookings").textStyle(.labelBase600)
                        Spacer()
                        Text("Q3").textStyle(.bodySm400).foregroundStyle(.secondary)
                    }
                }
                .footer {
                    Text("3 bookings · updated just now")
                        .textStyle(.bodySm400)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }

                DataTable(columns: [
                    .init("Hotel") { $0.hotel },
                    .init("Price", align: .trailing) { "$\(Int($0.price))" },
                ], rows: [Booking]())
                .empty {
                    VStack(spacing: 8) {
                        Image(systemName: "tray")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No bookings yet")
                            .textStyle(.bodySm400)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, Theme.SpacingKey.lg.value)
                }

                DataTable(columns: [
                    .init("Hotel") { $0.hotel },
                ], rows: [Booking]())
                .loading()
                .loadingView {
                    ProgressView()
                        .padding(.vertical, Theme.SpacingKey.lg.value)
                }
            }
            .padding()
        }
    }
    return Demo()
}
