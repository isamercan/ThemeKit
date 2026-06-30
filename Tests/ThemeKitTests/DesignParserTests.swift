import XCTest
@testable import ThemeKit

final class DesignParserTests: XCTestCase {
    private let parser = HeuristicDesignParser()

    // MARK: - Structured blocks

    func testThemekitBlockWins() {
        let md = """
        # Some App
        Lots of prose that says light and rounded to try to mislead the heuristics.

        ```themekit
        primary: #5E6AD2
        base: #0E0E10
        secondary: #8A93B5
        accent: #7C8AFF
        dark: true
        tint: 0.05
        radiusScale: 0.8
        spacingScale: 0.85
        shadowScale: 0.4
        font: System
        ```
        """
        let r = parser.parse(md)
        XCTAssertEqual(r.confidence, .high)
        XCTAssertEqual(r.config.primaryHex, "5e6ad2")
        XCTAssertEqual(r.config.baseHex, "0e0e10")
        XCTAssertEqual(r.config.secondaryHex, "8a93b5")
        XCTAssertEqual(r.config.accentHex, "7c8aff")
        XCTAssertTrue(r.config.dark)
        XCTAssertEqual(r.config.tint, 0.05, accuracy: 0.0001)
        XCTAssertEqual(r.config.radiusScale, 0.8, accuracy: 0.0001)
        XCTAssertEqual(r.config.font, "System")
    }

    func testJSONBlockDecodesToConfig() throws {
        let cfg = ThemeConfig(primaryHex: "ff0066", baseHex: "101014", dark: true, font: "SystemMono")
        let json = String(data: try cfg.jsonData(), encoding: .utf8)!
        let md = """
        # JSON spec
        ```json
        \(json)
        ```
        """
        let r = parser.parse(md)
        XCTAssertEqual(r.confidence, .high)
        XCTAssertEqual(r.config, cfg)
    }

    func testFrontMatterKeyValues() {
        let md = """
        ---
        title: My Theme
        primary: #112233
        dark: yes
        radius: 1.4
        ---
        # My Theme
        body text
        """
        let r = parser.parse(md)
        XCTAssertEqual(r.confidence, .high)
        XCTAssertEqual(r.config.primaryHex, "112233")
        XCTAssertTrue(r.config.dark)
        XCTAssertEqual(r.config.radiusScale, 1.4, accuracy: 0.0001)
    }

    // MARK: - Prose heuristics

    func testLabeledHexExtraction() {
        let md = """
        Our primary brand color is #5E6AD2.
        The background surface is #0E0E10.
        The secondary color is #8A93B5 and the accent highlight is #7C8AFF.
        """
        let r = parser.parse(md)
        XCTAssertEqual(r.config.primaryHex, "5e6ad2")
        XCTAssertEqual(r.config.baseHex, "0e0e10")
        XCTAssertEqual(r.config.secondaryHex, "8a93b5")
        XCTAssertEqual(r.config.accentHex, "7c8aff")
    }

    func testUnlabeledFirstHexBecomesPrimaryWithWarning() {
        let r = parser.parse("Brand vibe: #abcdef somewhere in here.")
        XCTAssertEqual(r.config.primaryHex, "abcdef")
        XCTAssertFalse(r.warnings.isEmpty)
    }

    func testThreeDigitHexExpands() {
        let r = parser.parse("primary color #f0c")
        XCTAssertEqual(r.config.primaryHex, "ff00cc")
    }

    func testDarkKeyword() {
        let r = parser.parse("A sleek dark mode interface. primary #336699")
        XCTAssertTrue(r.config.dark)
    }

    func testDarkInferredFromBaseLuminance() {
        // No explicit dark/light words, but the base is near-black → infer dark.
        let r = parser.parse("background surface is #0a0a0a, primary #3366ff")
        XCTAssertTrue(r.config.dark)
        XCTAssertTrue(r.warnings.contains { $0.lowercased().contains("luminance") })
    }

    func testRoundednessMapsToRadiusScale() {
        XCTAssertLessThan(parser.parse("sharp square corners, primary #111111").config.radiusScale, 0.5)
        XCTAssertGreaterThan(parser.parse("fully rounded pill shapes, primary #111111").config.radiusScale, 1.2)
    }

    func testDensityMapsToSpacingScale() {
        XCTAssertLessThan(parser.parse("compact dense layout, primary #111111").config.spacingScale, 1.0)
        XCTAssertGreaterThan(parser.parse("airy spacious layout, primary #111111").config.spacingScale, 1.1)
    }

    func testShadowMapsToShadowScale() {
        XCTAssertEqual(parser.parse("flat, no shadows, primary #111111").config.shadowScale, 0, accuracy: 0.0001)
        XCTAssertGreaterThan(parser.parse("elevated floating cards, primary #111111").config.shadowScale, 1.0)
    }

    func testFontKeywords() {
        XCTAssertEqual(parser.parse("uses a monospace code font, primary #111111").config.font, "SystemMono")
        XCTAssertEqual(parser.parse("a serif editorial feel, primary #111111").config.font, "SystemSerif")
        XCTAssertEqual(parser.parse("the native system font, primary #111111").config.font, "System")
    }

    // MARK: - Totality

    func testEmptyInputReturnsSeedAndWarns() {
        let seed = ThemeConfig(primaryHex: "abc123", dark: true)
        let r = parser.parse("   \n\n  ", seed: seed)
        XCTAssertEqual(r.config, seed)
        XCTAssertEqual(r.confidence, .low)
        XCTAssertFalse(r.warnings.isEmpty)
    }

    func testUnspecifiedFieldsKeepSeed() {
        let seed = ThemeConfig(primaryHex: "000000", font: "Montserrat", radiusScale: 1.7)
        // Only specifies a primary; radius/font should stay seeded.
        let r = parser.parse("primary #abcdef", seed: seed)
        XCTAssertEqual(r.config.primaryHex, "abcdef")
        XCTAssertEqual(r.config.radiusScale, 1.7, accuracy: 0.0001)
        XCTAssertEqual(r.config.font, "Montserrat")
    }
}
