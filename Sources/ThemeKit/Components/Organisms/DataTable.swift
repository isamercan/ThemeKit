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

/// Row density for a ``DataTable`` (Ant Table `size` large / middle / small).
/// `.middle` is the default and reproduces the original spacing.
public enum DataTableSize: Sendable { case large, middle, small }

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
        /// Fixed column width (Ant `column.width`); `nil` = flexible (shares
        /// remaining space equally with the other flexible columns).
        let width: CGFloat?
        /// Clip the cell to one line with a trailing ellipsis (Ant `column.ellipsis`).
        let ellipsis: Bool
        let content: (Row) -> AnyView

        /// Custom-view cell. Pass `sortKey` to make the column tap-to-sort,
        /// `width` for a fixed column, `ellipsis` to truncate to one line.
        public init<V: View>(
            _ title: String,
            align: ColumnAlign = .leading,
            sortKey: ((Row) -> TableSortKey)? = nil,
            width: CGFloat? = nil,
            ellipsis: Bool = false,
            @ViewBuilder content: @escaping (Row) -> V
        ) {
            self.title = title
            self.align = align
            self.sortKey = sortKey
            self.width = width
            self.ellipsis = ellipsis
            self.content = { AnyView(content($0)) }
        }

        /// Plain-text cell convenience.
        public init(
            _ title: String,
            align: ColumnAlign = .leading,
            sortKey: ((Row) -> TableSortKey)? = nil,
            width: CGFloat? = nil,
            ellipsis: Bool = false,
            value: @escaping (Row) -> String
        ) {
            self.init(title, align: align, sortKey: sortKey, width: width, ellipsis: ellipsis) { row in
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
    private var size: DataTableSize = .middle
    private var showsHeader = true
    /// Draw a leading checkbox column + select-all header (Ant `rowSelection`);
    /// only takes effect when a `selection` binding is present. Off by default,
    /// so the existing full-row-tap selection is unchanged.
    private var showsSelectionColumn = false
    private var onRowTap: ((Row) -> Void)?
    private var emptySlot: AnyView?
    private var loadingSlot: AnyView?
    private var headerSlot: AnyView?
    private var footerSlot: AnyView?

    /// Vertical cell padding for the current density (Ant `size`). `.middle`
    /// reproduces the original `SpacingKey.sm` metric.
    private var rowVPadding: CGFloat {
        switch size {
        case .large: return Theme.SpacingKey.md.value
        case .middle: return Theme.SpacingKey.sm.value
        case .small: return Theme.SpacingKey.xs.value
        }
    }

    /// Applies a column's fixed `width` (or flexible fill) + `ellipsis` clip to a cell.
    @ViewBuilder
    private func sizedCell<V: View>(_ view: V, _ column: Column) -> some View {
        let clipped = view.lineLimit(column.ellipsis ? 1 : nil)
        if let width = column.width {
            clipped.frame(width: width, alignment: column.align.alignment)
        } else {
            clipped.frame(maxWidth: .infinity, alignment: column.align.alignment)
        }
    }

    // MARK: Checkbox selection column (Ant `rowSelection`)

    /// Whether the leading checkbox column is drawn (needs a `selection` binding).
    private var hasSelectionColumn: Bool { showsSelectionColumn && selection != nil }
    /// Width of the checkbox column.
    private var selectionColumnWidth: CGFloat { 40 }
    /// IDs of the rows currently visible (the page's rows) — what select-all acts on.
    private var visibleIDs: [Row.ID] { pagedRows.map(\.id) }
    private var allVisibleSelected: Bool {
        guard let selection, !visibleIDs.isEmpty else { return false }
        return visibleIDs.allSatisfy { selection.wrappedValue.contains($0) }
    }
    private var someVisibleSelected: Bool {
        guard let selection else { return false }
        return visibleIDs.contains { selection.wrappedValue.contains($0) }
    }
    private func toggleAllVisible() {
        guard let selection else { return }
        if allVisibleSelected { visibleIDs.forEach { selection.wrappedValue.remove($0) } }
        else { visibleIDs.forEach { selection.wrappedValue.insert($0) } }
    }
    private func toggleRow(_ id: Row.ID) {
        guard let selection else { return }
        if selection.wrappedValue.contains(id) { selection.wrappedValue.remove(id) }
        else { selection.wrappedValue.insert(id) }
    }

    /// A selection checkbox glyph — filled when `on`, a dash for the header's
    /// indeterminate (some-but-not-all) state.
    private func checkbox(on: Bool, indeterminate: Bool = false) -> some View {
        Icon(systemName: on ? "checkmark.square.fill" : (indeterminate ? "minus.square.fill" : "square"))
            .size(.sm)
            .color(on || indeterminate ? theme.text(.textHero) : theme.text(.textTertiary))
    }

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

    // In checkbox-column mode the checkbox owns selection, so a row is only an
    // interactive button when it has an `onRowTap` (navigation). Otherwise a row
    // tap toggles selection (legacy), so any `selection` binding makes it interactive.
    private var isInteractive: Bool { onRowTap != nil || (selection != nil && !hasSelectionColumn) }

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
        .onChangeCompat(of: rows.count) { _, _ in clampPage() }
        .onChangeCompat(of: sortColumn) { _, _ in currentPage = 1 }
    }

    private var tableCard: some View {
        VStack(spacing: 0) {
            if showsHeader { headerRow }
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
            if hasSelectionColumn {
                Button { toggleAllVisible() } label: {
                    checkbox(on: allVisibleSelected, indeterminate: !allVisibleSelected && someVisibleSelected)
                        .frame(width: selectionColumnWidth, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: allVisibleSelected ? "Deselect all" : "Select all"))
            }
            ForEach(Array(columns.enumerated()), id: \.offset) { index, column in
                headerCell(column, index: index)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, rowVPadding)
        .background(theme.background(.bgBase))
    }

    @ViewBuilder
    private func headerCell(_ column: Column, index: Int) -> some View {
        let titleContent = HStack(spacing: 4) {
            Text(column.title)
                .textStyle(.labelSm700)
                .foregroundStyle(theme.text(.textSecondary))
            if column.sortKey != nil {
                Icon(systemName: sortColumn == index ? (sortAscending ? "chevron.up" : "chevron.down") : "chevron.up.chevron.down")
                    .size(.xs)
                    .color(sortColumn == index ? theme.text(.textPrimary) : theme.text(.textTertiary))
            }
        }
        // Same width rule as the cells so the header stays column-aligned.
        let title = sizedCell(titleContent, column)

        if column.sortKey != nil {
            Button { toggleSort(index) } label: { title }
                .buttonStyle(.plain)
                .accessibilityLabel(column.title)
                .accessibilityValue(sortColumn == index
                    ? (sortAscending ? String(themeKit: "sorted ascending") : String(themeKit: "sorted descending"))
                    : String(themeKit: "not sorted"))
                .accessibilityHint(String(themeKit: "Double-tap to sort"))
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
            if hasSelectionColumn {
                Button { toggleRow(row.id) } label: {
                    checkbox(on: isSelected)
                        .frame(width: selectionColumnWidth, alignment: .leading)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Select row"))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                sizedCell(column.content(row), column)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, rowVPadding)
        .background(rowBackground(index: index, isSelected: isSelected))

        if isInteractive {
            base.contentShape(Rectangle()).onTapGesture { handleTap(row) }
                // Tap-gesture rows carry no implicit traits — merge the cells into
                // one element and surface the button role (+ selection state) so
                // VoiceOver reads the row as a single button, not per-cell.
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        } else {
            base
        }
    }

    private func rowBackground(index: Int, isSelected: Bool) -> Color {
        if isSelected { return theme.background(.systemcolorsBgInfoLight) }
        if striped && index % 2 == 1 { return theme.background(.bgBase).opacity(0.5) }
        return theme.background(.bgWhite)
    }

    private func handleTap(_ row: Row) {
        // With the checkbox column, the checkbox owns selection — a row tap is
        // navigation only. Without it, tapping the row toggles selection (legacy).
        if !hasSelectionColumn, let selection {
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

    /// Row density (Ant Table `size`): large / middle (default) / small — scales
    /// the header + cell vertical padding. `.middle` keeps the original spacing.
    func size(_ size: DataTableSize) -> Self { copy { $0.size = size } }

    /// Show the column-title header strip (Ant `showHeader`; default on).
    func showsHeader(_ on: Bool = true) -> Self { copy { $0.showsHeader = on } }

    /// Draw a leading checkbox column with a select-all header (Ant `rowSelection`
    /// checkbox mode). Requires the `selection:` binding; when on, the checkbox
    /// owns selection and a row tap is navigation-only (`onRowTap`). Off by
    /// default — the existing full-row-tap selection is unchanged.
    func selectionColumn(_ on: Bool = true) -> Self { copy { $0.showsSelectionColumn = on } }

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

private struct Booking: Identifiable { let id = UUID(); let hotel: String; let nights: Int; let price: Double }

#Preview {
    struct Demo: View {
        @State var selected: Set<UUID> = []
        var body: some View {
            let rows = [
                Booking(hotel: "Grand Hotel", nights: 3, price: 4250),
                Booking(hotel: "Sea Resort", nights: 5, price: 7800),
                Booking(hotel: "City Inn", nights: 2, price: 1900),
            ]

            PreviewMatrix("DataTable") {
                PreviewCase("Sortable · selection + header/footer slots") {
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
                }
                // Checkbox selection column + select-all header (Ant `rowSelection`).
                PreviewCase("Checkbox selection column") {
                    DataTable(columns: [
                        .init("Hotel", sortKey: { .string($0.hotel) }) { $0.hotel },
                        .init("Price", align: .trailing) { "$\(Int($0.price))" },
                    ], rows: rows, selection: $selected)
                    .selectionColumn()
                }
                // Fixed-width + ellipsis columns, compact density, header hidden.
                PreviewCase("Fixed width · ellipsis · compact") {
                    DataTable(columns: [
                        .init("Hotel", ellipsis: true) { $0.hotel },
                        .init("Nights", align: .center, width: 64) { "\($0.nights)" },
                        .init("Price", align: .trailing, width: 88) { "$\(Int($0.price))" },
                    ], rows: rows)
                    .size(.small)
                    .showsHeader(false)
                }
                PreviewCase("Empty · custom slot") {
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
                }
                PreviewCase("Loading · custom slot") {
                    DataTable(columns: [
                        .init("Hotel") { $0.hotel },
                    ], rows: [Booking]())
                    .loading()
                    .loadingView {
                        ProgressView()
                            .padding(.vertical, Theme.SpacingKey.lg.value)
                    }
                }
            }
        }
    }
    return Demo()
}
