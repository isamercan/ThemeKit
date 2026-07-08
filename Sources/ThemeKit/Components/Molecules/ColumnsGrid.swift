//
//  ColumnsGrid.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Grid** (Row / Col) — an equal-column grid with a token
//  gutter. Either a fixed column count or a responsive `adaptive(minWidth:)` that
//  fits as many columns as the width allows. Named `ColumnsGrid` because SwiftUI
//  already owns `Grid`.
//
//      ColumnsGrid { ForEach(items) { Card($0) } }.columns(3).gutter(.md)
//      ColumnsGrid { ForEach(items) { Card($0) } }.adaptive(minWidth: 140)
//

import SwiftUI

public struct ColumnsGrid<Content: View>: View {
    private let content: Content
    // Appearance — mutated only through the modifiers below.
    private var columnCount = 2
    private var minItemWidth: CGFloat?
    private var gutter: CGFloat = Theme.SpacingKey.sm.value

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        LazyVGrid(columns: gridColumns, spacing: gutter) { content }
    }

    private var gridColumns: [GridItem] {
        if let minItemWidth {
            return [GridItem(.adaptive(minimum: minItemWidth), spacing: gutter)]
        }
        return Array(repeating: GridItem(.flexible(), spacing: gutter), count: max(1, columnCount))
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension ColumnsGrid {
    /// Fixed number of equal columns.
    func columns(_ count: Int) -> Self { copy { $0.columnCount = Swift.max(1, count); $0.minItemWidth = nil } }
    /// Fit as many columns as the width allows, each at least `minWidth` wide (Ant responsive Col).
    func adaptive(minWidth: CGFloat) -> Self { copy { $0.minItemWidth = Swift.max(1, minWidth) } }
    /// Gap between cells, from a preset size (Ant Row `gutter`).
    func gutter(_ size: SpaceSize) -> Self { copy { $0.gutter = size.value } }
    /// Gap between cells, from a raw point value.
    func gutter(_ value: CGFloat) -> Self { copy { $0.gutter = Swift.max(0, value) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    ScrollView {
        ColumnsGrid {
            ForEach(0..<9) { i in
                RoundedRectangle(cornerRadius: 12)
                    .fill(SemanticColor.primary.soft)
                    .frame(height: 64)
                    .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textHero)))
            }
        }
        .columns(3)
        .gutter(.medium)
        .padding()
    }
    .environment(Theme.shared)
}
