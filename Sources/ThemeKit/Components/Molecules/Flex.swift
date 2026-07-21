//
//  Flex.swift
//  ThemeKit
//
//  Molecule. Ant Design's **Flex** — a flexbox container. Like ``Space`` it lays
//  children on one axis with a token gap, but it adds `justify` (main-axis
//  distribution: start / center / end / space-between / -around / -evenly) and
//  `align` (cross-axis) via a custom `Layout`, plus optional wrapping.
//
//      Flex { Button("Back"){}; Spacer(); Button("Next"){} }        // or:
//      Flex { Tag("A"); Tag("B"); Tag("C") }.justify(.spaceBetween)
//      Flex { avatar; name; badge }.align(.center).gap(.medium)
//
//  iOS 15.6-floor compat (ADR-0007 §D2 rule 1 — single-path): the former
//  custom `Layout` (iOS 16) is now a measured view — `_VariadicView` enumerates
//  the children, the shared probes in `MeasuredLayoutSupport` read the proposed
//  main-axis span and each child's ideal size, and the same justify/align math
//  the old `placeSubviews` used places the children with absolute offsets.
//  `.stretch` measures a hidden ideal-size copy of each child (the
//  ``AdaptiveFit`` probe technique) so the visible one can be re-proposed the
//  container's cross span. Until the first measurement lands (one layout pass)
//  the row renders hidden, so there is no transient overlap flash.
//

import SwiftUI

/// Main-axis distribution (Ant Flex `justify`).
public enum FlexJustify: Sendable { case start, center, end, spaceBetween, spaceAround, spaceEvenly }
/// Cross-axis alignment (Ant Flex `align`).
public enum FlexAlign: Sendable { case start, center, end, stretch, baseline }

public struct Flex<Content: View>: View {
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection

    private let content: Content
    // Appearance — mutated only through the modifiers below.
    private var axis: Axis = .horizontal
    private var spacing: CGFloat = Theme.SpacingKey.sm.value
    private var justify: FlexJustify = .start
    private var alignment: FlexAlign = .start
    private var wraps = false

    public init(@ViewBuilder content: () -> Content) { self.content = content() }

