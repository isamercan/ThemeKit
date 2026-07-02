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

    // Appearance/config — mutated only through the modifiers below (R2).
    private var title: String? = nil
    private var bordered: Bool = false

    public init(rows: [Row]) {   // R1
        self.rows = rows
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
                if row.id != rows.last?.id { DividerView().size(.small) }
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension KeyValueTable {
    /// Heading rendered above the table.
    func title(_ text: String?) -> Self { copy { $0.title = text } }

    /// Wraps the table in a bordered, padded surface.
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    KeyValueTable(rows: [
        .init("Status", value: "Active", style: .success),
        .init("Old price", value: "$5,000", style: .strikethrough),
        .init("Total", value: "$4,250"),
        .init("Refund", value: "Cancelled", style: .error),
    ])
    .padding()
}
