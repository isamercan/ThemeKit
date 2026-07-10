import XCTest
import SwiftUI
@testable import ThemeKit

/// Math contract for `HSBAColor`, the working currency of ColorSlider /
/// ColorArea / ColorPickerPanel: every channel clamps to `0…1` on both init and
/// mutation, hue is kept below a full turn so the thumb never wraps to red, and
/// the `Color` bridge round-trips without drift.
final class ColorModelsTests: XCTestCase {

    // MARK: Clamp on init

    func testInitClampsChannelsIntoUnitRange() {
        let c = HSBAColor(hue: 2, saturation: -1, brightness: 5, alpha: -0.2)
        XCTAssertEqual(c.hue, 0.9999, accuracy: 0.0001, "hue clamps below a full turn")
        XCTAssertEqual(c.saturation, 0)
        XCTAssertEqual(c.brightness, 1)
        XCTAssertEqual(c.alpha, 0)
    }

    func testAlphaDefaultsToOpaque() {
        XCTAssertEqual(HSBAColor(hue: 0.5, saturation: 0.5, brightness: 0.5).alpha, 1)
    }

    // MARK: Clamp on mutation (didSet — the ColorSlider drag path)

    func testMutationReclampsThroughDidSet() {
        var c = HSBAColor(hue: 0.5, saturation: 0.5, brightness: 0.5)
        c.brightness = 4
        c.saturation = -3
        c.hue = 1.5
        c.alpha = 9
        XCTAssertEqual(c.brightness, 1)
        XCTAssertEqual(c.saturation, 0)
        XCTAssertEqual(c.hue, 0.9999, accuracy: 0.0001)
        XCTAssertEqual(c.alpha, 1)
    }

    func testHueNeverReachesOneSoTheThumbDoesNotWrap() {
        var c = HSBAColor(hue: 0, saturation: 1, brightness: 1)
        c.hue = 1.0
        XCTAssertLessThan(c.hue, 1.0)
    }

    // MARK: Color bridge

    func testColorRoundTripIsStable() {
        let original = HSBAColor(hue: 0.6, saturation: 0.8, brightness: 0.9, alpha: 0.7)
        let round = HSBAColor(original.color)
        XCTAssertEqual(round.hue, original.hue, accuracy: 0.01)
        XCTAssertEqual(round.saturation, original.saturation, accuracy: 0.01)
        XCTAssertEqual(round.brightness, original.brightness, accuracy: 0.01)
        XCTAssertEqual(round.alpha, original.alpha, accuracy: 0.01)
    }

    func testStaticClampHelpers() {
        XCTAssertEqual(HSBAColor.clampUnit(1.4), 1)
        XCTAssertEqual(HSBAColor.clampUnit(-0.4), 0)
        XCTAssertEqual(HSBAColor.clampUnit(0.3), 0.3)
        XCTAssertEqual(HSBAColor.clampHue(1.0), 0.9999, accuracy: 0.0001)
    }
}