    public var body: some View {
        if wraps, axis == .horizontal {
            FlowLayout(spacing: spacing, lineSpacing: spacing, alignment: .leading, layoutDirection: layoutDirection) { content }
        } else {
            FlexLayout(axis: axis, gap: spacing, justify: justify, alignment: alignment, layoutDirection: layoutDirection) { content }
        }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension Flex {
    /// Layout direction (Ant Flex `vertical`). Default `.horizontal`.
    func direction(_ axis: Axis) -> Self { copy { $0.axis = axis } }
    /// Stack the children vertically.
    func vertical(_ on: Bool = true) -> Self { copy { $0.axis = on ? .vertical : .horizontal } }
    /// Gap from a preset size (small / medium / large).
    func gap(_ size: SpaceSize) -> Self { copy { $0.spacing = size.value } }
    /// Gap from a theme spacing token.
    func gap(_ key: Theme.SpacingKey) -> Self { copy { $0.spacing = key.value } }
    /// Gap from a raw point value.
    func gap(_ value: CGFloat) -> Self { copy { $0.spacing = max(0, value) } }
    /// Main-axis distribution (Ant Flex `justify`).
    func justify(_ justify: FlexJustify) -> Self { copy { $0.justify = justify } }
    /// Cross-axis alignment (Ant Flex `align`).
    func align(_ alignment: FlexAlign) -> Self { copy { $0.alignment = alignment } }
    /// Wrap onto multiple lines when horizontal (Ant Flex `wrap`).
    func wrap(_ on: Bool = true) -> Self { copy { $0.wraps = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Layout (measured — see the header note)

/// A single-line flex layout with main-axis distribution + cross-axis alignment.
struct FlexLayout<Content: View>: View {
    var axis: Axis
    var gap: CGFloat
    var justify: FlexJustify
    var alignment: FlexAlign
    /// Absolute placement doesn't auto-mirror — under `.rightToLeft` every
    /// subview's x is mirrored within the span (main axis when horizontal,
    /// cross axis when vertical).
    var layoutDirection: LayoutDirection = .leftToRight

    private let content: Content

    init(
        axis: Axis,
        gap: CGFloat,
        justify: FlexJustify,
        alignment: FlexAlign,
        layoutDirection: LayoutDirection = .leftToRight,
        @ViewBuilder content: () -> Content
    ) {
        self.axis = axis
        self.gap = gap
        self.justify = justify
        self.alignment = alignment
        self.layoutDirection = layoutDirection
        self.content = content()
    }

    var body: some View {
        _VariadicView.Tree(
            FlexRoot(axis: axis, gap: gap, justify: justify, alignment: alignment, layoutDirection: layoutDirection)
        ) { content }
    }
}

private struct FlexRoot: _VariadicView.UnaryViewRoot {
    let axis: Axis
    let gap: CGFloat
    let justify: FlexJustify
    let alignment: FlexAlign
    let layoutDirection: LayoutDirection

    func body(children: _VariadicView.Children) -> some View {
        FlexStack(
            children: children,
            axis: axis,
            gap: gap,
            justify: justify,
            alignment: alignment,
            layoutDirection: layoutDirection
        )
    }
}

private struct FlexStack: View {
    /// The placement ZStack runs forced-LTR so anchors and offsets are
    /// absolute; the real environment direction is restored on every child,
    /// and the packed positions mirror only via the `layoutDirection`
    /// parameter (the old `Layout` semantics — see ``FlowLayout``).
    @Environment(\.layoutDirection) private var envDirection

    let children: _VariadicView.Children
    let axis: Axis
    let gap: CGFloat
    let justify: FlexJustify
    let alignment: FlexAlign
    let layoutDirection: LayoutDirection

    /// Proposed main-axis span (width when horizontal, height when vertical).
    @State private var availableMain: CGFloat?
    @State private var sizes: [Int: CGSize] = [:]

    private var isMeasured: Bool {
        availableMain != nil && sizes.count == children.count
    }

    var body: some View {
        // Ideal sizes in child order (missing → .zero until measured).
        let ideals = (0..<children.count).map { sizes[$0] ?? .zero }
        let mainTotal = ideals.map(mainOf).reduce(0, +)
        // The old `sizeThatFits`: fill the proposed main so justify can
        // distribute; the container never shrinks below the content.
        let span = availableMain.map { max($0, mainTotal + gap * CGFloat(max(0, children.count - 1))) } ?? mainTotal
        let crossMax = ideals.map(crossOf).max() ?? 0
        let origins = ltrOrigins(ideals: ideals, span: span, crossMax: crossMax)
        Group {
            if axis == .horizontal {
                VStack(alignment: .leading, spacing: 0) {
                    MeasuredLayoutWidthProbe()
                    placedChildren(origins: origins, crossMax: crossMax)
                        .frame(maxWidth: .infinity, alignment: .topLeading)
                        .frame(height: isMeasured ? crossMax : nil, alignment: .top)
                        .opacity(isMeasured ? 1 : 0)
                        // Absolute placement, like the old `placeSubviews` —
                        // the hugged ZStack and its offsets must not re-mirror
                        // under an RTL environment (the frames above included).
                        .environment(\.layoutDirection, .leftToRight)
                }
            } else {
                HStack(alignment: .top, spacing: 0) {
                    MeasuredLayoutHeightProbe()
                    placedChildren(origins: origins, crossMax: crossMax)
                        .frame(maxHeight: .infinity, alignment: .topLeading)
                        .frame(width: isMeasured ? crossMax : nil, alignment: .leading)
                        .opacity(isMeasured ? 1 : 0)
                        // Same forced-LTR scope as the horizontal branch.
                        .environment(\.layoutDirection, .leftToRight)
                }
            }
        }
        .onPreferenceChange(MeasuredLayoutWidthKey.self) { width in
            if axis == .horizontal { availableMain = width }
        }
        .onPreferenceChange(MeasuredLayoutHeightKey.self) { height in
            if axis == .vertical { availableMain = height }
        }
        .onPreferenceChange(MeasuredLayoutChildSizesKey.self) { sizes = $0 }
        .consumesMeasuredLayoutPreferences()
    }

    private func placedChildren(origins: [Int: CGPoint], crossMax: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                placedChild(child, index: index)
                    .offset(offset(for: index, origins: origins, crossMax: crossMax))
            }
        }
    }

    /// Non-stretch children measure themselves at their ideal size (the old
    /// `sizeThatFits(.unspecified)`). `.stretch` needs the ideal size *and* a
    /// cross-span proposal on the same child, which one instance can't provide
    /// — so a hidden ideal-size copy measures (the ``AdaptiveFit`` probe
    /// technique) while the visible child is proposed the measured cross span.
    @ViewBuilder private func placedChild(_ child: _VariadicView.Children.Element, index: Int) -> some View {
        if alignment == .stretch {
            let crossSpan = isMeasured ? (0..<children.count).compactMap({ sizes[$0]?[keyPath: crossKeyPath] }).max() : nil
            child
                .environment(\.layoutDirection, envDirection)   // restore the real direction
                .fixedSize(horizontal: axis == .horizontal, vertical: axis == .vertical)
                .frame(
                    width: axis == .vertical ? crossSpan : nil,
                    height: axis == .horizontal ? crossSpan : nil
                )
                .background(
                    child
                        .environment(\.layoutDirection, envDirection)
                        .fixedSize()
                        .hidden()
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .measuredLayoutChild(index)
                )
        } else {
            child
                .environment(\.layoutDirection, envDirection)   // restore the real direction
                .fixedSize()
                .measuredLayoutChild(index)
        }
    }

    private var crossKeyPath: KeyPath<CGSize, CGFloat> {
        axis == .horizontal ? \.height : \.width
    }

    // MARK: Packing (same math as the former `Layout` implementation)

    /// Left-to-right/top-to-bottom origins per child; mirroring is applied in
    /// ``offset(for:origins:crossMax:)``.
    private func ltrOrigins(ideals: [CGSize], span: CGFloat, crossMax: CGFloat) -> [Int: CGPoint] {
        let n = children.count
        guard n > 0 else { return [:] }
        let mainTotal = ideals.map(mainOf).reduce(0, +)

        var leading: CGFloat = 0
        var inter: CGFloat = gap
        switch justify {
        case .start, .center, .end:
            let free = max(0, span - (mainTotal + gap * CGFloat(n - 1)))
            leading = justify == .center ? free / 2 : (justify == .end ? free : 0)
        case .spaceBetween:
            let free = max(0, span - mainTotal)
            inter = n > 1 ? free / CGFloat(n - 1) : 0
            leading = n > 1 ? 0 : free / 2
        case .spaceAround:
            let unit = max(0, span - mainTotal) / CGFloat(n)
            inter = unit; leading = unit / 2
        case .spaceEvenly:
            let unit = max(0, span - mainTotal) / CGFloat(n + 1)
            inter = unit; leading = unit
        }

        var origins: [Int: CGPoint] = [:]
        var mainPos = leading
        for index in 0..<n {
            let s = ideals[index]
            let crossPos: CGFloat
            switch alignment {
            case .start, .baseline, .stretch: crossPos = 0
            case .center: crossPos = max(0, (crossMax - crossOf(s)) / 2)
            case .end: crossPos = max(0, crossMax - crossOf(s))
            }
            origins[index] = axis == .horizontal
                ? CGPoint(x: mainPos, y: crossPos)
                : CGPoint(x: crossPos, y: mainPos)
            mainPos += mainOf(s) + inter
        }
        return origins
    }

    private func offset(for index: Int, origins: [Int: CGPoint], crossMax: CGFloat) -> CGSize {
        guard isMeasured, let origin = origins[index], let size = sizes[index] else { return .zero }
        // The placed width on screen: ideal, or the cross span when stretched
        // (vertical axis), or the main-axis ideal (horizontal).
        let placedWidth: CGFloat = axis == .horizontal
            ? size.width
            : (alignment == .stretch ? crossMax : size.width)
        // Width of the span the mirroring is relative to (the old `bounds`).
        let containerWidth: CGFloat = axis == .horizontal
            ? max(availableMain ?? 0, 0)
            : crossMax
        // Forced-LTR anchor at x0 — the offset IS the position, mirrored
        // within the span only via the `layoutDirection` parameter.
        let x: CGFloat = layoutDirection == .rightToLeft
            ? containerWidth - origin.x - placedWidth
            : origin.x
        return CGSize(width: x, height: origin.y)
    }

    private func mainOf(_ s: CGSize) -> CGFloat { axis == .horizontal ? s.width : s.height }
    private func crossOf(_ s: CGSize) -> CGFloat { axis == .horizontal ? s.height : s.width }
}

#Preview {
    PreviewMatrix("Flex") {
        PreviewCase("Space between") {
            Flex { ForEach(0..<3) { Tag("Tag \($0)") } }.justify(.spaceBetween).frame(width: 300)
        }
        PreviewCase("Centered") {
            Flex { ForEach(0..<3) { Tag("Tag \($0)") } }.justify(.center).frame(width: 300)
        }
        PreviewCase("Align center · large gap") {
            Flex { Text("A").frame(height: 40); Text("B").frame(height: 24); Text("C").frame(height: 32) }
                .align(.center).gap(.large).frame(width: 300)
        }
        PreviewCase("Wrapping") {
            Flex { ForEach(0..<8) { Tag("Tag \($0)") } }.wrap().frame(width: 300)
        }
    }
    .environment(\.theme, Theme.shared)
}

#Preview("RTL — first child starts at the trailing edge") {
    VStack(spacing: 20) {
        Flex { ForEach(0..<3) { Tag("Tag \($0)") } }.frame(width: 300)
        Flex { ForEach(0..<3) { Tag("Tag \($0)") } }.justify(.spaceBetween).frame(width: 300)
        Flex { ForEach(0..<3) { Tag("Tag \($0)") } }.justify(.end).frame(width: 300)
        Flex { Text("Start"); Text("End") }.vertical().align(.start).frame(width: 300)
    }
    .padding()
    .environment(\.layoutDirection, .rightToLeft)
    .environment(\.theme, Theme.shared)
}
