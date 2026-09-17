//
//  TooltipStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  `.tooltip` + `TooltipStyle`: the built-in bubble still draws the 1.5.0
//  pixels (the arrow is now the public `TooltipArrowShape`), the stock style
//  draws the same pixels as the built-in bubble (every edge, both layout
//  directions, plain and rich), only the environment default is marked, and
//  the arrow shape the configuration carries is turned for RTL.
//

import XCTest
import SwiftUI
@_spi(ThemeKitInternal) import ThemeKitCore   // ColorContrast, for the 1.5.0 recipe
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class TooltipStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(stage(anchor.tooltip("Hint", isPresented: .constant(true)))), "plain")
        XCTAssertNotNil(render(stage(anchor.tooltip(isPresented: .constant(true)) { Text("Rich") })), "rich")
        XCTAssertNotNil(render(stage(anchor.tooltip("Hint"))), "self-managed, hidden")
    }

    /// The built-in path draws the 1.5.0 bubble, pixel for pixel: the arrow type
    /// became public (and pinned its layout-direction behaviour). Its placement is
    /// the 1.6.0 fix — beside the anchor (`TooltipPlacementTests`) — so the recipe
    /// places 1.5.0's bubble with the fixed placement.
    func testBuiltInTooltipDrawsThe150Pixels() {
        let cases: [RecipeCase] = [
            RecipeCase(label: "top", edge: .top),
            RecipeCase(label: "bottom info", edge: .bottom, style: .info),
            RecipeCase(label: "leading warning", edge: .leading, align: .start, style: .warning),
            RecipeCase(label: "trailing primary", edge: .trailing, align: .end, color: .primary),
            RecipeCase(label: "wrapping", edge: .bottom, align: .start, maxWidth: 140),
        ]
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for recipeCase in cases {
                let (label, edge, align) = (recipeCase.label, recipeCase.edge, recipeCase.align)
                let (style, color, maxWidth) = (recipeCase.style, recipeCase.color, recipeCase.maxWidth)
                let text = "A hint on the \(label) side"
                let current = stage(anchor.tooltip(text, isPresented: .constant(true), edge: edge, align: align,
                                                   style: style, color: color, maxWidth: maxWidth))
                    .environment(\.layoutDirection, direction)
                func recipe(opacity: Double) -> some View {
                    stage(anchor.overlay(alignment: edge.alignment(align)) {
                        V150Bubble(text: text, edge: edge, style: style, color: color, maxWidth: maxWidth)
                            .opacity(opacity)
                            .fixedSize(horizontal: maxWidth == nil, vertical: true)
                            .modifier(FixedPlacement(edge: edge))
                            .zIndex(1)
                    })
                    .environment(\.layoutDirection, direction)
                }
                XCTAssertLessThanOrEqual(pixelDelta(current, recipe(opacity: 1)) ?? .max, pixelNoise, "\(label) \(direction)")
                // Control, same case: the recipe at half opacity must be caught.
                XCTAssertGreaterThan(pixelDelta(current, recipe(opacity: 0.5)) ?? 0, pixelNoise,
                                     "\(label) \(direction) (control): the comparison saw no difference")
            }
        }
    }

    /// The popconfirm / popover cards draw the same arrow, filled and
    /// hairline-stroked, flipped under RTL: unchanged from 1.5.0.
    func testCardArrowDrawsThe150Pixels() {
        for direction in [LayoutDirection.leftToRight, .rightToLeft] {
            for edge in [TooltipEdge.top, .bottom, .leading, .trailing] {
                let current = TooltipArrowShape(edge: edge).fill(Color.white)
                    .overlay(TooltipArrowShape(edge: edge).stroke(Color.gray, lineWidth: 1))
                    .flipsForRightToLeftLayoutDirection(true)
                    .frame(width: edge.isVertical ? 14 : 7, height: edge.isVertical ? 7 : 14)
                    .padding(4).background(Color.blue)
                    .environment(\.layoutDirection, direction)
                let recipe = V150Arrow(edge: edge).fill(Color.white)
                    .overlay(V150Arrow(edge: edge).stroke(Color.gray, lineWidth: 1))
                    .flipsForRightToLeftLayoutDirection(true)
                    .frame(width: edge.isVertical ? 14 : 7, height: edge.isVertical ? 7 : 14)
                    .padding(4).background(Color.blue)
                    .environment(\.layoutDirection, direction)
                XCTAssertLessThanOrEqual(pixelDelta(current, recipe) ?? .max, pixelNoise, "\(edge) \(direction)")
            }
            // Control: a side arrow is asymmetric, so the flip is visible.
            let leading = V150Arrow(edge: .leading).fill(Color.white).frame(width: 7, height: 14)
            XCTAssertGreaterThan(pixelDelta(leading, leading.flipsForRightToLeftLayoutDirection(true)
                .environment(\.layoutDirection, .rightToLeft)) ?? 0, pixelNoise)
        }
    }

    /// `.tooltipStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched built-in bubble.
    func testDefaultStyleDrawsTheBuiltInBubblePixels() {
        let shown = Binding.constant(true)
        let cases: [(String, LayoutDirection, AnyView)] = [
            ("top", .leftToRight, AnyView(anchor.tooltip("Helpful hint", isPresented: shown))),
            ("bottom info", .leftToRight, AnyView(anchor.tooltip("Below", isPresented: shown, edge: .bottom, style: .info))),
            ("leading warning", .leftToRight,
             AnyView(anchor.tooltip("On the leading side", isPresented: shown, edge: .leading, style: .warning))),
            ("trailing primary", .leftToRight,
             AnyView(anchor.tooltip("On the trailing side", isPresented: shown, edge: .trailing, color: .primary))),
            ("color wins over style", .leftToRight,
             AnyView(anchor.tooltip("Tinted", isPresented: shown, style: .error, color: .success))),
            ("align start", .leftToRight,
             AnyView(anchor.tooltip("Start aligned", isPresented: shown, edge: .top, align: .start))),
            ("align end", .leftToRight,
             AnyView(anchor.tooltip("End aligned", isPresented: shown, edge: .trailing, align: .end))),
            ("wrapping", .leftToRight,
             AnyView(anchor.tooltip("A longer hint that wraps onto several lines", isPresented: shown,
                                    edge: .bottom, maxWidth: 140))),
            ("rich", .leftToRight, AnyView(anchor.tooltip(isPresented: shown, edge: .bottom, color: .info) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Installments").fontWeight(.semibold)
                    Text("Split the total into 3 payments.")
                }
            })),
            ("rtl leading", .rightToLeft,
             AnyView(anchor.tooltip("On the leading side", isPresented: shown, edge: .leading))),
            ("rtl trailing", .rightToLeft,
             AnyView(anchor.tooltip("On the trailing side", isPresented: shown, edge: .trailing, style: .info))),
            ("rtl top start", .rightToLeft,
             AnyView(anchor.tooltip("Start aligned", isPresented: shown, align: .start))),
        ]
        for (label, direction, tooltip) in cases {
            let builtIn = stage(tooltip).environment(\.layoutDirection, direction)
            let explicit = stage(tooltip).tooltipStyle(.default).environment(\.layoutDirection, direction)
            let delta = pixelDelta(builtIn, explicit)
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in bubble")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            let dimmed = stage(tooltip).tooltipStyle(DimmedDefaultTooltipStyle()).environment(\.layoutDirection, direction)
            let control = pixelDelta(builtIn, dimmed)
            XCTAssertNotNil(control, "\(label) (control): renders differ in size or failed")
            XCTAssertGreaterThan(control ?? 0, pixelNoise, "\(label) (control): the comparison saw no difference")
        }
    }

    /// Under RTL the stock style draws the configuration's turned arrow with
    /// no flip; drawing the left-to-right arrow unflipped instead must show up,
    /// or the RTL cases above prove nothing about the arrow.
    func testRTLParityWouldCatchAnUnturnedArrow() {
        let tooltip = anchor.tooltip("On the leading side", isPresented: .constant(true), edge: .leading)
        let builtIn = stage(tooltip).environment(\.layoutDirection, .rightToLeft)
        let unturned = stage(tooltip).tooltipStyle(UnturnedArrowTooltipStyle()).environment(\.layoutDirection, .rightToLeft)
        XCTAssertGreaterThan(pixelDelta(builtIn, unturned) ?? 0, pixelNoise)
        // The same style is exact in LTR, where turning changes nothing.
        let builtInLTR = stage(tooltip)
        let unturnedLTR = stage(tooltip).tooltipStyle(UnturnedArrowTooltipStyle())
        XCTAssertLessThanOrEqual(pixelDelta(builtInLTR, unturnedLTR) ?? .max, pixelNoise)
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().tooltipStyle.isDefault)
        XCTAssertFalse(AnyTooltipStyle(DefaultTooltipStyle()).isDefault)
    }

    // MARK: Arrow shape

    func testConfigurationArrowIsTurnedForTheLayoutDirection() {
        let rect = CGRect(x: 0, y: 0, width: 6, height: 12)
        let wide = CGRect(x: 0, y: 0, width: 12, height: 6)
        // Side edges swap paths under RTL…
        XCTAssertEqual(TooltipArrowShape(edge: .leading, layoutDirection: .rightToLeft).path(in: rect),
                       TooltipArrowShape(edge: .trailing).path(in: rect))
        XCTAssertEqual(TooltipArrowShape(edge: .trailing, layoutDirection: .rightToLeft).path(in: rect),
                       TooltipArrowShape(edge: .leading).path(in: rect))
        XCTAssertNotEqual(TooltipArrowShape(edge: .leading).path(in: rect),
                          TooltipArrowShape(edge: .trailing).path(in: rect))
        // …and stay as they are in LTR; top and bottom never change.
        for edge in [TooltipEdge.top, .bottom, .leading, .trailing] {
            let r = edge.isVertical ? wide : rect
            XCTAssertEqual(TooltipArrowShape(edge: edge, layoutDirection: .leftToRight).path(in: r),
                           TooltipArrowShape(edge: edge).path(in: r), "\(edge) LTR")
            if edge.isVertical {
                XCTAssertEqual(TooltipArrowShape(edge: edge, layoutDirection: .rightToLeft).path(in: r),
                               TooltipArrowShape(edge: edge).path(in: r), "\(edge) RTL")
            }
            XCTAssertEqual(TooltipArrowShape(edge: edge, layoutDirection: .rightToLeft).edge, edge,
                           "the shape keeps the logical edge")
        }
    }

    /// The configuration built under RTL carries the turned shape.
    func testConfigurationCarriesTheTurnedArrowUnderRTL() throws {
        let recorder = TooltipConfigurationRecorder()
        _ = render(stage(anchor.tooltip("Hint", isPresented: .constant(true), edge: .trailing))
            .tooltipStyle(RecordingTooltipStyle(recorder: recorder))
            .environment(\.layoutDirection, .rightToLeft))
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.edge, .trailing)
        XCTAssertTrue(c.arrowShape.isMirrored)
        let rect = CGRect(x: 0, y: 0, width: 6, height: 12)
        XCTAssertEqual(c.arrowShape.path(in: rect), TooltipArrowShape(edge: .leading).path(in: rect))
    }

    // MARK: Helpers

    private var anchor: some View {
        Rectangle().fill(Color.gray).frame(width: 24, height: 24)
    }

    /// Room around the anchor so the bubble, which sits outside the anchor's
    /// frame, lands inside the render.
    private func stage(_ tooltip: some View) -> some View {
        tooltip.padding(.horizontal, 180).padding(.vertical, 80)
    }

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second (the first render of new glyphs can antialias a
    /// few bytes differently); callers treat a delta up to `pixelNoise` as
    /// identical.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    private let pixelNoise = 2
}

