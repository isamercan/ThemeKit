//
//  DataTable.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A multi-column data table with a header and optional zebra striping.
//  (daisyUI "Table"; complements the label/value KeyValueTable.)
//

import SwiftUI

public enum ColumnAlign {
    case leading, center, trailing
    var alignment: Alignment {
        switch self { case .leading: return .leading; case .center: return .center; case .trailing: return .trailing }
    }
}

public struct DataTable<Row: Identifiable>: View {
    public struct Column {
        let title: String
        let align: ColumnAlign
        let value: (Row) -> String
        public init(_ title: String, align: ColumnAlign = .leading, value: @escaping (Row) -> String) {
            self.title = title
            self.align = align
            self.value = value
        }
    }

    private let columns: [Column]
    private let rows: [Row]
    private let striped: Bool

    public init(columns: [Column], rows: [Row], striped: Bool = true) {
        self.columns = columns
        self.rows = rows
        self.striped = striped
    }

    public var body: some View {
        VStack(spacing: 0) {
            headerRow
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                dataRow(row, index: index)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(Theme.shared.border(.borderPrimary), lineWidth: 1))
    }

    private var headerRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                Text(column.title)
                    .textStyle(.labelSm700)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
                    .frame(maxWidth: .infinity, alignment: column.align.alignment)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(Theme.shared.background(.bgElevatorPrimary))
    }

    private func dataRow(_ row: Row, index: Int) -> some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                Text(column.value(row))
                    .textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textPrimary))
                    .frame(maxWidth: .infinity, alignment: column.align.alignment)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(striped && index % 2 == 1 ? Theme.shared.background(.bgElevatorPrimary).opacity(0.5) : Theme.shared.background(.bgWhite))
    }
}

#Preview {
    struct Booking: Identifiable { let id = UUID(); let hotel: String; let nights: Int; let price: String }
    let rows = [
        Booking(hotel: "Grand Hotel", nights: 3, price: "₺4.250"),
        Booking(hotel: "Sea Resort", nights: 5, price: "₺7.800"),
        Booking(hotel: "City Inn", nights: 2, price: "₺1.900"),
    ]
    return DataTable(columns: [
        .init("Hotel") { $0.hotel },
        .init("Nights", align: .center) { "\($0.nights)" },
        .init("Price", align: .trailing) { $0.price },
    ], rows: rows)
    .padding()
}
