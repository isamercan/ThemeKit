//
//  Masonry.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Masonry** — a Pinterest-style grid where variable-
//  height items flow into a fixed number of columns, each new item dropping into
//  the currently shortest column (so columns stay balanced). Built on a custom
//  `Layout`.
//
//      Masonry { ForEach(photos) { PhotoCard($0) } }.columns(2).spacing(.sm)
//

import SwiftUI

public struct Masonry<Content: View>: View {
    private let content: Content
    // Appearance — mutated only through the modifiers below.
    private var columnCount = 2
    private var spacing: CGFloat = Theme.SpacingKey.sm.value

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        MasonryLayout(columns: max(1, columnCount), spacing: spacing) { content }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Masonry {
    /// Number of columns.
    func columns(_ count: Int) -> Self { copy { $0.columnCount = Swift.max(1, count) } }
    /// Gap between items, from a preset size.
    func spacing(_ size: SpaceSize) -> Self { copy { $0.spacing = size.value } }
    /// Gap between items, from a raw point value.
    func spacing(_ value: CGFloat) -> Self { copy { $0.spacing = Swift.max(0, value) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Layout

struct MasonryLayout: Layout {
    var columns: Int
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 320
        let heights = columnHeights(subviews: subviews, columnWidth: columnWidth(width))
        return CGSize(width: width, height: (heights.max() ?? spacing) - spacing)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let colW = columnWidth(bounds.width)
        var heights = Array(repeating: CGFloat(0), count: columns)
        for sub in subviews {
            let h = sub.sizeThatFits(ProposedViewSize(width: colW, height: nil)).height
            let col = shortest(heights)
            let x = bounds.minX + CGFloat(col) * (colW + spacing)
            let y = bounds.minY + heights[col]
            sub.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(width: colW, height: h))
            heights[col] += h + spacing
        }
    }

    private func columnWidth(_ totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    private func columnHeights(subviews: Subviews, columnWidth colW: CGFloat) -> [CGFloat] {
        var heights = Array(repeating: CGFloat(0), count: columns)
        for sub in subviews {
            let h = sub.sizeThatFits(ProposedViewSize(width: colW, height: nil)).height
            heights[shortest(heights)] += h + spacing
        }
        return heights
    }

    private func shortest(_ heights: [CGFloat]) -> Int {
        var idx = 0
        for i in heights.indices where heights[i] < heights[idx] { idx = i }
        return idx
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    let heights: [CGFloat] = [90, 140, 70, 120, 100, 160, 80, 110]
    ScrollView {
        Masonry {
            ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                RoundedRectangle(cornerRadius: 12)
                    .fill(SemanticColor.primary.soft)
                    .frame(height: h)
                    .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textHero)))
            }
        }
        .columns(3)
        .padding()
    }
    .environment(Theme.shared)
}