// MARK: - The 1.5.0 recipe (verbatim bubble, fixed placement)

/// One `.tooltip(…)` call's arguments for the 1.5.0 comparison.
private struct RecipeCase {
    let label: String
    let edge: TooltipEdge
    var align: PopoverAlign = .center
    var style: BadgeStyle?
    var color: SemanticColor?
    var maxWidth: CGFloat?
}

/// 1.5.0's internal `TooltipArrow`: the same path, with SwiftUI's default
/// layout-direction behaviour.
private struct V150Arrow: Shape {
    let edge: TooltipEdge

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch edge {
        case .top:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        case .bottom:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .leading:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        case .trailing:
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        }
        return p
    }
}

/// 1.5.0's `TooltipBubble` (plain text), modifier for modifier.
private struct V150Bubble: View {
    @Environment(\.theme) private var theme
    let text: String
    let edge: TooltipEdge
    let style: BadgeStyle?
    let color: SemanticColor?
    let maxWidth: CGFloat?

    private var bubbleColor: Color {
        color.map { theme.resolve($0).solid } ?? style.map { theme.resolve($0.semantic).solid } ?? theme.background(.bgTertiary)
    }

    var body: some View {
        let bubble = Group { Text(text).multilineTextAlignment(.leading) }
            .textStyle(.bodySm400)
            .foregroundStyle(ColorContrast.content(on: bubbleColor))
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .background(bubbleColor, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
        let arrow = V150Arrow(edge: edge)
            .fill(bubbleColor)
            .frame(width: edge.isVertical ? 12 : 6, height: edge.isVertical ? 6 : 12)
            .flipsForRightToLeftLayoutDirection(true)
        switch edge {
        case .top: VStack(spacing: -1) { bubble; arrow }
        case .bottom: VStack(spacing: -1) { arrow; bubble }
        case .leading: HStack(spacing: -1) { bubble; arrow }
        case .trailing: HStack(spacing: -1) { arrow; bubble }
        }
    }
}

/// 1.5.0's `TooltipPlacement` with the 1.6.0 fix: the same offset and guides, set
/// unconditionally (1.5.0 set them inside a `switch`, which SwiftUI drops).
private struct FixedPlacement: ViewModifier {
    let edge: TooltipEdge
    @Environment(\.layoutDirection) private var layoutDirection

