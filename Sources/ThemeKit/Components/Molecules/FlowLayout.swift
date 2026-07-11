//
//  FlowLayout.swift
//  ThemeKit
//
//  A line-wrapping layout: places subviews left→right at their ideal size and wraps
//  to a new line when the next one won't fit the proposed width. It hugs its content
//  when everything fits, so it's a drop-in for an `HStack` that should wrap to the
//  next line instead of squeezing its children. Reusable for any run of self-sizing
//  views — buttons, chips, tags…
//

import SwiftUI

public struct FlowLayout: Layout {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment
    /// Absolute placement doesn't auto-mirror — under `.rightToLeft` each
    /// subview's x is mirrored within `bounds` so the first item of every line
    /// starts at the trailing edge. Containers read `@Environment(\.layoutDirection)`
    /// and hand it in (see ``Flex``/``Space``).
    public var layoutDirection: LayoutDirection = .leftToRight

    public init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
    }

    /// RTL-aware overload — containers read `@Environment(\.layoutDirection)`
    /// and pass it so absolute placement mirrors under right-to-left. Kept
    /// separate from the base init (with `layoutDirection` **required**) so the
    /// original signature stays source- and ABI-stable.
    public init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading,
        layoutDirection: LayoutDirection
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.layoutDirection = layoutDirection
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        let rows = rows(maxWidth: maxWidth, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        // Hug content when it fits; only fill out to the proposed width once wrapped.
        return CGSize(width: maxWidth.isFinite ? min(width, maxWidth) : width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout Void) {
        let rows = rows(maxWidth: bounds.width, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center: x = bounds.minX + (bounds.width - row.width) / 2
            case .trailing: x = bounds.maxX - row.width
            default: x = bounds.minX
            }
            for item in row.items {
                var origin = CGPoint(x: x, y: y + (row.height - item.size.height) / 2)
                if layoutDirection == .rightToLeft {
                    origin.x = bounds.maxX - (origin.x - bounds.minX) - item.size.width
                }
                subviews[item.index].place(at: origin, proposal: ProposedViewSize(item.size))
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.append(index: index, size: size, spacing: spacing)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }

    private struct Row {
        var items: [(index: Int, size: CGSize)] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
        mutating func append(index: Int, size: CGSize, spacing: CGFloat) {
            if !items.isEmpty { width += spacing }
            items.append((index, size))
            width += size.width
            height = max(height, size.height)
        }
    }
}
