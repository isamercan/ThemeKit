//
//  FlowLayout.swift
//  ThemeKit
//
//  A line-wrapping layout: places subviews left→right at their ideal size and wraps
//  to a new line when the next one won't fit the available width. A drop-in for an
//  `HStack` that should wrap to the next line instead of squeezing its children.
//  Reusable for any run of self-sizing views — buttons, chips, tags…
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): the `Layout`
//  protocol is iOS 16, so the flow is a measured *view* — `_VariadicView`
//  enumerates the children (the ``ButtonGroup`` precedent), the shared probes in
//  `MeasuredLayoutSupport` read the proposed width and each child's ideal size,
//  and the exact row-packing math the old `Layout.placeSubviews` used places
//  the children with absolute offsets. Call sites are source-compatible
//  (`FlowLayout(spacing:) { … }` — the trailing closure is now a `@ViewBuilder`
//  init parameter instead of `Layout.callAsFunction`); the dropped public
//  `Layout` conformance is the allowlisted API change (plan §3a, ADR-0007 §D4).
//
//  Deliberate divergences from the `Layout` implementation (snapshot-visible
//  only outside full-width leading-aligned contexts; Phase-4 re-record):
//  1. The view spans the proposed width instead of hugging its rows — reading
//     the proposal pre-16 requires occupying it (the same trade ``AdaptiveFit``
//     documents). Row `alignment` still positions each row within that span.
//  2. Until the first measurement lands (one layout pass, and again for one
//     pass when the child count changes) the rows render hidden, so there is
//     no transient overlap flash.
//

import SwiftUI

public struct FlowLayout<Content: View>: View {
    public var spacing: CGFloat
    public var lineSpacing: CGFloat
    public var alignment: HorizontalAlignment
    /// Absolute placement doesn't auto-mirror — under `.rightToLeft` each
    /// subview's x is mirrored within the span so the first item of every line
    /// starts at the trailing edge. Containers read `@Environment(\.layoutDirection)`
    /// and hand it in (see ``Flex``/``Space``).
    public var layoutDirection: LayoutDirection = .leftToRight

    private let content: Content

    public init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.content = content()
    }

    /// RTL-aware overload — containers read `@Environment(\.layoutDirection)`
    /// and pass it so absolute placement mirrors under right-to-left. Kept
    /// separate from the base init (with `layoutDirection` **required**) so the
    /// original signature stays source-stable.
    public init(
        spacing: CGFloat = 8,
        lineSpacing: CGFloat = 8,
        alignment: HorizontalAlignment = .leading,
        layoutDirection: LayoutDirection,
        @ViewBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.alignment = alignment
        self.layoutDirection = layoutDirection
        self.content = content()
    }

    public var body: some View {
        _VariadicView.Tree(
            FlowRoot(
                spacing: spacing,
                lineSpacing: lineSpacing,
                alignment: alignment,
                layoutDirection: layoutDirection
            )
        ) { content }
    }
}

// MARK: - Variadic root

private struct FlowRoot: _VariadicView.UnaryViewRoot {
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let alignment: HorizontalAlignment
    let layoutDirection: LayoutDirection

    func body(children: _VariadicView.Children) -> some View {
        FlowStack(
            children: children,
            spacing: spacing,
            lineSpacing: lineSpacing,
            alignment: alignment,
            layoutDirection: layoutDirection
        )
    }
}

// MARK: - Measured flow

private struct FlowStack: View {
    /// The placement ZStack runs forced-LTR so anchors and offsets are
    /// absolute (like the old `Layout` bounds math); the real environment
    /// direction is restored on every child, and the packed positions mirror
    /// only when a container passes `layoutDirection: .rightToLeft` in — the
    /// old `Layout` semantics exactly.
    @Environment(\.layoutDirection) private var envDirection

    let children: _VariadicView.Children
    let spacing: CGFloat
    let lineSpacing: CGFloat
    let alignment: HorizontalAlignment
    let layoutDirection: LayoutDirection

    @State private var availableWidth: CGFloat?
    @State private var sizes: [Int: CGSize] = [:]

    private var isMeasured: Bool {
        availableWidth != nil && sizes.count == children.count
    }

    var body: some View {
        let width = availableWidth ?? .infinity
        let rows = packedRows(maxWidth: width)
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(0, rows.count - 1))
        let frames = ltrFrames(rows: rows, containerWidth: width)
        VStack(alignment: .leading, spacing: 0) {
            MeasuredLayoutWidthProbe()
            ZStack(alignment: .topLeading) {
                ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                    child
                        .environment(\.layoutDirection, envDirection)   // restore the real direction
                        .fixedSize()   // ideal size, like the old `sizeThatFits(.unspecified)`
                        .measuredLayoutChild(index)
                        .offset(offset(for: index, frames: frames, containerWidth: width))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .frame(height: isMeasured ? height : nil, alignment: .top)
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

    private func packedRows(maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in 0..<children.count {
            let size = sizes[index] ?? .zero
            if !current.items.isEmpty, current.width + spacing + size.width > maxWidth {
                rows.append(current)
                current = Row()
            }
            current.append(index: index, size: size, spacing: spacing)
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }

    /// Left-to-right frames within the span; mirroring is applied in
    /// ``offset(for:frames:containerWidth:)``, exactly like the old
    /// `placeSubviews`.
    private func ltrFrames(rows: [Row], containerWidth: CGFloat) -> [Int: CGRect] {
        let width = containerWidth.isFinite ? containerWidth : rows.map(\.width).max() ?? 0
        var frames: [Int: CGRect] = [:]
        var y: CGFloat = 0
        for row in rows {
            var x: CGFloat
            switch alignment {
            case .center: x = (width - row.width) / 2
            case .trailing: x = width - row.width
            default: x = 0
            }
            for item in row.items {
                frames[item.index] = CGRect(
                    x: x,
                    y: y + (row.height - item.size.height) / 2,
                    width: item.size.width,
                    height: item.size.height
                )
                x += item.size.width + spacing
            }
            y += row.height + lineSpacing
        }
        return frames
    }

    private func offset(for index: Int, frames: [Int: CGRect], containerWidth: CGFloat) -> CGSize {
        guard isMeasured, containerWidth.isFinite, let frame = frames[index] else { return .zero }
        // The forced-LTR ZStack anchors every child at x0 — the offset IS the
        // position, mirrored within the span only when the container passed
        // `.rightToLeft` in (the old `placeSubviews` math).
        let x: CGFloat = layoutDirection == .rightToLeft
            ? containerWidth - frame.minX - frame.width
            : frame.minX
        return CGSize(width: x, height: frame.minY)
    }
}
