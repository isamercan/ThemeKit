//
//  CountBadgeStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `CountBadge` + `CountBadgeStyle`: the new public view renders counts, host
//  text and glyphs; the `countBadge(_:)` overlay still draws the same bubble;
//  the stock style draws the same pixels as the default path; a custom style
//  receives the content, axes and environment state; visibility rules hold.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class CountBadgeStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(CountBadge(5)), "count")
        XCTAssertNotNil(render(CountBadge(128)), "overflow")
        XCTAssertNotNil(render(CountBadge("+1")), "text")
        XCTAssertNotNil(render(CountBadge { Image(systemName: "checkmark") }), "glyph")
        XCTAssertNotNil(render(Image(systemName: "bell.fill").countBadge(5)), "overlay")
    }

    func testDefaultBubbleKeepsItsMinimumSize() throws {
        let image = try XCTUnwrap(render(CountBadge(5), scale: 1))
        XCTAssertEqual(image.width, 18)
        XCTAssertEqual(image.height, 18)
    }

    func testHiddenCountsRenderNothing() {
        XCTAssertNil(render(CountBadge(0)), "zero is hidden by default")
        XCTAssertNil(render(CountBadge(-3)), "negative counts are hidden")
        XCTAssertNotNil(render(CountBadge(0).showsZero()), "showsZero reveals the zero")
        XCTAssertNotNil(render(CountBadge("")), "host text is always shown")
    }

    func testDefaultStyleDrawsTheDefaultPathPixels() {
        let badges: [(String, CountBadge)] = [
            ("count", CountBadge(5)),
            ("overflow", CountBadge(128)),
            ("custom cap", CountBadge(12).overflowCount(9)),
            ("zero shown", CountBadge(0).showsZero()),
            ("text", CountBadge("+1").accent(.primary)),
            ("glyph", CountBadge { Image(systemName: "checkmark") }.accent(.success)),
            ("no halo", CountBadge(3).halo(false)),
        ]
        for (label, badge) in badges {
            let delta = pixelDelta(badge, badge.countBadgeStyle(.default))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the default path")
        }
        let host = Color.clear.frame(width: 40, height: 40).countBadge(7).padding(12)
        XCTAssertLessThanOrEqual(pixelDelta(host, host.countBadgeStyle(.default)) ?? .max, pixelNoise,
                                 "overlay: .default drifted from the default path")
    }

    func testHaloIsVisible() {
        XCTAssertGreaterThan(pixelDelta(CountBadge(3), CountBadge(3).halo(false)) ?? .max, pixelNoise)
    }

    func testAccentNilRestoresTheDefault() {
        XCTAssertLessThanOrEqual(pixelDelta(CountBadge(3), CountBadge(3).accent(.primary).accent(nil)) ?? .max,
                                 pixelNoise)
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().countBadgeStyle.isDefault)
        XCTAssertFalse(AnyCountBadgeStyle(DefaultCountBadgeStyle()).isDefault)
    }

    // MARK: Custom style

    func testCountReachesTheStyleFormattedAndRaw() throws {
        let recorder = CountConfigurationRecorder()
        _ = render(CountBadge(128).countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(text(of: c), "99+")
        XCTAssertEqual(c.count, 128)
        XCTAssertEqual(c.accent, .error)
        XCTAssertTrue(c.showsHalo)
        XCTAssertTrue(c.isEnabled)
        XCTAssertEqual(c.controlSize, .regular)
    }

    func testAxesAndEnvironmentStateReachTheStyle() throws {
        let recorder = CountConfigurationRecorder()
        let badge = CountBadge(12)
            .overflowCount(9)
            .accent(.primary)
            .halo(false)
            .controlSize(.small)
            .disabled(true)
        _ = render(badge.countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(text(of: c), "9+")
        XCTAssertEqual(c.accent, .primary)
        XCTAssertFalse(c.showsHalo)
        XCTAssertFalse(c.isEnabled)
        XCTAssertEqual(c.controlSize, .small)
    }

    func testCountIsFormattedWithTheEnvironmentLocale() throws {
        let recorder = CountConfigurationRecorder()
        _ = render(CountBadge(1_234).overflowCount(9_999)
            .countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder))
            .environment(\.locale, Locale(identifier: "de_DE")))
        XCTAssertEqual(text(of: try XCTUnwrap(recorder.values.last)), "1.234")
    }

    func testTextAndGlyphReachTheStyle() throws {
        let recorder = CountConfigurationRecorder()
        _ = render(CountBadge("+1").countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        let textConfiguration = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(text(of: textConfiguration), "+1")
        XCTAssertNil(textConfiguration.count)

        _ = render(CountBadge { Image(systemName: "checkmark") }
            .countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        let glyphConfiguration = try XCTUnwrap(recorder.values.last)
        guard case .glyph = glyphConfiguration.content else {
            return XCTFail("expected glyph content, got \(glyphConfiguration.content)")
        }
        XCTAssertNil(glyphConfiguration.count)
    }

    func testHiddenCountNeverReachesTheStyle() throws {
        let recorder = CountConfigurationRecorder()
        _ = render(CountBadge(0).countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        XCTAssertTrue(recorder.values.isEmpty)

        _ = render(CountBadge(0).showsZero().countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        XCTAssertEqual(text(of: try XCTUnwrap(recorder.values.last)), "0")
    }

    // MARK: Overlay

    func testOverlayForwardsItsParametersThroughTheStyle() throws {
        let recorder = CountConfigurationRecorder()
        let host = Color.clear.frame(width: 30, height: 30)
        _ = render(host.countBadge(0, overflowCount: 5, showZero: true, color: .success)
            .countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        let zero = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(text(of: zero), "0")
        XCTAssertEqual(zero.accent, .success)

        _ = render(host.countBadge(8, overflowCount: 5)
            .countBadgeStyle(RecordingCountBadgeStyle(recorder: recorder)))
        let capped = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(text(of: capped), "5+")
        XCTAssertEqual(capped.count, 8)
        XCTAssertEqual(capped.accent, .error)
    }

    // MARK: Helpers

    private func text(of configuration: CountBadgeStyleConfiguration) -> String? {
        guard case .text(let text) = configuration.content else { return nil }
        return text
    }

    private func render<V: View>(_ view: V, scale: CGFloat = 2) -> CGImage? {
        let renderer = ImageRenderer(content: view)
        renderer.scale = scale
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
private final class CountConfigurationRecorder {
    var values: [CountBadgeStyleConfiguration] = []
}

private struct RecordingCountBadgeStyle: CountBadgeStyle {
    let recorder: CountConfigurationRecorder

    @MainActor
    func makeBody(configuration: CountBadgeStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return Circle().frame(width: 12, height: 12)
    }
}
