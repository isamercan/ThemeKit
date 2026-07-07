//
//  Footer.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A page footer: columns of titled links + an optional bottom note.
/// (daisyUI "Footer".)
///
/// Chrome is drawn by the ambient ``BarStyle`` (`.barStyle(_:)`): the whole
/// column grid is the `.bottom`-edge configuration's content (a footer has no
/// leading/trailing accessories) with the hairline suppressed — so the default
/// style reproduces the original flat fill pixel-identically. `surface(_:)`
/// still wins over the fill the style would draw.
public struct Footer: View {
    @Environment(\.theme) private var theme
    @Environment(\.barStyle) private var barStyle

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
    /// `nil` = the active `BarStyle` picks its own fill (the default style uses
    /// `.bgWhite`, the original footer surface); set via `surface(_:)`.
    private var surfaceOverride: Theme.BackgroundColorKey?

    public init(columns: [Column], note: String? = nil) {
        self.columns = columns
        self.note = note
    }

    public var body: some View {
        // A footer never draws a hairline (its divider is content, above the
        // note), so the hairline the style would add is suppressed; a set
        // `surface(_:)` beats the style's fill (same rule as SheetHeader).
        barStyle.makeBody(configuration: BarStyleConfiguration(leading: nil,
                                                               content: AnyView(contentStack),
                                                               trailing: nil,
                                                               edge: .bottom))
            .environment(\.barChromeOverrides,
                         BarChromeOverrides(surface: surfaceOverride,
                                            showsHairline: false))
    }

    private var contentStack: some View {
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
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Footer {
    /// Surface fill (background token key). Wins over the fill the active
    /// `BarStyle` would draw; when unset, the style picks its own (the default
    /// style uses `.bgWhite`, the original footer surface).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceOverride = key } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    let columns: [Footer.Column] = [
        .init("Company", items: [.init("About"), .init("Careers"), .init("Press")]),
        .init("Support", items: [.init("Help center"), .init("Contact"), .init("FAQ")]),
        .init("Legal", items: [.init("Terms"), .init("Privacy")]),
    ]
    return VStack(spacing: 24) {
        Footer(columns: columns, note: "© 2026 ThemeKit. All rights reserved.")
        Footer(columns: columns, note: "© 2026 ThemeKit. All rights reserved.")
            .barStyle(.floating)
    }
    .padding()
}