    func body(content: Content) -> some View {
        let gap = Theme.SpacingKey.sm.value
        let direction: CGFloat = layoutDirection == .rightToLeft ? -1 : 1
        let edge = edge
        return content
            .offset(x: edge == .leading ? -gap * direction : edge == .trailing ? gap * direction : 0,
                    y: edge == .top ? -gap : edge == .bottom ? gap : 0)
            .alignmentGuide(.top) { edge == .top ? $0[.bottom] : $0[.top] }
            .alignmentGuide(.bottom) { edge == .bottom ? $0[.top] : $0[.bottom] }
            .alignmentGuide(.leading) { edge == .leading ? $0[.trailing] : $0[.leading] }
            .alignmentGuide(.trailing) { edge == .trailing ? $0[.leading] : $0[.trailing] }
    }
}

// MARK: - Fixtures

@MainActor
private final class TooltipConfigurationRecorder {
    var values: [TooltipStyleConfiguration] = []
}

private struct RecordingTooltipStyle: TooltipStyle {
    let recorder: TooltipConfigurationRecorder

    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return DefaultTooltipStyle().makeBody(configuration: configuration)
    }
}

/// The stock bubble at 30% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultTooltipStyle: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DefaultTooltipStyle().makeBody(configuration: configuration).opacity(0.3)
    }
}

/// The stock bubble handed the left-to-right arrow instead of the turned one.
private struct UnturnedArrowTooltipStyle: TooltipStyle {
    func makeBody(configuration: TooltipStyleConfiguration) -> some View {
        DefaultTooltipStyle().makeBody(configuration: TooltipStyleConfiguration(
            text: configuration.text, content: configuration.content, edge: configuration.edge,
            align: configuration.align, maxWidth: configuration.maxWidth, style: configuration.style,
            color: configuration.color, arrowShape: TooltipArrowShape(edge: configuration.edge),
            isMotionEnabled: configuration.isMotionEnabled, dismiss: configuration.dismiss))
    }
}
