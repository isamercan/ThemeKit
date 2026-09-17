//
//  SegmentedTabBarChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 17.09.2026.
//
//  `SegmentedTabBar` + `SegmentedTabBarChromeStyle`: the built-in bar still
//  draws the 1.6.0 pixels, the stock style draws the same pixels as the
//  built-in tabs (every treatment, selected / unselected / disabled), a custom
//  style receives one tab's content, axes and state, and the new API behaves —
//  the `TabItem.leading { }` slot, `.fillsWidth(false)` and `.baseline()`.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class SegmentedTabBarChromeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(staged(SegmentedTabBar(["A", "B"], selection: .constant(0)))), "underline")
        XCTAssertNotNil(render(staged(SegmentedTabBar(["A", "B"], selection: .constant(0)).tabStyle(.pill))), "pill")
        XCTAssertNotNil(render(staged(SegmentedTabBar(["A", "B"], selection: .constant(0),
                                                      onClose: { _ in }, onAdd: {}).tabStyle(.card))), "card")
        XCTAssertNotNil(render(staged(SegmentedTabBar(richItems, selection: .constant(1)).dividers())), "rich + dividers")
        XCTAssertNotNil(render(staged(SegmentedTabBar([TabItem("Flights").leading { Circle().frame(width: 8, height: 8) }],
                                                      selection: .constant(0)))), "leading slot")
    }

    /// The built-in bar draws the 1.6.0 pixels: the slot, `.fillsWidth(_:)`,
    /// `.baseline(_:)` and the style path are additive, so a bar that uses none
    /// of them must not move. (A `.card` bar and a `.scrollable()` one live in
    /// a `ScrollView`, which `ImageRenderer` leaves empty — those two are
    /// pinned by the iOS snapshot suite instead; `testFixturesDrawInk` keeps
    /// every case here honest.)
    func testBuiltInBarDrawsThe160Pixels() {
        let items = richItems
        for (label, style) in [("underline", SegmentedTabBarStyle.underline), ("pill", .pill)] {
            for selection in [0, 1] {
                let current = staged(SegmentedTabBar(items, selection: .constant(selection))
                    .tabStyle(style))
                let recipe = staged(V160TabBar(items: items, selection: selection, style: style))
                let delta = pixelDelta(current, recipe)
                XCTAssertNotNil(delta, "\(label) \(selection): renders differ in size or failed")
                XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label) \(selection): the built-in bar drifted from 1.6.0")
                // Control, same case: the recipe at 60% opacity must be caught.
                XCTAssertGreaterThan(pixelDelta(current, staged(V160TabBar(items: items, selection: selection, style: style)
                    .opacity(0.6))) ?? 0, pixelNoise, "\(label) \(selection) (control): the comparison saw no difference")
            }
        }
    }

    /// `.segmentedTabBarChromeStyle(.default)` goes through `makeBody`, yet must
    /// draw the same pixels as the untouched built-in tabs.
    func testDefaultStyleDrawsTheBuiltInPixels() {
        for (label, bar) in parityCases {
            let delta = pixelDelta(staged(bar), staged(bar.segmentedTabBarChromeStyle(.default)))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in tabs")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            let control = pixelDelta(staged(bar), staged(bar.segmentedTabBarChromeStyle(DimmedDefaultTabChrome())))
            XCTAssertNotNil(control, "\(label) (control): renders differ in size or failed")
            XCTAssertGreaterThan(control ?? 0, pixelNoise, "\(label) (control): the comparison saw no difference")
        }
    }

    /// The disabled fade the built-in path's `.plain` button applies, on both
    /// a disabled item and a disabled bar.
    func testDefaultStyleMatchesTheDisabledLooks() {
        let disabledItem = SegmentedTabBar([TabItem("On"), TabItem("Off", isEnabled: false)], selection: .constant(0))
        let disabledBar = SegmentedTabBar(["On", "Off"], selection: .constant(0)).disabled(true)
        for (label, bar) in [("disabled item", AnyView(disabledItem)), ("disabled bar", AnyView(disabledBar))] {
            let delta = pixelDelta(staged(bar), staged(bar.segmentedTabBarChromeStyle(.default)))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the built-in tabs")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().segmentedTabBarChromeStyle.isDefault)
        XCTAssertFalse(AnySegmentedTabBarChromeStyle(DefaultSegmentedTabBarChromeStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesOneConfigurationPerTabWithContentAxesAndState() throws {
        let recorder = TabConfigurationRecorder()
        let bar = SegmentedTabBar([TabItem("Economy", caption: "$2,450", systemImage: "airplane",
                                           trailingSystemImage: "star.fill", badge: "12"),
                                   TabItem("Business"),
                                   TabItem("First", isEnabled: false)], selection: .constant(1))
            .tabStyle(.pill)
            .size(.large)
            .scrollable()
        _ = render(staged(bar.segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder)).controlSize(.small)))

        XCTAssertEqual(recorder.values.map(\.title), ["Economy", "Business", "First"])
        let first = try XCTUnwrap(recorder.values.first)
        XCTAssertEqual(first.caption, "$2,450")
        XCTAssertEqual(first.badge, "12")
        XCTAssertEqual(first.systemImage, "airplane")
        XCTAssertEqual(first.trailingSystemImage, "star.fill")
        XCTAssertNotNil(first.leading, "the SF Symbol shorthand is handed over pre-sized")
        XCTAssertFalse(first.isSelected)
        XCTAssertTrue(first.isEnabled)
        XCTAssertFalse(first.isPressed)
        XCTAssertEqual(first.tabStyle, .pill)
        XCTAssertEqual(first.size, .large)
        XCTAssertEqual(first.controlSize, .small)
        XCTAssertTrue(first.isScrollable)
        XCTAssertTrue(first.fillsWidth, "the modifier's own value, whatever the bar does with it")
        XCTAssertFalse(first.isStretched, "a scrolling bar hands out no share of its width")
        XCTAssertEqual(first.indicatorID, SegmentedTabAccessibility.indicatorID)
        XCTAssertNil(first.closeButton)
        XCTAssertNil(first.onClose)
        XCTAssertTrue(recorder.values[1].isSelected, "the selected tab is the one that says so")
        XCTAssertFalse(recorder.values[2].isEnabled, "a disabled item reaches the style disabled")
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = TabConfigurationRecorder()
        _ = render(staged(SegmentedTabBar(["Only"], selection: .constant(0))
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNil(c.caption)
        XCTAssertNil(c.badge)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.systemImage)
        XCTAssertNil(c.trailingSystemImage)
        XCTAssertEqual(c.tabStyle, .underline)
        XCTAssertEqual(c.size, .medium)
        XCTAssertFalse(c.isScrollable)
        XCTAssertTrue(c.fillsWidth)
        XCTAssertTrue(c.isStretched)
        XCTAssertNotNil(c.animation, "the bar hands over its resolved selection animation")
    }

    /// A disabled bar reaches the style disabled, even with enabled items.
    func testDisabledBarReachesTheStyle() throws {
        let recorder = TabConfigurationRecorder()
        _ = render(staged(SegmentedTabBar(["A"], selection: .constant(0))
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder))
            .disabled(true)))
        XCTAssertFalse(try XCTUnwrap(recorder.values.last).isEnabled)
    }

    /// Motion arrives resolved: a style never reads the motion environment.
    func testMotionIsResolvedBeforeTheStyleSeesIt() throws {
        let recorder = TabConfigurationRecorder()
        _ = render(staged(SegmentedTabBar(["A", "B"], selection: .constant(0))
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder))
            .microAnimations(false)))
        XCTAssertNil(try XCTUnwrap(recorder.values.last).animation)
    }

    /// A closable card tab carries the wired close button and its handler.
    func testClosableCardTabCarriesItsCloseButton() throws {
        let recorder = TabConfigurationRecorder()
        var closed: [Int] = []
        _ = render(staged(SegmentedTabBar(["Search", "Results"], selection: .constant(0), onClose: { closed.append($0) })
            .tabStyle(.card)
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder))))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNotNil(c.closeButton)
        XCTAssertNotNil(c.onClose)
        c.onClose?()
        XCTAssertEqual(closed, [1], "the handler closes the tab it came from")

        // …and a bar with no `onClose:` hands over neither.
        let plain = TabConfigurationRecorder()
        _ = render(staged(SegmentedTabBar(["Search"], selection: .constant(0)).tabStyle(.card)
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: plain))))
        XCTAssertNil(try XCTUnwrap(plain.values.last).closeButton)
    }

    /// The bar keeps drawing what sits around the tabs, so a styled bar is
    /// still a bar: the `.pill` track still boxes the styled tabs (its padding
    /// and fill are the bar's, not the style's).
    func testTheBarAroundTheTabsSurvivesTheStylePath() throws {
        let bare = SegmentedTabBar(["A", "B"], selection: .constant(0))
            .segmentedTabBarChromeStyle(FlatTabChrome())
        let boxed = SegmentedTabBar(["A", "B"], selection: .constant(0)).tabStyle(.pill)
            .segmentedTabBarChromeStyle(FlatTabChrome())
        let bareHeight = try XCTUnwrap(render(staged(bare))?.height)
        let boxedHeight = try XCTUnwrap(render(staged(boxed))?.height)
        XCTAssertGreaterThan(boxedHeight, bareHeight, "the pill track's padding must still be drawn")
        XCTAssertGreaterThan(ink(staged(boxed)), ink(staged(bare)), "…and its fill with it")
    }

    /// Every fixture the pixel loops compare actually draws something — a pair
    /// of empty renders would pass every comparison in this file.
    func testFixturesDrawInk() {
        for (label, bar) in parityCases {
            XCTAssertGreaterThan(ink(staged(bar)), 0, "\(label): the fixture renders nothing")
        }
        for (label, style) in [("underline", SegmentedTabBarStyle.underline), ("pill", .pill)] {
            XCTAssertGreaterThan(ink(staged(V160TabBar(items: richItems, selection: 0, style: style))), 0,
                                 "\(label): the 1.6.0 recipe renders nothing")
        }
    }

    // MARK: TabItem.leading slot

    /// On the built-in path the slot takes the SF Symbol's place.
    func testLeadingSlotReplacesTheSymbolOnTheBuiltInPath() {
        let slotOnly = SegmentedTabBar([TabItem("Flights").leading { Image(systemName: "star.fill") }],
                                       selection: .constant(0))
        let slotOverSymbol = SegmentedTabBar([TabItem("Flights", systemImage: "airplane")
            .leading { Image(systemName: "star.fill") }], selection: .constant(0))
        let symbolOnly = SegmentedTabBar([TabItem("Flights", systemImage: "airplane")], selection: .constant(0))
        XCTAssertLessThanOrEqual(pixelDelta(staged(slotOnly), staged(slotOverSymbol)) ?? .max, pixelNoise)
        XCTAssertGreaterThan(pixelDelta(staged(slotOverSymbol), staged(symbolOnly)) ?? 0, pixelNoise)
    }

    func testLeadingSlotHidesTheSymbolNameFromTheStyle() throws {
        let recorder = TabConfigurationRecorder()
        _ = render(staged(SegmentedTabBar([TabItem("Flights", systemImage: "airplane").leading { Text("L") }],
                                          selection: .constant(0))
            .segmentedTabBarChromeStyle(RecordingTabChrome(recorder: recorder))))
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNotNil(c.leading)
        XCTAssertNil(c.systemImage, "a set slot hides the shorthand's symbol name")
    }

    // MARK: fillsWidth

    /// `.fillsWidth()` is today's distribution; off, the tabs hug their content
    /// and park at the leading edge.
    func testFillsWidthDistributesAndHuggingDoesNot() {
        let filled = SegmentedTabBar(["A", "Much longer tab"], selection: .constant(0))
        let hugging = filled.fillsWidth(false)
        XCTAssertLessThanOrEqual(pixelDelta(staged(filled), staged(filled.fillsWidth())) ?? .max, pixelNoise,
                                 "`.fillsWidth()` is the default")
        XCTAssertGreaterThan(pixelDelta(staged(filled), staged(hugging)) ?? 0, pixelNoise,
                             "a hugging bar lays its tabs out differently")
    }

    /// A hugging bar puts no space between the tabs on the style path, so a
    /// style's own padding sets the gap: the bar is exactly as wide as its
    /// tabs laid out edge to edge.
    func testHuggingBarDropsTheSpacingOnTheStylePath() throws {
        let hugging = SegmentedTabBar(["Flights", "Hotels"], selection: .constant(0))
            .fillsWidth(false)
            .segmentedTabBarChromeStyle(FlatTabChrome())
        let edgeToEdge = HStack(spacing: 0) { flatTab("Flights"); flatTab("Hotels") }
        let spaced = HStack(spacing: Theme.SpacingKey.lg.value) { flatTab("Flights"); flatTab("Hotels") }

        let barWidth = try XCTUnwrap(contentWidth(hugging))
        XCTAssertEqual(barWidth, try XCTUnwrap(contentWidth(edgeToEdge)), "a hugging bar adds no gap of its own")
        XCTAssertNotEqual(barWidth, try XCTUnwrap(contentWidth(spaced)), "…and the measurement would see one")
    }

    // MARK: baseline

    func testBaselineIsOffByDefaultAndDrawsAHairline() {
        let bar = SegmentedTabBar(["A", "B"], selection: .constant(0))
        XCTAssertLessThanOrEqual(pixelDelta(staged(bar), staged(bar.baseline(false))) ?? .max, pixelNoise,
                                 "the baseline is off by default")
        XCTAssertGreaterThan(pixelDelta(staged(bar), staged(bar.baseline())) ?? 0, pixelNoise,
                             "`.baseline()` must draw a rule")
    }

    /// The baseline is a `DividerView`, so a `DividerStyle` paints it.
    func testDividerStyleReachesTheBaseline() throws {
        let recorder = DividerConfigurationRecorder()
        _ = render(staged(SegmentedTabBar(["A", "B"], selection: .constant(0))
            .baseline()
            .dividerStyle(RecordingDividerStyle(recorder: recorder))))
        XCTAssertFalse(recorder.values.isEmpty, "the baseline must go through the divider style")
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).axis, .horizontal)
    }

    // MARK: Accessibility decisions

    /// A unit-test host builds no accessibility tree, so the decision is tested
    /// where it's made.
    func testStyledTabReadsItsTitleCaptionAndBadge() {
        XCTAssertEqual(SegmentedTabAccessibility.label(title: "Economy", caption: "$2,450", badge: "12"),
                       "Economy, $2,450, 12")
        XCTAssertEqual(SegmentedTabAccessibility.label(title: "Economy", caption: nil, badge: nil), "Economy")
    }

    // MARK: Helpers

    private var slotItems: [TabItem] {
        [TabItem("Flights").leading { Circle().frame(width: 8, height: 8) },
         TabItem("Hotels", systemImage: "bed.double")]
    }

    private var richItems: [TabItem] {
        [TabItem("Economy", caption: "$2,450", systemImage: "airplane", badge: "12"),
         TabItem("Business", trailingSystemImage: "star.fill"),
         TabItem("First", isEnabled: false)]
    }

    /// Every bar a pixel loop compares. Scrolling bars (`.scrollable()`,
    /// `.card`) are left out: `ImageRenderer` renders a `ScrollView`'s content
    /// as nothing, so a comparison of two of them proves nothing. The iOS
    /// snapshot suite covers those.
    private var parityCases: [(String, AnyView)] {
        let items = richItems
        return [
            ("underline", AnyView(SegmentedTabBar(items, selection: .constant(0)))),
            ("underline · second selected", AnyView(SegmentedTabBar(items, selection: .constant(1)))),
            ("underline · small", AnyView(SegmentedTabBar(items, selection: .constant(0)).size(.small))),
            ("underline · large", AnyView(SegmentedTabBar(items, selection: .constant(0)).size(.large))),
            ("underline · hugging", AnyView(SegmentedTabBar(items, selection: .constant(0)).fillsWidth(false))),
            ("underline · dividers", AnyView(SegmentedTabBar(items, selection: .constant(0)).dividers())),
            ("underline · baseline", AnyView(SegmentedTabBar(items, selection: .constant(0)).baseline())),
            ("underline · slots", AnyView(SegmentedTabBar(slotItems, selection: .constant(0)))),
            ("pill", AnyView(SegmentedTabBar(items, selection: .constant(0)).tabStyle(.pill))),
            ("pill · selected", AnyView(SegmentedTabBar(items, selection: .constant(1)).tabStyle(.pill))),
            ("pill · small hugging", AnyView(SegmentedTabBar(items, selection: .constant(0)).tabStyle(.pill)
                .size(.small).fillsWidth(false))),
            ("pill · large", AnyView(SegmentedTabBar(items, selection: .constant(1)).tabStyle(.pill).size(.large))),
        ]
    }

    private func staged(_ view: some View) -> some View {
        view.frame(width: 360).padding(8)
    }

    /// One tab of ``FlatTabChrome``, for the spacing measurement.
    private func flatTab(_ title: String) -> some View {
        Text(title).textStyle(.labelBase600)
    }

    /// The rendered width of a bar that sizes itself (no fixed frame).
    private func contentWidth(_ view: some View) -> Int? {
        render(view.fixedSize(horizontal: true, vertical: false).padding(8))?.width
    }

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// How many bytes of a render are not fully transparent — zero means the
    /// view drew nothing at all.
    private func ink<V: View>(_ view: V) -> Int {
        guard let image = render(view), let data = image.dataProvider?.data as Data? else { return 0 }
        return data.reduce(0) { $1 == 0 ? $0 : $0 + 1 }
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. Each view renders twice
    /// and keeps the second (the first render of new glyphs can antialias a few
    /// bytes differently); callers treat a delta up to `pixelNoise` as identical.
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

// MARK: - The 1.6.0 recipe (verbatim bar)

/// `SegmentedTabBar`'s 1.6.0 tabs, written out: the reference the built-in path
/// must still draw. Covers the three treatments at the default density, with no
/// dividers, no add button and no auto-scroll.
@available(iOS 16.0, macOS 13.0, *)
private struct V160TabBar: View {
    @Environment(\.theme) private var theme

    let items: [TabItem]
    let selection: Int
    let style: SegmentedTabBarStyle

    private let hPadding = Theme.SpacingKey.md.value
    private let vPadding = Theme.SpacingKey.sm.value

    var body: some View {
        if style == .card {
            ScrollView(.horizontal, showsIndicators: false) { bar }
        } else {
            bar
        }
    }

    private var bar: some View {
        HStack(spacing: style == .card ? Theme.SpacingKey.sm.value
               : (style == .pill ? Theme.SpacingKey.xs.value : 0)) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Group {
                    switch style {
                    case .card: card(index: index, item: item)
                    case .pill: pill(index: index, item: item).frame(maxWidth: .infinity)
                    case .underline: underline(index: index, item: item).frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(style == .pill ? Theme.SpacingKey.xs.value : 0)
        .background {
            if style == .pill {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .fill(theme.background(.bgElevatorTertiary))
            }
        }
    }

    private func titleStyle(_ active: Bool) -> TextStyle { active ? .labelBase700 : .labelBase600 }

    private func badge(_ text: String) -> some View {
        Text(text).textStyle(.overline400).foregroundStyle(theme.foreground(.fgSecondary))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(theme.background(.systemcolorsBgError), in: Capsule())
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textPrimary) : theme.text(.textSecondary)
    }

    private func underline(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return Button {} label: {
            VStack(spacing: Theme.SpacingKey.sm.value) {
                VStack(spacing: 1) {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        if let icon = item.systemImage {
                            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                        }
                        Text(item.title).textStyle(titleStyle(isActive))
                        if let trailing = item.trailingSystemImage {
                            Image(systemName: trailing).font(.system(size: 13, weight: .semibold))
                        }
                        if let value = item.badge { badge(value) }
                    }
                    if let caption = item.caption {
                        Text(caption).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))

                ZStack {
                    Capsule().fill(Color.clear).frame(height: 2)
                    if isActive {
                        Capsule().fill(theme.border(.borderHero)).frame(height: 2)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
    }

    private func pill(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return Button {} label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let icon = item.systemImage {
                    Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                }
                Text(item.title).textStyle(titleStyle(isActive))
                if let value = item.badge { badge(value) }
            }
            .foregroundStyle(item.isEnabled
                             ? (isActive ? theme.foreground(.fgSecondary) : theme.text(.textSecondary))
                             : theme.text(.textDisabled))
            .padding(.horizontal, hPadding)
            .padding(.vertical, vPadding)
            .frame(maxWidth: .infinity)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .fill(theme.background(.bgHero))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
    }

    private func card(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return HStack(spacing: Theme.SpacingKey.xs.value) {
            Button {} label: {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let icon = item.systemImage {
                        Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                    }
                    Text(item.title).textStyle(titleStyle(isActive))
                    if let value = item.badge { badge(value) }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, hPadding)
        .padding(.vertical, vPadding)
        .background(
            (isActive ? theme.background(.bgWhite) : theme.background(.bgElevatorTertiary)),
            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(isActive ? theme.border(.borderHero) : theme.border(.borderPrimary),
                              lineWidth: isActive ? 1.5 : 1)
        )
        .disabled(!item.isEnabled)
    }
}

// MARK: - Fixture styles

@MainActor
private final class TabConfigurationRecorder {
    var values: [SegmentedTabBarChromeStyleConfiguration] = []
}

private struct RecordingTabChrome: SegmentedTabBarChromeStyle {
    let recorder: TabConfigurationRecorder

    @MainActor
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return HStack(spacing: 4) {
            configuration.leading
            Text(configuration.title)
            configuration.closeButton
        }
    }
}

/// A flat text tab with no padding of its own — the fixture for the layout
/// assertions (spacing, the bar around the tabs).
private struct FlatTabChrome: SegmentedTabBarChromeStyle {
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        Text(configuration.title)
            .textStyle(.labelBase600)
            .frame(maxWidth: configuration.isStretched ? .infinity : nil)
    }
}

/// The stock chrome at 60% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultTabChrome: SegmentedTabBarChromeStyle {
    func makeBody(configuration: SegmentedTabBarChromeStyleConfiguration) -> some View {
        DefaultSegmentedTabBarChromeStyle().makeBody(configuration: configuration).opacity(0.6)
    }
}

@MainActor
private final class DividerConfigurationRecorder {
    var values: [DividerStyleConfiguration] = []
}

private struct RecordingDividerStyle: DividerStyle {
    let recorder: DividerConfigurationRecorder

    @MainActor
    func makeBody(configuration: DividerStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return Color.clear.frame(height: 1)
    }
}
