//
//  SegmentedControlStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 23.09.2026.
//
//  `SegmentedControl` + `SegmentedControlStyle`: the built-in pill still draws
//  the 1.10.0 pixels, the stock style draws the same pixels through `makeBody`,
//  a custom style receives the control's options and the selected index,
//  `select` moves the caller's binding (and keeps the disabled gate), and a
//  style scopes to the controls it is set around — never to a sibling
//  component.
//
//  The selection tests host the control in a real window: `select` writes
//  through the binding, and a state update is something an `ImageRenderer`
//  render never runs (the `DialogStyleTests` precedent).
//

import XCTest
import SwiftUI
@testable import ThemeKit

#if canImport(UIKit)
import UIKit
#else
import AppKit
#endif

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class SegmentedControlStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        for fixture in segmentedCases {
            XCTAssertNotNil(render(staged(control(fixture))), fixture.label)
            XCTAssertTrue(drawsInk(staged(control(fixture))), "\(fixture.label): the fixture renders blank")
        }
    }

    /// With no style set, the pill draws the 1.10.0 pixels: extracting the body
    /// behind the `isDefault` branch must move nothing.
    func testBuiltInPillDrawsTheStockPixels() {
        for fixture in segmentedCases {
            let delta = pixelDelta(staged(control(fixture)), staged(recipe(fixture)))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(fixture.label): the built-in pill drifted from 1.10.0")
            // Control, same case: the recipe at 60% opacity must be caught.
            XCTAssertTrue(differs(staged(control(fixture)), staged(recipe(fixture, opacity: 0.6))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    /// `.segmentedControlStyle(.default)` goes through `makeBody`, yet must draw
    /// the same pixels as the untouched built-in path.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for fixture in segmentedCases {
            let styled = control(fixture).segmentedControlStyle(.default)
            let delta = pixelDelta(staged(control(fixture)), staged(styled))
            XCTAssertNotNil(delta, "\(fixture.label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise,
                                     "\(fixture.label): .default drifted from the built-in pill")
            XCTAssertTrue(drawsInk(staged(styled)), "\(fixture.label): the .default fixture renders blank")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            XCTAssertTrue(differs(staged(control(fixture)),
                                  staged(control(fixture).segmentedControlStyle(DimmedDefaultSegmentedControlStyle()))),
                          "\(fixture.label) (control): the comparison saw no difference")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().segmentedControlStyle.isDefault)
        XCTAssertFalse(AnySegmentedControlStyle(DefaultSegmentedControlStyle()).isDefault)
    }

    /// With no style set up the tree, the control never asks any style to draw:
    /// a style set on a sibling isn't consulted, and the pill still draws the
    /// built-in pixels.
    func testDefaultPathDrawsNoCustomStyle() {
        let recorder = SegmentedConfigurationRecorder()
        let fixture = segmentedCases[0]
        let pair = VStack(spacing: 0) {
            control(fixture)
            Color.clear.frame(width: 280, height: 40)
                .segmentedControlStyle(RecordingSegmentedControlStyle(recorder: recorder))
        }
        _ = render(staged(pair))
        XCTAssertTrue(recorder.values.isEmpty, "a style off the control's path was consulted")
        XCTAssertLessThanOrEqual(pixelDelta(staged(control(fixture)), staged(recipe(fixture))) ?? .max, pixelNoise)
    }

    // MARK: Custom style — the configuration

    func testCustomStyleReceivesTheControlsItems() throws {
        let c = try XCTUnwrap(capture(SegmentedControl([SegmentItem("List", systemImage: "list.bullet"),
                                                        SegmentItem(icon: "square.grid.2x2", tooltip: "Grid"),
                                                        SegmentItem("Map", isEnabled: false, tooltip: "Soon"),
                                                        SegmentItem { Text("★") }],
                                                       selection: .constant(2))))

        XCTAssertEqual(c.items.count, 4)
        XCTAssertEqual(c.items.map(\.title), ["List", nil, "Map", nil])
        XCTAssertEqual(c.items[0].systemImage, "list.bullet", "the glyph arrives as a name, not a view")
        XCTAssertFalse(c.items[0].isIconOnly)
        XCTAssertTrue(c.items[1].isIconOnly, "an icon-only option says so")
        XCTAssertEqual(c.items[1].tooltip, "Grid")
        XCTAssertEqual(c.items[1].accessibilityLabel, "Grid", "an icon-only option falls back to its tooltip")
        XCTAssertFalse(c.items[2].isEnabled, "a disabled option reaches the style")
        XCTAssertEqual(c.items[2].accessibilityLabel, "Map")
        XCTAssertNotNil(c.items[3].content, "the custom-content slot reaches the style")
        XCTAssertNil(c.items[3].title)
        XCTAssertEqual(c.selection, 2, "the selected index reaches the style")
        XCTAssertTrue(drawsInk(staged(SegmentedControl(["One way", "Round trip"], selection: .constant(0))
            .segmentedControlStyle(ContentOnlySegmentedControlStyle()))),
                      "the options' content didn't reach the style")
    }

    /// A bare two-option control hands the style the stock axes.
    func testDefaultsReachTheStyle() throws {
        let c = try XCTUnwrap(capture(SegmentedControl(["One way", "Round trip"], selection: .constant(0))))
        XCTAssertEqual(c.items.map(\.title), ["One way", "Round trip"])
        XCTAssertEqual(c.selection, 0)
        XCTAssertEqual(c.size, .medium)
        XCTAssertEqual(c.shape, .default)
        XCTAssertEqual(c.selectionStyle, .thumb)
        XCTAssertTrue(c.fullWidth, "the stock control stretches its options")
        XCTAssertFalse(c.showsDividers)
        XCTAssertEqual(c.tint, .primary, "nothing re-tints the control")
        XCTAssertTrue(c.isEnabled)
        XCTAssertEqual(c.axis, .horizontal)
        XCTAssertEqual(c.selectionID, SegmentedControlMetrics.selectionID)
    }

    /// Every axis the modifiers set reaches the style as it was written.
    func testAxesReachTheStyle() throws {
        let c = try XCTUnwrap(capture(SegmentedControl(["Chart", "Grid"], selection: .constant(1))
            .size(.large)
            .shape(.round)
            .fullWidth(false)
            .vertical()
            .dividers()
            .tinted(.success)))

        XCTAssertEqual(c.size, .large)
        XCTAssertEqual(c.shape, .round)
        XCTAssertEqual(c.selectionStyle, .tinted, "`.tinted(_:)` reaches the style as its selection style")
        XCTAssertEqual(c.tint, .success)
        XCTAssertFalse(c.fullWidth)
        XCTAssertTrue(c.showsDividers)
        XCTAssertEqual(c.axis, .vertical)
        XCTAssertEqual(c.selection, 1)
    }

    /// The provider cascade is resolved before the style sees it: with no
    /// explicit accent the subtree's `componentDefaults` tint arrives, and the
    /// environment's `.disabled(_:)` arrives as `isEnabled`.
    func testResolvedTintAndEnabledStateReachTheStyle() throws {
        let provided = try XCTUnwrap(capture(SegmentedControl(["Day", "Week"], selection: .constant(0))
            .selectionStyle(.outline)
            .componentDefaults(accent: .turquoise)))
        XCTAssertEqual(provided.tint, .turquoise, "the subtree accent didn't reach the style")

        let explicit = try XCTUnwrap(capture(SegmentedControl(["Day", "Week"], selection: .constant(0))
            .accent(.orange)
            .componentDefaults(accent: .turquoise)))
        XCTAssertEqual(explicit.tint, .orange, "an explicit accent must win over the provider")

        let off = try XCTUnwrap(capture(SegmentedControl(["Day", "Week"], selection: .constant(0)).disabled(true)))
        XCTAssertFalse(off.isEnabled, "the environment's .disabled(_:) didn't reach the style")
    }

    // MARK: Custom style — selection

    /// `select` writes through the caller's binding, exactly as the stock
    /// option's button does, and the new index reaches the style.
    func testSelectMovesTheBinding() async throws {
        let box = SelectionBox()
        let recorder = SegmentedConfigurationRecorder()
        let host = LiveHost(BoundSegmentedControlHost(box: box, recorder: recorder))
        defer { host.tearDown() }

        await host.settle { !recorder.values.isEmpty }
        XCTAssertEqual(recorder.values.last?.selection, 0)

        try XCTUnwrap(recorder.values.last).select(1)
        await host.settle { box.index == 1 }
        XCTAssertEqual(box.index, 1, "select didn't write through the caller's binding")
        XCTAssertEqual(recorder.values.last?.selection, 1, "the new selection didn't reach the style")

        // The other direction: the caller moves it and the style follows.
        box.index = 0
        await host.settle { recorder.values.last?.selection == 0 }
        XCTAssertEqual(recorder.values.last?.selection, 0, "a bound change didn't reach the style")
    }

    /// The control keeps its gate: a style's own button can't choose a disabled
    /// option, an index the control doesn't have, or anything at all while the
    /// control itself is disabled.
    func testSelectKeepsTheDisabledGate() async throws {
        let box = SelectionBox()
        let recorder = SegmentedConfigurationRecorder()
        let host = LiveHost(BoundSegmentedControlHost(box: box, recorder: recorder))
        defer { host.tearDown() }
        await host.settle { !recorder.values.isEmpty }

        // Option 2 is the disabled one in the fixture.
        try XCTUnwrap(recorder.values.last).select(2)
        await host.settle { box.index != 0 }
        XCTAssertEqual(box.index, 0, "select chose a disabled option")

        try XCTUnwrap(recorder.values.last).select(7)
        await host.settle { box.index != 0 }
        XCTAssertEqual(box.index, 0, "select chose an index the control doesn't have")

        let offBox = SelectionBox()
        let offRecorder = SegmentedConfigurationRecorder()
        let offHost = LiveHost(BoundSegmentedControlHost(box: offBox, recorder: offRecorder, isEnabled: false))
        defer { offHost.tearDown() }
        await offHost.settle { !offRecorder.values.isEmpty }
        try XCTUnwrap(offRecorder.values.last).select(1)
        await offHost.settle { offBox.index != 0 }
        XCTAssertEqual(offBox.index, 0, "select moved the binding of a disabled control")
    }

    // MARK: Scope

    /// The style reaches the control it's set around and nothing else.
    func testStyleReachesOnlyTheControlItIsSetAround() {
        let recorder = SegmentedConfigurationRecorder()
        _ = render(staged(VStack(spacing: 0) {
            SegmentedControl(["Styled", "B"], selection: .constant(0))
                .segmentedControlStyle(RecordingSegmentedControlStyle(recorder: recorder))
            SegmentedControl(["Sibling", "B"], selection: .constant(0))
        }))
        XCTAssertEqual(recorder.values.map { $0.items.first?.title }, ["Styled"],
                       "the style reached a control it wasn't set around")
    }

    /// A `SegmentedControlStyle` is this component's alone: the tab bar and the
    /// button-style radio group beside it draw their own pixels, and a tab
    /// bar's chrome style never reaches the pill.
    func testStyleDoesNotLeakToASiblingComponent() {
        let bar = SegmentedTabBar(["Flights", "Hotels"], selection: .constant(0))
        XCTAssertTrue(drawsInk(staged(bar)), "the tab-bar fixture renders blank")
        XCTAssertLessThanOrEqual(pixelDelta(staged(bar),
                                            staged(bar.segmentedControlStyle(SlabSegmentedControlStyle(fullWidth: true))))
                                 ?? .max, pixelNoise,
                                 "a SegmentedControlStyle changed a SegmentedTabBar")

        let radios = RadioButtonGroup(options: ["One way", "Round trip"],
                                      selection: .constant(Optional("One way"))) { $0 }
        XCTAssertTrue(drawsInk(staged(radios)), "the radio-group fixture renders blank")
        XCTAssertLessThanOrEqual(pixelDelta(staged(radios),
                                            staged(radios.segmentedControlStyle(SlabSegmentedControlStyle(fullWidth: true))))
                                 ?? .max, pixelNoise,
                                 "a SegmentedControlStyle changed a RadioButtonGroup")

        let pill = control(segmentedCases[0])
        XCTAssertLessThanOrEqual(pixelDelta(staged(pill),
                                            staged(pill.segmentedTabBarChromeStyle(BlankTabChromeStyle())))
                                 ?? .max, pixelNoise,
                                 "a SegmentedTabBarChromeStyle reached the SegmentedControl")
    }

    // MARK: Layout

    /// ThemeKit wraps nothing around a custom body but the control's animation
    /// and its accessibility element: a style that fills its width spans the
    /// container, and one that hugs its content doesn't.
    func testCustomBodyGetsNoThemeKitChrome() {
        let pill = SegmentedControl(["Edge", "Case"], selection: .constant(0))
        let filling = staged(pill.segmentedControlStyle(SlabSegmentedControlStyle(fullWidth: true)))
        let hugging = staged(pill.segmentedControlStyle(SlabSegmentedControlStyle(fullWidth: false)))
        XCTAssertTrue(drawsInk(filling), "the fixture renders blank")
        let wide = pixelDelta(filling, staged(SlabSegmentedControlStyle.slab(fullWidth: true)))
        XCTAssertNotNil(wide, "renders differ in size or failed")
        XCTAssertLessThanOrEqual(wide ?? .max, pixelNoise, "ThemeKit changed the custom body's width")
        XCTAssertLessThanOrEqual(pixelDelta(hugging, staged(SlabSegmentedControlStyle.slab(fullWidth: false))) ?? .max,
                                 pixelNoise, "ThemeKit stretched a custom body that hugs its content")
        XCTAssertTrue(differs(filling, hugging), "control: the comparison saw no difference")
    }

    // MARK: Fixtures

    private var segmentedCases: [SegmentedCase] {
        [
            SegmentedCase(label: "two options"),
            SegmentedCase(label: "round, selected last", selection: 1, shape: .round),
            SegmentedCase(label: "icons + a disabled option",
                          items: [SegmentItem("List", systemImage: "list.bullet"),
                                  SegmentItem("Grid", systemImage: "square.grid.2x2"),
                                  SegmentItem("Map", systemImage: "map", isEnabled: false)],
                          selection: 1),
            SegmentedCase(label: "icon-only, hugging",
                          items: [SegmentItem(icon: "chart.bar"), SegmentItem(icon: "square.grid.2x2")],
                          fullWidth: false),
            SegmentedCase(label: "custom content",
                          items: [SegmentItem { Text("★").textStyle(.labelBase700) },
                                  SegmentItem { Text("☆").textStyle(.labelBase600) }]),
            SegmentedCase(label: "outline", selectionStyle: .outline),
            SegmentedCase(label: "outline, accented", selectionStyle: .outline, tint: .success),
            SegmentedCase(label: "tinted + dividers, hugging", shape: .round, selectionStyle: .tinted,
                          tint: .turquoise, fullWidth: false, dividers: true),
            SegmentedCase(label: "vertical, small", selection: 1, size: .small, fullWidth: false, vertical: true),
            SegmentedCase(label: "large", size: .large),
            SegmentedCase(label: "disabled control", enabled: false),
            SegmentedCase(label: "selection out of range", selection: 5),
        ]
    }

    /// The fixture as the component draws it.
    private func control(_ fixture: SegmentedCase) -> AnyView {
        var pill = SegmentedControl(fixture.items, selection: .constant(fixture.selection))
            .size(fixture.size)
            .shape(fixture.shape)
            .selectionStyle(fixture.selectionStyle)
            .fullWidth(fixture.fullWidth)
            .vertical(fixture.vertical)
            .dividers(fixture.dividers)
        if let tint = fixture.tint { pill = pill.accent(tint) }
        return AnyView(pill.disabled(!fixture.enabled))
    }

    /// The same fixture as 1.10.0 drew it: the old body written out.
    private func recipe(_ fixture: SegmentedCase, opacity: Double = 1) -> some View {
        V1100SegmentedControl(items: fixture.items, selection: fixture.selection, isEnabled: fixture.enabled,
                              isFullWidth: fixture.fullWidth, size: fixture.size, shape: fixture.shape,
                              selectionStyle: fixture.selectionStyle, tintColor: fixture.tint,
                              isVertical: fixture.vertical, showsDividers: fixture.dividers)
            .opacity(opacity)
    }

    /// The configuration a style is handed for `pill`.
    private func capture(_ pill: some View) -> SegmentedControlStyleConfiguration? {
        let recorder = SegmentedConfigurationRecorder()
        _ = render(staged(pill.segmentedControlStyle(RecordingSegmentedControlStyle(recorder: recorder))))
        return recorder.values.last
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 280).padding(8)
    }

    private func render(_ view: some View) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    private func drawsInk(_ view: some View) -> Bool {
        _ = render(view)
        guard let image = render(view), let data = image.dataProvider?.data as Data?, let first = data.first
        else { return false }
        return data.contains { $0 != first }
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second; callers treat a delta up to `pixelNoise` as
    /// identical.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        _ = render(a)
        _ = render(b)
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    /// `true` when two renders are visibly different — either their sizes
    /// differ or a channel moved past the antialiasing noise floor.
    private func differs<A: View, B: View>(_ a: A, _ b: B) -> Bool {
        guard let delta = pixelDelta(a, b) else { return true }
        return delta > pixelNoise
    }

    private let pixelNoise = 2
}

// MARK: - The 1.10.0 recipe (the pill written out)

/// `SegmentedControl`'s 1.10.0 body, written out: the reference the built-in
/// path must still draw. Its selection is a constant — the pixels are what
/// matter.
@available(iOS 16.0, macOS 13.0, *)
private struct V1100SegmentedControl: View {
    @Environment(\.theme) private var theme
    @Namespace private var pill
    @State private var hovered: Int?

    var items: [SegmentItem]
    var selection: Int
    var isEnabled = true
    var isFullWidth = true
    var size: SegmentedSize = .medium
    var shape: SegmentedShape = .default
    var selectionStyle: SegmentedSelectionStyle = .thumb
    var tintColor: SemanticColor?
    var isVertical = false
    var showsDividers = false

    private var resolvedTint: SemanticColor { tintColor ?? .primary }
    private var usesStockTint: Bool { tintColor == nil }

    private var trackShape: ThemeAnyShape {
        shape == .round
            ? ThemeAnyShape(Capsule(style: .continuous))
            : ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
    private var thumbShape: ThemeAnyShape {
        shape == .round
            ? ThemeAnyShape(Capsule(style: .continuous))
            : ThemeAnyShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
    }
    private var trackFill: Color {
        selectionStyle == .tinted ? theme.resolve(resolvedTint).soft : theme.background(.bgBase)
    }

    var body: some View {
        segments
            .padding(selectionStyle == .tinted ? 0 : 4)
            .background(trackFill, in: trackShape)
            .opacity(isEnabled ? 1 : 0.5)
    }

    @ViewBuilder private var segments: some View {
        if isVertical {
            VStack(spacing: showsDividers ? 0 : 4) { segmentRows }
        } else {
            HStack(spacing: showsDividers ? 0 : 4) { segmentRows }
        }
    }

    @ViewBuilder private var segmentRows: some View {
        ForEach(Array(items.enumerated()), id: \.offset) { index, item in
            segment(index, item)
            if showsDividers && index < items.count - 1 { divider }
        }
    }

    @ViewBuilder private var divider: some View {
        if isVertical {
            Rectangle().fill(theme.background(.bgWhite)).frame(height: 1).padding(.horizontal, 6)
        } else {
            Rectangle().fill(theme.background(.bgWhite)).frame(width: 1).padding(.vertical, 6)
        }
    }

    private func segment(_ index: Int, _ item: SegmentItem) -> some View {
        let isActive = index == selection
        return Button {} label: {
            label(item, isActive: isActive)
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .frame(maxWidth: isFullWidth ? .infinity : nil)
                .padding(.vertical, size.verticalPadding)
                .padding(.horizontal, item.isIconOnly ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value)
                .background { hoverFill(index: index, isActive: isActive, enabled: item.isEnabled) }
                .background { selectionFill(isActive: isActive) }
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled || !item.isEnabled)
        .onHover { hovering in hovered = hovering ? index : (hovered == index ? nil : hovered) }
        .help(item.tooltip ?? "")
    }

    @ViewBuilder private func hoverFill(index: Int, isActive: Bool, enabled: Bool) -> some View {
        if hovered == index, !isActive, enabled, isEnabled {
            thumbShape.fill(theme.text(.textPrimary).opacity(0.06))
        }
    }

    @ViewBuilder private func label(_ item: SegmentItem, isActive: Bool) -> some View {
        if let content = item.content {
            content
        } else {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let icon = item.systemImage {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                if let title = item.title {
                    Text(title).textStyle(isActive ? .labelBase700 : .labelBase600)
                }
            }
        }
    }

    @ViewBuilder private func selectionFill(isActive: Bool) -> some View {
        if isActive {
            switch selectionStyle {
            case .thumb:
                thumbShape.fill(theme.background(.bgWhite)).themeShadow(.soft)
                    .matchedGeometryEffect(id: "pill", in: pill)
            case .outline:
                thumbShape.fill(theme.resolve(resolvedTint).soft)
                    .overlay(thumbShape.stroke(usesStockTint ? theme.border(.borderHero)
                                                             : theme.resolve(resolvedTint).border,
                                               lineWidth: 2))
                    .matchedGeometryEffect(id: "pill", in: pill)
            case .tinted:
                EmptyView()
            }
        }
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        guard isActive else { return theme.text(.textSecondary) }
        return selectionStyle == .tinted ? theme.resolve(resolvedTint).accent : theme.text(.textHero)
    }
}

// MARK: - Fixtures

private struct SegmentedCase {
    let label: String
    var items: [SegmentItem] = [SegmentItem("One way"), SegmentItem("Round trip")]
    var selection = 0
    var size: SegmentedSize = .medium
    var shape: SegmentedShape = .default
    var selectionStyle: SegmentedSelectionStyle = .thumb
    var tint: SemanticColor?
    var fullWidth = true
    var vertical = false
    var dividers = false
    var enabled = true
}

@MainActor
private final class SegmentedConfigurationRecorder {
    var values: [SegmentedControlStyleConfiguration] = []
}

private struct RecordingSegmentedControlStyle: SegmentedControlStyle {
    let recorder: SegmentedConfigurationRecorder

    @MainActor
    func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return HStack(spacing: 0) {
            ForEach(Array(configuration.items.enumerated()), id: \.offset) { index, item in
                Text(item.title ?? "•").opacity(index == configuration.selection ? 1 : 0.5)
            }
        }
    }
}

/// The stock pill at 60% opacity — the control for the pixel-parity loops.
private struct DimmedDefaultSegmentedControlStyle: SegmentedControlStyle {
    func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
        DefaultSegmentedControlStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

/// Draws the options' own content and nothing else.
private struct ContentOnlySegmentedControlStyle: SegmentedControlStyle {
    func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
        HStack {
            ForEach(Array(configuration.items.enumerated()), id: \.offset) { _, item in
                Text(item.title ?? "").textStyle(.bodyBase400)
            }
        }
    }
}

/// A flat slab, either filling its container's width or hugging its content —
/// the layout proof.
private struct SlabSegmentedControlStyle: SegmentedControlStyle {
    let fullWidth: Bool

    @MainActor static func slab(fullWidth: Bool) -> some View {
        Rectangle().fill(Color.red)
            .frame(width: fullWidth ? nil : 120, height: 40)
            .frame(maxWidth: fullWidth ? .infinity : nil)
    }

    func makeBody(configuration: SegmentedControlStyleConfiguration) -> some View {
        Self.slab(fullWidth: fullWidth)
    }
}

/// A tab chrome that draws nothing — proof a tab-bar style never reaches the
/// pill (if it did, the pill would vanish).
private struct BlankTabChromeStyle: SegmentedTabBarChromeStyle {
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        Color.clear.frame(width: 1, height: 1)
    }
}

