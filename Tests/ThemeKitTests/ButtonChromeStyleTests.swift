//
//  ButtonChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  Logic coverage for ThemeButton's chrome door (`ButtonChromeStyle`) and the
//  slots that came with it (`.label { }`, `.loadingIndicator { }`, `.spacing(_:)`):
//  the built-in chrome still renders and `.default` reproduces it pixel for
//  pixel, a custom chrome receives the resolved configuration, and the slots
//  land where the content model says — on both chrome paths.
//

import SwiftUI
import XCTest
@testable import ThemeKit

/// What a render touched: the configurations a chrome was asked to draw, and
/// the probe views whose bodies were evaluated.
@MainActor
private final class RenderLog {
    var configurations: [ButtonChromeStyleConfiguration] = []
    var seen: Set<String> = []
}

/// A chrome that records its configuration and draws the bare label.
private struct RecordingChrome: ButtonChromeStyle {
    let log: RenderLog
    func makeBody(configuration: ButtonChromeStyleConfiguration) -> some View {
        log.configurations.append(configuration)
        return configuration.label
    }
}

/// Marks its tag as seen whenever its body is evaluated.
private struct Probe: View {
    let tag: String
    let log: RenderLog
    var body: some View {
        log.seen.insert(tag)
        return Text(tag)
    }
}

/// Reads the environment chrome style ThemeButton would see.
private struct ChromeStyleProbe: View {
    let log: RenderLog
    @Environment(\.buttonChromeStyle) private var style
    var body: some View {
        log.seen.insert(style.isDefault ? "default" : "custom")
        return Color.clear
    }
}

@available(iOS 16.0, macOS 13.0, *)   // ImageRenderer (matches the sibling render suites)
@MainActor
final class ButtonChromeStyleTests: XCTestCase {

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    // MARK: Built-in path

    func testBuiltInChromeStillRenders() throws {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        let buttons: [ThemeButton] = [
            ThemeButton("Book") {},
            ThemeButton("Soft") {}.variant(.soft).color(.success).size(.large),
            ThemeButton { }.icon(leading: "heart").shape(.circle),
            ThemeButton("Saving") {}.loading().spinnerPlacement(.trailing),
            ThemeButton("Pay") {}.label { Text("Pay now") }.loadingIndicator { Text("…") }.spacing(.sm),
        ]
        for button in buttons {
            XCTAssertNotNil(try pixels(button))
        }
    }

