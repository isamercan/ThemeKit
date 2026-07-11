//
//  KeyValueTable.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The `bordered` shell (surface fill, corner clipping, hairline border) is drawn
//  by the active `CardStyle` — `.surface(_:)` feeds its configuration. With
//  `bordered(false)` (the default) the table stays bare, with no shell at all;
//  the `title` is part of the content and always renders above the shell.
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
    @Environment(\.cardStyle) private var cardStyle

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
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite

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
                // The bordered shell is drawn by the active `CardStyle`; `.none`
                // elevation keeps the original hairline border and no shadow.
                cardStyle.makeBody(configuration: CardStyleConfiguration(
                    content: AnyView(table),
                    elevation: .none,
                    isSelected: false,
                    isPressed: false,
                    surfaceKey: surfaceKey,
                    radius: .field))
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

    /// Wraps the table in a bordered, padded surface (drawn by the active `CardStyle`).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }

    /// Surface fill for the bordered shell (background token key, default `.bgWhite`).
    /// Feeds the `CardStyle` configuration; ignored while `bordered` is off.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("KeyValueTable") {
        PreviewCase("Value styles (plain / success / strikethrough / error)") {
            KeyValueTable(rows: [
                .init("Status", value: "Active", style: .success),
                .init("Old price", value: "$5,000", style: .strikethrough),
                .init("Total", value: "$4,250"),
                .init("Refund", value: "Cancelled", style: .error),
            ])
        }
        PreviewCase("Bordered + outlined card style · title") {
            KeyValueTable(rows: [
                .init("Status", value: "Active", style: .success),
                .init("Total", value: "$4,250"),
            ])
            .title("Summary")
            .bordered()
            .cardStyle(.outlined)
        }
        PreviewCase("Bordered · muted value · custom surface") {
            KeyValueTable(rows: [
                .init("Reference", value: "BK-20931", style: .muted),
                .init("Total", value: "$4,250"),
            ])
            .bordered()
            .surface(.bgSecondaryLight)
        }
    }
}
