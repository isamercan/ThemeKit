//
//  IconTileStyleTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 16.09.2026.
//
//  `IconTile` + `IconTileStyle`: the default path still renders (and keeps its
//  24pt floor), the stock style draws the same pixels, a custom style receives
//  the glyph, sizes and axes, and the glyph init / tile shape behave.
//

import XCTest
import SwiftUI
@testable import ThemeKit

@available(iOS 16.0, macOS 13.0, *)
@MainActor
final class IconTileStyleTests: XCTestCase {

    override func setUp() {
        super.setUp()
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    // MARK: Default path

    func testDefaultPathStillRenders() {
        XCTAssertNotNil(render(IconTile("airplane")), "SF Symbol")
        XCTAssertNotNil(render(IconTile { Text("A") }), "glyph init")
        XCTAssertNotNil(render(IconTile("bell.fill").tileShape(.circle)), "circle")
    }

    func testDefaultPathKeepsTheSizeFloor() throws {
        let small = try XCTUnwrap(render(IconTile("bell.fill").size(16), scale: 1))
        XCTAssertEqual(small.width, 24)
        XCTAssertEqual(small.height, 24)
        let sized = try XCTUnwrap(render(IconTile("bell.fill").size(40), scale: 1))
        XCTAssertEqual(sized.width, 40)
        let unset = try XCTUnwrap(render(IconTile("bell.fill"), scale: 1))
        XCTAssertEqual(unset.width, 46)
    }

    func testDefaultStyleDrawsTheDefaultPathPixels() {
        let tiles: [(String, IconTile)] = [
            ("neutral", IconTile("airplane")),
            ("accent", IconTile("suitcase.fill").accent(.turquoise)),
            ("sized", IconTile("bell.fill").accent(.warning).size(40)),
            ("floored", IconTile("bell.fill").size(10).iconSize(4)),
            ("tokens", IconTile("mappin").background(.bgSecondaryLight).iconColor(.textPrimary).cornerRadius(.box)),
            ("circle", IconTile("heart.fill").accent(.pink).tileShape(.circle)),
            ("glyph", IconTile { Text("A") }.accent(.info)),
        ]
        for (label, tile) in tiles {
            let delta = pixelDelta(tile, tile.iconTileStyle(.default))
            XCTAssertNotNil(delta, "\(label): renders differ in size or failed")
            XCTAssertLessThanOrEqual(delta ?? .max, pixelNoise, "\(label): .default drifted from the default path")
        }
    }

    func testCircleDiffersFromRounded() {
        let tile = IconTile("bell.fill").accent(.info)
        XCTAssertGreaterThan(pixelDelta(tile, tile.tileShape(.circle)) ?? .max, pixelNoise)
        XCTAssertLessThanOrEqual(pixelDelta(tile, tile.tileShape(.rounded)) ?? .max, pixelNoise,
                                 ".rounded is today's look")
    }

    func testEnvironmentDefaultIsMarkedAndExplicitStylesAreNot() {
        XCTAssertTrue(EnvironmentValues().iconTileStyle.isDefault)
        XCTAssertFalse(AnyIconTileStyle(DefaultIconTileStyle()).isDefault)
    }

    // MARK: Custom style

    func testCustomStyleReceivesSizesAndAxes() throws {
        let recorder = TileConfigurationRecorder()
        let tile = IconTile("bell.fill")
            .size(16)
            .iconSize(9)
            .accent(.warning)
            .cornerRadius(.box)
            .tileShape(.circle)
        _ = render(tile.iconTileStyle(RecordingIconTileStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.systemImage, "bell.fill")
        XCTAssertEqual(c.requestedSize, 16, "the style sees the caller's size")
        XCTAssertEqual(c.size, 24, "…and the floored size the default chrome draws")
        XCTAssertEqual(c.iconSize, 9)
        XCTAssertEqual(c.cornerRadius, .box)
        XCTAssertEqual(c.shape, .circle)
        XCTAssertEqual(c.accent, .warning)
        XCTAssertEqual(c.backgroundKey, .bgElevatorTertiary)
        XCTAssertNil(c.iconColorKey)
        XCTAssertTrue(c.isEnabled)
    }

    func testDefaultsReachTheStyle() throws {
        let recorder = TileConfigurationRecorder()
        _ = render(IconTile("airplane").background(.bgSecondaryLight).iconColor(.textPrimary)
            .iconTileStyle(RecordingIconTileStyle(recorder: recorder)))

        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.requestedSize, 46)
        XCTAssertEqual(c.size, 46)
        XCTAssertEqual(c.iconSize, 18)
        XCTAssertEqual(c.cornerRadius, .selector)
        XCTAssertEqual(c.shape, .rounded)
        XCTAssertNil(c.accent)
        XCTAssertEqual(c.backgroundKey, .bgSecondaryLight)
        XCTAssertEqual(c.iconColorKey, .textPrimary)
    }

    func testIconSizeKeepsItsFloor() throws {
        let recorder = TileConfigurationRecorder()
        _ = render(IconTile("airplane").iconSize(2).iconTileStyle(RecordingIconTileStyle(recorder: recorder)))
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).iconSize, 8)
    }

    func testGlyphInitHasNoSymbolName() throws {
        let recorder = TileConfigurationRecorder()
        _ = render(IconTile { Text("A") }.iconTileStyle(RecordingIconTileStyle(recorder: recorder)))
        XCTAssertNil(try XCTUnwrap(recorder.values.last).systemImage)
    }

    func testDisabledStateReachesTheStyle() throws {
        let recorder = TileConfigurationRecorder()
        _ = render(IconTile("airplane").disabled(true).iconTileStyle(RecordingIconTileStyle(recorder: recorder)))
        XCTAssertEqual(try XCTUnwrap(recorder.values.last).isEnabled, false)
    }

    /// A custom style may honour sizes under the default floor.
    func testCustomStyleCanDrawBelowTheFloor() throws {
        let recorder = TileConfigurationRecorder()
        let image = try XCTUnwrap(render(IconTile("bell.fill").size(16)
            .iconTileStyle(RecordingIconTileStyle(recorder: recorder)), scale: 1))
        XCTAssertEqual(image.width, 16)
    }

    // MARK: Environment reach

    func testContainerStyleReachesComposedTiles() throws {
        let recorder = TileConfigurationRecorder()
        _ = render(SuggestionRow("Paris").iconTileStyle(RecordingIconTileStyle(recorder: recorder)))
        let c = try XCTUnwrap(recorder.values.last)
        XCTAssertEqual(c.systemImage, "mappin")
        XCTAssertEqual(c.iconSize, 17)
    }

    // MARK: Helpers

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
private final class TileConfigurationRecorder {
    var values: [IconTileStyleConfiguration] = []
}

/// Records the configuration and draws the glyph at the requested size.
private struct RecordingIconTileStyle: IconTileStyle {
    let recorder: TileConfigurationRecorder

    @MainActor
    func makeBody(configuration: IconTileStyleConfiguration) -> some View {
        recorder.values.append(configuration)
        return configuration.glyph
            .frame(width: configuration.requestedSize, height: configuration.requestedSize)
    }
}