    /// `.buttonChromeStyle(.default)` goes through the style door, yet must
    /// draw exactly what the built-in chrome draws.
    func testDefaultChromeThroughTheDoorMatchesTheBuiltInPixels() throws {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        // Non-vacuity: the renderer must tell chromes and variants apart.
        let solid = ThemeButton("Solid") {}
        XCTAssertNotEqual(try pixels(solid), try pixels(solid.variant(.outline)))
        XCTAssertNotEqual(try pixels(solid), try pixels(solid.buttonChromeStyle(RecordingChrome(log: RenderLog()))))
        // …and must see the tint a tint-reading slot draws with.
        let tintReading = ThemeButton("Tint") {}.prefix { Circle().fill(.tint).frame(width: 12, height: 12) }
        XCTAssertNotEqual(try pixels(tintReading), try pixels(tintReading.tint(.red)))

        let cases: [(String, ThemeButton)] = [
            ("solid", ThemeButton("Solid") {}),
            ("soft", ThemeButton("Soft") {}.variant(.soft).color(.success)),
            ("outline", ThemeButton("Outline") {}.variant(.outline).color(.error)),
            ("ghost", ThemeButton("Ghost") {}.variant(.ghost)),
            ("link", ThemeButton("Link") {}.variant(.link)),
            ("neutral", ThemeButton("Neutral") {}.color(.neutral).shape(.pill)),
            ("circle", ThemeButton { }.icon(leading: "heart.fill").shape(.circle).color(.error)),
            ("compact icon-only", ThemeButton { }.icon(leading: "plus").iconOnly().density(.compact).size(.small)),
            ("icons", ThemeButton("Next") {}.icon(leading: "star", trailing: "arrow.right").size(.xsmall)),
            ("label slot", ThemeButton("Pay") {}.label { Text("Pay \(Text("now").bold())") }),
            ("custom label", ThemeButton { } label: { HStack { Image(systemName: "cart"); Text("Cart") } }),
            ("full width", ThemeButton("Block") {}.fullWidth()),
            ("spacing", ThemeButton("Wide") {}.icon(leading: "star").spacing(.lg)),
            // The stock chrome tints only the loading indicator, as the
            // built-in chrome does — a tint-reading slot looks the same.
            ("tint-reading prefix", ThemeButton("Tint") {}.prefix { Circle().fill(.tint).frame(width: 12, height: 12) }),
            ("tinted indicator", ThemeButton("Saving") {}.loading()
                .loadingIndicator { Circle().fill(.tint).frame(width: 12, height: 12) }),
            ("tinted inline indicator", ThemeButton("Saving") {}.loading().spinnerPlacement(.leading)
                .loadingIndicator { Circle().fill(.tint).frame(width: 12, height: 12) }),
        ]
        for (name, button) in cases {
            XCTAssertEqual(try pixels(button), try pixels(button.buttonChromeStyle(.default)), name)
            XCTAssertEqual(
                try pixels(button.disabled(true)),
                try pixels(button.disabled(true).buttonChromeStyle(.default)),
                "\(name), disabled"
            )
        }
    }

    // MARK: Environment plumbing

    func testEnvironmentDefaultIsMarkedAndASetStyleIsNot() {
        XCTAssertTrue(EnvironmentValues().buttonChromeStyle.isDefault)

        let log = RenderLog()
        render(ChromeStyleProbe(log: log))
        render(ChromeStyleProbe(log: log).buttonChromeStyle(.default))
        XCTAssertEqual(log.seen, ["default", "custom"], "`.default` must route through the door, unmarked")
    }

    func testAStyleSetOnAContainerReachesNestedButtons() {
        let log = RenderLog()
        render(
            VStack {
                HStack { ThemeButton("One") {} }
                ThemeButton("Two") {}
            }
            .buttonChromeStyle(RecordingChrome(log: log))
        )
        XCTAssertEqual(Set(log.configurations.compactMap(\.title)), ["One", "Two"])
    }

    // MARK: Configuration

    func testCustomChromeReceivesTheResolvedAxes() throws {
        let log = RenderLog()
        render(
            ThemeButton("Pay") {}
                .variant(.outline).color(.success).size(.large).shape(.pill)
                .density(.compact).fullWidth()
                .buttonChromeStyle(RecordingChrome(log: log))
        )
        let configuration = try XCTUnwrap(log.configurations.last)
        XCTAssertEqual(configuration.title, "Pay")
        XCTAssertEqual(configuration.variant, .outline)
        XCTAssertEqual(configuration.color, .success)
        XCTAssertEqual(configuration.size, .large)
        XCTAssertEqual(configuration.shape, .pill)
        XCTAssertEqual(configuration.density, .compact)
        XCTAssertTrue(configuration.isFullWidth)
        XCTAssertFalse(configuration.isIconOnly)
        XCTAssertTrue(configuration.isEnabled)
        XCTAssertFalse(configuration.isLoading)
        XCTAssertFalse(configuration.isPressed, "at rest")
        XCTAssertFalse(configuration.isFocused, "at rest")
    }

