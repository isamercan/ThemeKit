//
//  Footer.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A page footer: columns of titled links + an optional bottom note.
//  (daisyUI "Footer".)
//

import SwiftUI

public struct Footer: View {
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
                            .foregroundStyle(Theme.shared.text(.textTertiary))
                        ForEach(column.items) { item in
                            TextLink(item.title, underline: false, action: item.action)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let note {
                DividerView(size: .small)
                Text(note)
                    .textStyle(.bodySm400)
                    .foregroundStyle(Theme.shared.text(.textTertiary))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.shared.background(.bgElevatorPrimary))
    }
}

#Preview {
    Footer(columns: [
        .init("Company", items: [.init("About"), .init("Careers"), .init("Press")]),
        .init("Support", items: [.init("Help center"), .init("Contact"), .init("FAQ")]),
        .init("Legal", items: [.init("Terms"), .init("Privacy")]),
    ], note: "© 2026 GlobalUIComponents. All rights reserved.")
    .padding()
}
