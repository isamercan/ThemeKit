//
//  KeyValueTable.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A label/value table (Figma "Table"). Values can carry a status
//  style (plain / success / error / muted / strikethrough).
//

import SwiftUI

public enum TableValueStyle {
    case plain, success, error, muted, strikethrough

    var color: Color {
        switch self {
        case .plain: return Theme.shared.text(.textPrimary)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        case .muted, .strikethrough: return Theme.shared.text(.textTertiary)
        }
    }
}

public struct KeyValueTable: View {
    public struct Row: Identifiable {
        public let id = UUID()
        let label: String
        let value: String
        let style: TableValueStyle
        public init(_ label: String, value: String, style: TableValueStyle = .plain) {
            self.label = label
            self.value = value
            self.style = style
        }
    }

    private let rows: [Row]

    public init(rows: [Row]) {
        self.rows = rows
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                    Spacer(minLength: Theme.SpacingKey.md.value)
                    Text(row.value)
                        .textStyle(.labelBase600)
                        .foregroundStyle(row.style.color)
                        .strikethrough(row.style == .strikethrough)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, Theme.SpacingKey.sm.value)
                if row.id != rows.last?.id { DividerView(size: .small) }
            }
        }
    }
}

#Preview {
    KeyValueTable(rows: [
        .init("Status", value: "Aktif", style: .success),
        .init("Old price", value: "5.000 TL", style: .strikethrough),
        .init("Total", value: "4.250 TL"),
        .init("Refund", value: "İptal Edildi", style: .error),
    ])
    .padding()
}
