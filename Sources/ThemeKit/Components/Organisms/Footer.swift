//
//  Footer.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A page footer: columns of titled links + an optional bottom note.
/// (daisyUI "Footer".)
public struct Footer: View {
    @Environment(\.theme) private var theme

    public struct Item: Identifiable {
        public let id = UUID()
        let title: String
        let action: () -> Void
        public init(_ title: String, action: @escaping () -> Void = {}) { self.title = title; self.action = action }
    }
    public struct Column: Identifiable {
        public let id = UUID()
        let title: String
        let items: [Item]
        public init(_ title: String, items: [Item]) { self.title = title; self.items = items }
    }

    private let columns: [Column]
    private let note: String?
    // Appearance — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite

    public init(columns: [Column], note: String? = nil) {
        self.columns = columns
        self.note = note
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.lg.value) {
            HStack(alignment: .top, spacing: Theme.SpacingKey.lg.value) {
                ForEach(columns) { column in
                    VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                        Text(column.title.uppercased())
                            .textStyle(.overline500)
                            .foregroundStyle(theme.text(.textTertiary))
                        ForEach(column.items) { item in
                            TextLink(item.title, action: item.action).underline(false)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let note {
                DividerView().size(.small)
                Text(note)
                    .textStyle(.bodySm400)
                    .foregroundStyle(theme.text(.textTertiary))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(theme.background(surfaceKey))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Footer {
    /// Surface fill (background token key, default `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    Footer(columns: [
        .init("Company", items: [.init("About"), .init("Careers"), .init("Press")]),
        .init("Support", items: [.init("Help center"), .init("Contact"), .init("FAQ")]),
        .init("Legal", items: [.init("Terms"), .init("Privacy")]),
    ], note: "© 2026 ThemeKit. All rights reserved.")
    .padding()
}