    func testCustomChromeReceivesTheResolvedState() throws {
        let log = RenderLog()
        render(
            ThemeButton { }
                .icon(leading: "heart").shape(.circle).loading()
                .disabled(true)
                .buttonChromeStyle(RecordingChrome(log: log))
        )
        let configuration = try XCTUnwrap(log.configurations.last)
        XCTAssertNil(configuration.title)
        XCTAssertTrue(configuration.isIconOnly)
        XCTAssertTrue(configuration.isLoading)
        XCTAssertFalse(configuration.isEnabled)
        XCTAssertEqual(configuration.shape, .circle)
        XCTAssertFalse(configuration.isFullWidth)

        // `.iconOnly()` on a rounded button is icon-only too.
        render(ThemeButton { }.icon(leading: "plus").iconOnly().buttonChromeStyle(RecordingChrome(log: log)))
        XCTAssertEqual(log.configurations.last?.isIconOnly, true)
        XCTAssertEqual(log.configurations.last?.shape, .rounded)
    }

    /// Color: explicit ?? subtree `componentDefaults` accent ?? `.primary`.
    /// Size: explicit ?? enclosing `ButtonGroup` size ?? `.medium`.
    func testCustomChromeReceivesTheCascadedColorAndSize() {
        let log = RenderLog()
        let chrome = RecordingChrome(log: log)
        render(ThemeButton("Plain") {}.buttonChromeStyle(chrome))
        render(ThemeButton("Subtree") {}.componentDefaults(accent: .turquoise).buttonChromeStyle(chrome))
        render(ThemeButton("Explicit") {}.color(.error).componentDefaults(accent: .turquoise).buttonChromeStyle(chrome))
        render(ThemeButton("Grouped") {}.environment(\.buttonGroupControlSize, .small).buttonChromeStyle(chrome))
        render(ThemeButton("Own size") {}.size(.xlarge).environment(\.buttonGroupControlSize, .small).buttonChromeStyle(chrome))

        let byTitle = Dictionary(log.configurations.map { ($0.title ?? "", $0) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(byTitle["Plain"]?.color, .primary)
        XCTAssertEqual(byTitle["Plain"]?.size, .medium)
        XCTAssertEqual(byTitle["Plain"]?.variant, .solid)
        XCTAssertEqual(byTitle["Plain"]?.density, .regular)
        XCTAssertEqual(byTitle["Subtree"]?.color, .turquoise)
        XCTAssertEqual(byTitle["Explicit"]?.color, .error)
        XCTAssertEqual(byTitle["Grouped"]?.size, .small)
        XCTAssertEqual(byTitle["Own size"]?.size, .xlarge)
    }

    /// Motion reaches the chrome resolved — the chrome never reads the switch.
    func testCustomChromeReceivesResolvedMotion() {
        let log = RenderLog()
        let chrome = RecordingChrome(log: log)
        render(ThemeButton("Moving") {}.buttonChromeStyle(chrome))
        render(ThemeButton("Still") {}.microAnimations(false).buttonChromeStyle(chrome))
        let byTitle = Dictionary(log.configurations.map { ($0.title ?? "", $0) }, uniquingKeysWith: { _, last in last })
        XCTAssertEqual(byTitle["Moving"]?.isMotionEnabled, true)
        XCTAssertEqual(byTitle["Still"]?.isMotionEnabled, false)
    }

    // MARK: Slots — `.label { }` / `.loadingIndicator { }` on both chrome paths

    func testSlotModifiersStayOnThemeButton() {
        // Compile-time: each slot returns ThemeButton, so chaining continues.
        let button: ThemeButton = ThemeButton("Pay") {}
            .label { Text("Pay") }
            .loadingIndicator { Text("…") }
            .spacing(.sm)
            .variant(.soft)
        XCTAssertNotNil(button)

        // `.indicator { }` is not a ThemeButton member: on a button it is the
        // generic `View.indicator(_:content:)` corner overlay, as in 1.4.0.
        let overlaid: Any = ThemeButton("Inbox") {}.indicator { Text("3") }
        XCTAssertFalse(overlaid is ThemeButton, "`.indicator { }` must resolve to the View corner overlay")
    }

    /// 1.4.0 call sites keep working: `.indicator { }` on a ThemeButton hangs
    /// its content on the corner while the button is *not* loading — on the
    /// built-in chrome and under a custom chrome alike.
    func testIndicatorWithoutAPositionStaysTheCornerOverlay() {
        for isCustom in [false, true] {
            let log = RenderLog()
            let overlaid = ThemeButton("Inbox") {}.indicator { Probe(tag: "badge", log: log) }
            if isCustom {
                render(overlaid.buttonChromeStyle(RecordingChrome(log: log)))
                XCTAssertEqual(log.configurations.last?.title, "Inbox", "the custom chrome drew the button")
                XCTAssertEqual(log.configurations.last?.isLoading, false)
            } else {
                render(overlaid)
            }
            XCTAssertTrue(log.seen.contains("badge"), "\(isCustom ? "custom" : "built-in") chrome: the overlay must draw")
        }
    }

    /// With a position, `.indicator` is the generic corner overlay too.
    func testPositionedIndicatorStaysTheCornerOverlay() {
        let log = RenderLog()
        render(ThemeButton("Inbox") {}.indicator(.topTrailing) { Probe(tag: "badge", log: log) })
        XCTAssertTrue(log.seen.contains("badge"))
    }

    func testLabelSlotReplacesOnlyTheTitle() {
        assertRendered(
            { log in
                ThemeButton("Pay") {}
                    .label { Probe(tag: "slot", log: log) }
                    .prefix { Probe(tag: "prefix", log: log) }
                    .suffix { Probe(tag: "suffix", log: log) }
                    .loadingIndicator { Probe(tag: "indicator", log: log) }
            },
            shows: ["slot", "prefix", "suffix"],
            hides: ["indicator"]
        )
    }

    func testLoadingIndicatorReplacesTheLabelWhileLoading() {
        assertRendered(
            { log in
                ThemeButton("Pay") {}
                    .label { Probe(tag: "slot", log: log) }
                    .loadingIndicator { Probe(tag: "indicator", log: log) }
                    .loading()
            },
            shows: ["indicator"],
            hides: ["slot"]
        )
    }

    func testLoadingIndicatorSitsBesideTheSlotWithSpinnerPlacement() {
        for edge in [HorizontalEdge.leading, .trailing] {
            assertRendered(
                { log in
                    ThemeButton("Pay") {}
                        .label { Probe(tag: "slot", log: log) }
                        .loadingIndicator { Probe(tag: "indicator", log: log) }
                        .loading().spinnerPlacement(edge)
                },
                shows: ["slot", "indicator"],
                hides: []
            )
        }
    }

    func testLoadingIndicatorAlsoServesTheCustomLabelInit() {
        assertRendered(
            { log in
                ThemeButton { } label: { Probe(tag: "row", log: log) }
                    .loadingIndicator { Probe(tag: "indicator", log: log) }
                    .loading().spinnerPlacement(.trailing)
            },
            shows: ["row", "indicator"],
            hides: []
        )
    }

    func testCustomLabelInitWinsOverTheLabelSlot() {
        assertRendered(
            { log in
                ThemeButton { } label: { Probe(tag: "row", log: log) }
                    .label { Probe(tag: "slot", log: log) }
            },
            shows: ["row"],
            hides: ["slot"]
        )
    }

    func testIconOnlyIgnoresTheLabelSlot() {
        assertRendered(
            { log in
                ThemeButton("Like") {}
                    .iconOnly()
                    .prefix { Probe(tag: "glyph", log: log) }
                    .label { Probe(tag: "slot", log: log) }
            },
            shows: ["glyph"],
            hides: ["slot"]
        )
    }

    func testLabelSlotRendersWithoutATitle() {
        assertRendered(
            { log in ThemeButton { }.label { Probe(tag: "slot", log: log) } },
            shows: ["slot"],
            hides: []
        )
    }

    // MARK: Shared stock paint + metrics

    func testDensityMetricsFollowTheRamps() {
        for size in ButtonSize.allCases {
            XCTAssertEqual(size.height(for: .regular), size.height)
            XCTAssertEqual(size.height(for: .compact), size.compactHeight)
            XCTAssertEqual(size.horizontalPadding(for: .regular), size.horizontalPadding)
            XCTAssertEqual(size.horizontalPadding(for: .compact), size.compactHorizontalPadding)
            XCTAssertEqual(size.textStyle(for: .regular), size.textStyle)
            XCTAssertEqual(size.textStyle(for: .compact), size.compactTextStyle)
            XCTAssertEqual(size.fontSize(for: .regular), size.fontSize)
            XCTAssertEqual(size.fontSize(for: .compact), size.compactFontSize)
        }
    }

    func testStockPaintRules() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        func paint(_ variant: ButtonVariant, _ color: SemanticColor = .primary, enabled: Bool = true) -> ButtonChromePaint {
            ButtonChromePaint(theme: Theme.shared, color: color, variant: variant, shape: .rounded, isEnabled: enabled)
        }
        // Only the outline variant strokes — enabled or not.
        for variant in ButtonVariant.allCases where variant != .outline {
            XCTAssertNil(paint(variant).stroke, "\(variant)")
        }
        XCTAssertNotNil(paint(.outline).stroke)
        XCTAssertNotNil(paint(.outline, enabled: false).stroke)
        // Transparent fills for the bordered / bare variants.
        XCTAssertEqual(paint(.outline).background, .clear)
        XCTAssertEqual(paint(.ghost).background, .clear)
        XCTAssertEqual(paint(.link).background, .clear)
        // Disabled and neutral-solid buttons don't change fill on press.
        for variant in ButtonVariant.allCases {
            XCTAssertEqual(paint(variant, enabled: false).pressedBackground, paint(variant, enabled: false).background)
        }
        XCTAssertEqual(paint(.solid, .neutral).pressedBackground, paint(.solid, .neutral).background)
        XCTAssertNotEqual(paint(.solid).pressedBackground, paint(.solid).background)
        // Disabled text reads the disabled token for every variant.
        for variant in ButtonVariant.allCases {
            XCTAssertEqual(paint(variant, enabled: false).foreground, Theme.shared.text(.textDisabled))
        }
    }

    // MARK: Helpers

    /// Renders the button on the built-in chrome and under a custom chrome, and
    /// checks which probes were (not) drawn on each path.
    private func assertRendered(
        _ make: (RenderLog) -> ThemeButton,
        shows: Set<String>,
        hides: Set<String>,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for isCustom in [false, true] {
            let log = RenderLog()
            let button = make(log)
            if isCustom {
                render(button.buttonChromeStyle(RecordingChrome(log: log)))
            } else {
                render(button)
            }
            let path = isCustom ? "custom chrome" : "built-in chrome"
            XCTAssertTrue(shows.isSubset(of: log.seen), "\(path): expected \(shows), saw \(log.seen)", file: file, line: line)
            XCTAssertTrue(hides.isDisjoint(with: log.seen), "\(path): \(hides) must not render, saw \(log.seen)", file: file, line: line)
        }
    }

    private func render(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 320, height: 120))
        _ = renderer.cgImage
    }

    /// Raw rendered pixels (same size + scale ⇒ comparable bytes; mirrors
    /// ControllableStateTests.pixels). Rendered twice, keeping the second: the
    /// first render of new content can differ by a few antialiased bytes
    /// (glyph / path warm-up), which would make the equality checks flaky.
    private func pixels(_ view: some View) throws -> Data {
        let content = view.frame(width: 320, height: 90)
        let warmUp = ImageRenderer(content: content)
        warmUp.scale = 2
        _ = warmUp.cgImage
        let renderer = ImageRenderer(content: content)
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage, "no render")
        return try XCTUnwrap(image.dataProvider?.data, "no backing data") as Data
    }
}
