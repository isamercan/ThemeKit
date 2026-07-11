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
            FlowLayout(spacing: spacing, lineSpacing: spacing, alignment: .leading) { content }
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

// MARK: - Layout

/// A single-line flex layout with main-axis distribution + cross-axis alignment.
struct FlexLayout: Layout {
    var axis: Axis
    var gap: CGFloat
    var justify: FlexJustify
    var alignment: FlexAlign
    /// Absolute placement doesn't auto-mirror — under `.rightToLeft` every
    /// subview's x is mirrored within `bounds` (main axis when horizontal,
    /// cross axis when vertical).
    var layoutDirection: LayoutDirection = .leftToRight

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let mainTotal = sizes.map(mainOf).reduce(0, +) + gap * CGFloat(max(0, subviews.count - 1))
        let crossMax = sizes.map(crossOf).max() ?? 0
        let proposedMain = axis == .horizontal ? proposal.width : proposal.height
        // Fill the proposed main so justify can distribute; else hug the content.
        return size(main: proposedMain.map { max($0, mainTotal) } ?? mainTotal, cross: crossMax)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let n = subviews.count
        guard n > 0 else { return }
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let containerMain = axis == .horizontal ? bounds.width : bounds.height
        let containerCross = axis == .horizontal ? bounds.height : bounds.width
        let mainTotal = sizes.map(mainOf).reduce(0, +)

        var leading: CGFloat = 0
        var inter: CGFloat = gap
        switch justify {
        case .start, .center, .end:
            let free = max(0, containerMain - (mainTotal + gap * CGFloat(n - 1)))
            leading = justify == .center ? free / 2 : (justify == .end ? free : 0)
        case .spaceBetween:
            let free = max(0, containerMain - mainTotal)
            inter = n > 1 ? free / CGFloat(n - 1) : 0
            leading = n > 1 ? 0 : free / 2
        case .spaceAround:
            let unit = max(0, containerMain - mainTotal) / CGFloat(n)
            inter = unit; leading = unit / 2
        case .spaceEvenly:
            let unit = max(0, containerMain - mainTotal) / CGFloat(n + 1)
            inter = unit; leading = unit
        }

        var mainPos = (axis == .horizontal ? bounds.minX : bounds.minY) + leading
        for (i, sub) in subviews.enumerated() {
            let s = sizes[i]
            let crossPos: CGFloat
            switch alignment {
            case .start, .baseline, .stretch: crossPos = 0
            case .center: crossPos = max(0, (containerCross - crossOf(s)) / 2)
            case .end: crossPos = max(0, containerCross - crossOf(s))
            }
            let crossOrigin = (axis == .horizontal ? bounds.minY : bounds.minX) + crossPos
            let place: ProposedViewSize = alignment == .stretch
                ? (axis == .horizontal ? ProposedViewSize(width: mainOf(s), height: containerCross)
                                       : ProposedViewSize(width: containerCross, height: mainOf(s)))
                : ProposedViewSize(width: s.width, height: s.height)
            var origin = axis == .horizontal ? CGPoint(x: mainPos, y: crossOrigin) : CGPoint(x: crossOrigin, y: mainPos)
            if layoutDirection == .rightToLeft {
                let placedWidth = axis == .horizontal
                    ? mainOf(s)
                    : (alignment == .stretch ? containerCross : s.width)
                origin.x = bounds.maxX - (origin.x - bounds.minX) - placedWidth
            }
            sub.place(at: origin, proposal: place)
            mainPos += mainOf(s) + inter
        }
    }

    private func mainOf(_ s: CGSize) -> CGFloat { axis == .horizontal ? s.width : s.height }
    private func crossOf(_ s: CGSize) -> CGFloat { axis == .horizontal ? s.height : s.width }
    private func size(main: CGFloat, cross: CGFloat) -> CGSize {
        axis == .horizontal ? CGSize(width: main, height: cross) : CGSize(width: cross, height: main)
    }
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
    .environment(Theme.shared)
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
    .environment(Theme.shared)
}
