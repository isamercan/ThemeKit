//
//  BadgeChromeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `Badge` + `BadgeChromeStyle`: the default path still renders, the stock
//  style draws the same pixels as the default path, a custom style receives
//  the badge's content, axes and state, and the new slots behave.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class BadgeChromeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(Badge("New")), "plain badge")
        XCTAssertNotNil(render(Badge("Tap") {}), "action badge")
        XCTAssertNotNil(render(Badge("Both").icon(leading: "star.fill", trailing: "xmark")), "icons")
        XCTAssertNotNil(render(Badge("Slots").leading { Circle().frame(width: 6, height: 6) }
            .trailing { Text("2") }), "slots")
    }

    /// `.badgeChromeStyle(.default)` goes through `makeBody`, yet must draw the
    /// same pixels as the untouched default path.
    func testDefaultStyleDrawsTheDefaultPathPixels() {
        let badges: [(String, Badge)] = [
            ("plain", Badge("New")),
            ("tone + icons", Badge("Info").badgeStyle(.info).icon(leading: "star.fill", trailing: "chevron.right")),
            ("solid", Badge("Sold out").badgeStyle(.error).variant(.solid).icon("xmark.circle.fill")),
            ("outline rounded", Badge("Outline").badgeStyle(.success).variant(.outline).badgeShape(.rounded)),
            ("ghost large", Badge("Ghost").badgeStyle(.purple).variant(.ghost).size(.large)),
            ("gradient", Badge("Pro").gradient([.purple, .pink]).variant(.solid)),
            ("highlighted xlarge", Badge("Lifted").badgeStyle(.warning).size(.xlarge).highlighted()),
            ("slot", Badge("Slot").badgeStyle(.turquoise).leading { Circle().frame(width: 6, height: 6) }),
            ("action", Badge("Action") {}.badgeStyle(.info)),
        ]
        for (label, badge) in badges {
            let delta = pixelDelta(badge, badge.badgeChromeStyle(.default))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the default path")
            // Control, same case: a style that forwards to `.default` but
            // changes one thing must be caught by the same comparison.
            let control = pixelDelta(badge, badge.badgeChromeStyle(DimmedDefaultBadgeChrome()))
            XCTAssertNotNil(control, "\(label) (control): renders differ in size or failed")
            XCTAssertGreaterThan(control ?? 0, pixelNoise, "\(label) (control): the comparison saw no difference")
        }
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().badgeChromeStyle.isDefault)
        XCTAssertFalse(AnyBadgeChromeStyle(DefaultBadgeChromeStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesContentAxesAndState() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        let badge = Badge("Sale")
            .badgeStyle(.error)
            .variant(.outline)
            .size(.large)
            .badgeShape(.rounded)
            .icon("tag.fill")
            .gradient([.primary, .turquoise])
            .highlighted()
        _ = render(badge.badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.text, "Sale")
        XCTAssertEqual(c.tone, .error)
        XCTAssertEqual(c.variant, .outline)
        XCTAssertEqual(c.size, .large)
        XCTAssertEqual(c.shape, .rounded)
        XCTAssertEqual(c.gradient, [.primary, .turquoise])
        XCTAssertTrue(c.isHighlighted)
        XCTAssertTrue(c.isEnabled)
        XCTAssertFalse(c.isPressed)
        XCTAssertNotNil(c.leading, "the SF Symbol shorthand is handed over pre-built")
        XCTAssertEqual(c.leadingSystemImage, "tag.fill")
        XCTAssertNil(c.trailing)
        XCTAssertNil(c.trailingSystemImage)
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        _ = render(Badge("Plain").badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.tone, .neutral)
        XCTAssertEqual(c.variant, .soft)
        XCTAssertEqual(c.size, .medium)
        XCTAssertEqual(c.shape, .pill)
        XCTAssertNil(c.gradient)
        XCTAssertFalse(c.isHighlighted)
        XCTAssertNil(c.leading)
        XCTAssertNil(c.trailing)
    }

    func testDisabledStateReachesTheStyle() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        _ = render(Badge("Off").disabled(true).badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).isEnabled, false)
    }

    func testActionBadgeRendersThroughTheStyleUnpressed() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        _ = render(Badge("Tap") {}.badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last, "the action path must still call makeBody")
        XCTAssertEqual(c.text, "Tap")
        XCTAssertFalse(c.isPressed)
        XCTAssertTrue(c.isEnabled)
    }

    // MARK: Slots

    func testSlotsReplaceTheSymbolShorthands() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        let badge = Badge("Both")
            .icon(leading: "star.fill", trailing: "xmark")
            .leading { Text("L") }
            .trailing { Text("T") }
        _ = render(badge.badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNotNil(c.leading)
        XCTAssertNotNil(c.trailing)
        XCTAssertNil(c.leadingSystemImage, "a set slot hides the shorthand's symbol name")
        XCTAssertNil(c.trailingSystemImage, "a set slot hides the shorthand's symbol name")
    }

    func testOneSlotKeepsTheOtherSidesShorthand() throws {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        let badge = Badge("Mixed").icon(leading: "star.fill", trailing: "xmark").leading { Text("L") }
        _ = render(badge.badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertNil(c.leadingSystemImage)
        XCTAssertEqual(c.trailingSystemImage, "xmark")
        XCTAssertNotNil(c.trailing)
    }

    /// On the default path a slot takes the shorthand's place — the badge with
    /// a slot differs from the one with the symbol, and matches a badge that
    /// only has the slot.
    func testSlotReplacesTheSymbolOnTheDefaultPath() {
        let slotOnly = Badge("Slot").leading { Circle().frame(width: 6, height: 6) }
        let slotOverSymbol = Badge("Slot").icon("star.fill").leading { Circle().frame(width: 6, height: 6) }
        let symbolOnly = Badge("Slot").icon("star.fill")
        XCTAssertLessThanOrEqual(pixelDelta(slotOnly, slotOverSymbol) ?? .max, pixelNoise)
        XCTAssertGreaterThan(pixelDelta(slotOverSymbol, symbolOnly) ?? .max, pixelNoise)
    }

    // MARK: Environment reach

    /// A style set on a container reaches the badges ThemeKit composes inside
    /// other components (documented behaviour).
    func testContainerStyleReachesComposedBadges() {
        let recorder = ConfigurationRecorder<BadgeChromeStyleConfiguration>()
        let breakdown = PriceBreakdown(190, currencyCode: "USD").original(240).discountBadge("-21%")
        _ = render(breakdown.badgeChromeStyle(RecordingBadgeChrome(recorder: recorder)))
        XCTAssertTrue(recorder.values.contains { $0.text == "-21%" })
    }

    func testToneExposesItsSemanticHue() {
        XCTAssertEqual(BadgeStyle.info.semantic, .info)
        XCTAssertEqual(BadgeStyle.turquoise.semantic, .turquoise)
    }

    // MARK: Helpers

    private func render<V: View>(_ view: V) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        return renderer.cgImage
    }

    /// The largest per-channel difference between two renders, or `nil` when
    /// either fails to render or their sizes differ. The first render of an SF
    /// Symbol in a process can anti-alias a few pixels one step differently, so
    /// callers treat a delta up to `pixelNoise` as identical; real drift (a
    /// colour, a border, a size) is far larger.
    private func pixelDelta<A: View, B: View>(_ a: A, _ b: B) -> Int? {
        guard let x = render(a), let y = render(b), x.width == y.width, x.height == y.height,
              let dx = x.dataProvider?.data as Data?, let dy = y.dataProvider?.data as Data?,
              dx.count == dy.count else { return nil }
        return zip(dx, dy).reduce(0) { max($0, abs(Int($1.0) - Int($1.1))) }
    }

    private let pixelNoise = 2
}

@MainActor
private final class ConfigurationRecorder<Value> {
    var values: [Value] = []
}

/// The stock chrome at 30% opacity — the control for the pixel-parity loop.
private struct DimmedDefaultBadgeChrome: BadgeChromeStyle {
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        DefaultBadgeChromeStyle().makeBody(configuration: configuration).opacity(0.3)
    }
}

private struct RecordingBadgeChrome: BadgeChromeStyle {
    let recorder: ConfigurationRecorder<BadgeChromeStyleConfiguration>

    @MainActor
    func makeBody(configuration: BadgeChromeStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return HStack {
            configuration.leading
            Text(configuration.text)
            configuration.trailing
        }
    }
}
