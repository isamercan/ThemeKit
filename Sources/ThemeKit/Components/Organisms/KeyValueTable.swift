//
//  KeyValueTable.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum TableValueStyle {
    case plain, success, error, muted, strikethrough

    func color(_ theme: Theme) -> Color {
        switch self {
        case .plain: return theme.text(.textPrimary)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .error: return theme.foreground(.systemcolorsFgError)
        case .muted, .strikethrough: return theme.text(.textTertiary)
        }
    }
}

/// Organism. A label/value table (Figma "Table"). Values can carry a status
/// style (plain / success / error / muted / strikethrough).
public struct KeyValueTable: View {
    @Environment(\.theme) private var theme

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
    private let title: String?
    private let bordered: Bool

    public init(rows: [Row], title: String? = nil, bordered: Bool = false) {
        self.rows = rows
        self.title = title
        self.bordered = bordered
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            if let title {
                Text(title)
                    .textStyle(.labelLg600)
                    .foregroundStyle(theme.text(.textPrimary))
            }
            if bordered {
                table
                    .background(theme.background(.bgWhite),
                                in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                            .strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
                    )
            } else {
                table
            }
        }
    }

    private var table: some View {
        VStack(spacing: 0) {
            ForEach(rows) { row in
                HStack {
                    Text(row.label)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                    Spacer(minLength: Theme.SpacingKey.md.value)
                    Text(row.value)
                        .textStyle(.labelBase600)
                        .foregroundStyle(row.style.color(theme))
                        .strikethrough(row.style == .strikethrough)
                        .multilineTextAlignment(.trailing)
                }
                .padding(.vertical, Theme.SpacingKey.sm.value)
                .padding(.horizontal, bordered ? Theme.SpacingKey.md.value : 0)
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
