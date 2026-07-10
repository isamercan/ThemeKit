import XCTest
@testable import ThemeKit

/// Contract for `HexColor`, the ColorPickerPanel's pure hex ↔ HSBA conversion:
/// known colors format correctly, parsing tolerates `#`/whitespace/case,
/// invalid input is rejected, and the round-trip is stable.
final class HexColorTests: XCTestCase {

    func testKnownColorsFormat() {
        XCTAssertEqual(HexColor.string(HSBAColor(hue: 0, saturation: 1, brightness: 1)), "FF0000")   // red
        XCTAssertEqual(HexColor.string(HSBAColor(hue: 1.0 / 3.0, saturation: 1, brightness: 1)), "00FF00")   // green
        XCTAssertEqual(HexColor.string(HSBAColor(hue: 2.0 / 3.0, saturation: 1, brightness: 1)), "0000FF")   // blue
        XCTAssertEqual(HexColor.string(HSBAColor(hue: 0, saturation: 0, brightness: 1)), "FFFFFF")   // white
        XCTAssertEqual(HexColor.string(HSBAColor(hue: 0, saturation: 0, brightness: 0)), "000000")   // black
    }

    func testParseToleratesHashWhitespaceAndCase() {
        let a = HexColor.hsba(fromHex: "#ff0000", alpha: 1)
        let b = HexColor.hsba(fromHex: "  FF0000 ", alpha: 1)
        XCTAssertNotNil(a); XCTAssertNotNil(b)
        XCTAssertEqual(a?.hue ?? -1, 0, accuracy: 0.001)
        XCTAssertEqual(a?.saturation ?? -1, 1, accuracy: 0.001)
        XCTAssertEqual(a?.brightness ?? -1, 1, accuracy: 0.001)
    }

    func testParseRejectsInvalid() {
        XCTAssertNil(HexColor.hsba(fromHex: "12345", alpha: 1))   // too short
        XCTAssertNil(HexColor.hsba(fromHex: "GGGGGG", alpha: 1))  // non-hex
        XCTAssertNil(HexColor.hsba(fromHex: "", alpha: 1))
    }

    func testParsePreservesAlpha() {
        XCTAssertEqual(HexColor.hsba(fromHex: "3366CC", alpha: 0.4)?.alpha ?? -1, 0.4, accuracy: 0.001)
    }

    func testRoundTripIsStable() {
        for hex in ["3366CC", "FFA500", "7F00FF", "123456", "ABCDEF"] {
            guard let color = HexColor.hsba(fromHex: hex, alpha: 1) else { return XCTFail("parse \(hex)") }
            XCTAssertEqual(HexColor.string(color), hex, "round-trip drift for \(hex)")
        }
    }
}