/// The caller-owned selection of the live fixture.
private final class SelectionBox: ObservableObject {
    @Published var index = 0
}

/// A control whose binding the box owns, so the test can drive it from outside
/// and watch what reaches the style. Option 2 is disabled — the gate's fixture.
@available(iOS 16.0, macOS 13.0, *)
private struct BoundSegmentedControlHost: View {
    @ObservedObject var box: SelectionBox
    let recorder: SegmentedConfigurationRecorder
    var isEnabled = true

    var body: some View {
        SegmentedControl([SegmentItem("One way"), SegmentItem("Round trip"), SegmentItem("Multi", isEnabled: false)],
                         selection: $box.index)
            .segmentedControlStyle(RecordingSegmentedControlStyle(recorder: recorder))
            .disabled(!isEnabled)
    }
}

// MARK: - Live host (state updates an `ImageRenderer` render never runs)

@available(iOS 16.0, macOS 13.0, *)
@MainActor
private final class LiveHost {
    #if canImport(UIKit)
    private let controller: UIHostingController<AnyView>
    private let window: UIWindow
    #else
    private let view: NSHostingView<AnyView>
    private let window: NSWindow
    #endif

    init(_ root: some View) {
        let size = CGSize(width: 360, height: 480)
        #if canImport(UIKit)
        controller = UIHostingController(rootView: AnyView(root))
        window = UIWindow(frame: CGRect(origin: .zero, size: size))
        window.rootViewController = controller
        window.isHidden = false
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view = NSHostingView(rootView: AnyView(root))
        view.frame = CGRect(origin: .zero, size: size)
        window = NSWindow(contentRect: CGRect(origin: .zero, size: size),
                          styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        view.layoutSubtreeIfNeeded()
        #endif
        pump()
    }

    /// Runs the main loop (layout, updates, animations) until `condition`
    /// holds, or for half a second when it never does.
    func settle(_ condition: () -> Bool) async {
        let deadline = Date().addingTimeInterval(condition() ? 0 : 0.5)
        repeat {
            pump()
            try? await Task.sleep(nanoseconds: 10_000_000)
        } while !condition() && Date() < deadline
        pump()
    }

    func tearDown() {
        #if canImport(UIKit)
        window.isHidden = true
        #else
        window.orderOut(nil)
        window.contentView = nil
        #endif
    }

    private func pump() {
        #if canImport(UIKit)
        controller.view.setNeedsLayout()
        controller.view.layoutIfNeeded()
        #else
        view.needsLayout = true
        view.layoutSubtreeIfNeeded()
        view.displayIfNeeded()
        #endif
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.01))
    }
}
