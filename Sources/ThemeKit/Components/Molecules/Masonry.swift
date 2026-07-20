//
//  Masonry.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Masonry** — a Pinterest-style grid where variable-
//  height items flow into a fixed number of columns, each new item dropping into
//  the currently shortest column (so columns stay balanced).
//
//      Masonry { ForEach(photos) { PhotoCard($0) } }.columns(2).spacing(.sm)
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): the former
//  custom `Layout` (iOS 16) is now a measured view — `_VariadicView` enumerates
//  the children, the shared probes in `MeasuredLayoutSupport` read the proposed
//  width and each child's height at column width, and the same
//  shortest-column math the old `placeSubviews` used places the children with
//  absolute offsets. Until the first measurement lands (one layout pass) the
//  grid renders hidden, so there is no transient overlap flash.
//

import SwiftUI

public struct Masonry<Content: View>: View {
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection

    private let content: Content
    // Appearance — mutated only through the modifiers below.
    private var columnCount = 2
    private var spacing: CGFloat = Theme.SpacingKey.sm.value

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        MasonryLayout(columns: max(1, columnCount), spacing: spacing, layoutDirection: layoutDirection) { content }
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

// MARK: - Layout (measured — see the header note)

struct MasonryLayout<Content: View>: View {
    var columns: Int
    var spacing: CGFloat
    /// Absolute placement doesn't auto-mirror — under `.rightToLeft` each
    /// column's x is mirrored within the span so column 0 (the first fill
    /// target) starts at the trailing edge.
    var layoutDirection: LayoutDirection = .leftToRight

    private let content: Content

    init(
        columns: Int,
        spacing: CGFloat,
        layoutDirection: LayoutDirection = .leftToRight,
        @ViewBuilder content: () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.layoutDirection = layoutDirection
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(
            MasonryRoot(columns: columns, spacing: spacing, layoutDirection: layoutDirection)
        ) { content }
    }
}

private struct MasonryRoot: _VariadicView.UnaryViewRoot {
    let columns: Int
    let spacing: CGFloat
    let layoutDirection: LayoutDirection

    func body(children: _VariadicView.Children) -> some View {
        MasonryStack(
            children: children,
            columns: columns,
            spacing: spacing,
            layoutDirection: layoutDirection
        )
    }
}

private struct MasonryStack: View {
    /// The placement ZStack runs forced-LTR so anchors and offsets are
    /// absolute; the real environment direction is restored on every child,
    /// and the packed positions mirror only via the `layoutDirection`
    /// parameter (the old `Layout` semantics — see ``FlowLayout``).
    @Environment(\.layoutDirection) private var envDirection

    let children: _VariadicView.Children
    let columns: Int
    let spacing: CGFloat
    let layoutDirection: LayoutDirection

    @State private var availableWidth: CGFloat?
    @State private var sizes: [Int: CGSize] = [:]

    private var isMeasured: Bool {
        availableWidth != nil && sizes.count == children.count
    }

    var body: some View {
        // Same fallback the old `sizeThatFits` used for a `nil` width proposal.
        let width = availableWidth ?? 320
        let colW = columnWidth(width)
        let placement = ltrPlacement(columnWidth: colW)
        VStack(alignment: .leading, spacing: 0) {
            MeasuredLayoutWidthProbe()
            ZStack(alignment: .topLeading) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    child
                        .environment(\.layoutDirection, envDirection)   // restore the real direction
                        .frame(width: colW)   // the old per-column width proposal
                        .measuredLayoutChild(index)
                        .offset(offset(for: index, placement: placement, columnWidth: colW, containerWidth: width))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: isMeasured ? placement.height : nil, alignment: .top)
            .opacity(isMeasured ? 1 : 0)
            // Absolute placement, like the old `placeSubviews` — anchors and
            // offsets must not re-mirror under an RTL environment.
            .environment(\.layoutDirection, .leftToRight)
        }
        .onPreferenceChange(MeasuredLayoutWidthKey.self) { availableWidth = $0 }
        .onPreferenceChange(MeasuredLayoutChildSizesKey.self) { sizes = $0 }
        .consumesMeasuredLayoutPreferences()
    }

    // MARK: Packing (same math as the former `Layout` implementation)

    private func columnWidth(_ totalWidth: CGFloat) -> CGFloat {
        max(0, (totalWidth - spacing * CGFloat(columns - 1)) / CGFloat(columns))
    }

    /// Left-to-right origins per child (shortest column wins) + total height.
    private func ltrPlacement(columnWidth colW: CGFloat) -> (origins: [Int: CGPoint], height: CGFloat) {
        var heights = Array(repeating: CGFloat(0), count: columns)
        var origins: [Int: CGPoint] = [:]
        for index in 0..<children.count {
            let h = sizes[index]?.height ?? 0
            let col = shortest(heights)
            origins[index] = CGPoint(x: CGFloat(col) * (colW + spacing), y: heights[col])
            heights[col] += h + spacing
        }
        return (origins, (heights.max() ?? spacing) - spacing)
    }

    private func shortest(_ heights: [CGFloat]) -> Int {
        var idx = 0
        for i in heights.indices where heights[i] < heights[idx] { idx = i }
        return idx
    }

    private func offset(
        for index: Int,
        placement: (origins: [Int: CGPoint], height: CGFloat),
        columnWidth colW: CGFloat,
        containerWidth: CGFloat
    ) -> CGSize {
        guard isMeasured, let origin = placement.origins[index] else { return .zero }
        // Forced-LTR anchor at x0 — the offset IS the position, mirrored
        // within the span only via the `layoutDirection` parameter.
        let x: CGFloat = layoutDirection == .rightToLeft
            ? containerWidth - origin.x - colW
            : origin.x
        return CGSize(width: x, height: origin.y)
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            let heights: [CGFloat] = [90, 140, 70, 120, 100, 160, 80, 110]
            PreviewMatrix("Masonry") {
                PreviewCase("3 columns") {
                    Masonry {
                        ForEach(Array(heights.enumerated()), id: \.offset) { i, h in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SemanticColor.primary.soft)
                                .frame(height: h)
                                .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textHero)))
                        }
                    }
                    .columns(3)
                }
                PreviewCase("2 columns (default)") {
                    Masonry {
                        ForEach(Array(heights.prefix(5).enumerated()), id: \.offset) { i, h in
                            RoundedRectangle(cornerRadius: 12)
                                .fill(SemanticColor.primary.soft)
                                .frame(height: h)
                                .overlay(Text("\(i)").textStyle(.labelBase700).foregroundStyle(theme.text(.textHero)))
                        }
                    }
                }
            }
            .environment(\.theme, Theme.shared)
        }
    }
    return Demo()
}

#Preview("RTL — columns fill from the trailing edge") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
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
            .environment(\.layoutDirection, .rightToLeft)
            .environment(\.theme, Theme.shared)
        }
    }
    return Demo()
}
