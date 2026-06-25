//
//  DataTable.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A multi-column data table with a header and optional zebra striping.
//  Supports tap-to-sort columns, row selection, and fully custom cell views.
//  (daisyUI "Table"; complements the label/value KeyValueTable.)
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

public struct DataTable<Row: Identifiable>: View {
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
                Text(value(row))
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
            }
        }
    }

    private let columns: [Column]
    private let rows: [Row]
    private let striped: Bool
    private let selection: Binding<Set<Row.ID>>?
    private let onRowTap: ((Row) -> Void)?

    @State private var sortColumn: Int?
    @State private var sortAscending = true

    public init(
        columns: [Column],
        rows: [Row],
        striped: Bool = true,
        selection: Binding<Set<Row.ID>>? = nil,
        onRowTap: ((Row) -> Void)? = nil
    ) {
        self.columns = columns
        self.rows = rows
        self.striped = striped
        self.selection = selection
        self.onRowTap = onRowTap
    }

    private var displayRows: [Row] {
        guard let c = sortColumn, columns.indices.contains(c), let key = columns[c].sortKey else { return rows }
        let sorted = rows.sorted { key($0) < key($1) }
        return sortAscending ? sorted : sorted.reversed()
    }

    private var isInteractive: Bool { selection != nil || onRowTap != nil }

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
            if displayRows.isEmpty {
                emptyRow
            } else {
                ForEach(Array(displayRows.enumerated()), id: \.element.id) { index, row in
                    dataRow(row, index: index)
                }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
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
        .background(Theme.shared.background(.bgElevatorPrimary))
    }

    @ViewBuilder
    private func headerCell(_ column: Column, index: Int) -> some View {
        let title = HStack(spacing: 4) {
            Text(column.title)
                .textStyle(.labelSm700)
                .foregroundStyle(Theme.shared.text(.textSecondary))
            if column.sortKey != nil {
                Icon(systemName: sortColumn == index ? (sortAscending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down",
                     size: .xs,
                     color: sortColumn == index ? Theme.shared.text(.textPrimary) : Theme.shared.text(.textTertiary))
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
        if isSelected { return Theme.shared.background(.systemcolorsBgInfoLight) }
        if striped && index % 2 == 1 { return Theme.shared.background(.bgElevatorPrimary).opacity(0.5) }
        return Theme.shared.background(.bgWhite)
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
            .foregroundStyle(Theme.shared.text(.textTertiary))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Theme.SpacingKey.lg.value)
            .background(Theme.shared.background(.bgWhite))
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
