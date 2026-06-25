//
//  ThemeGeneratorRobustnessTests.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Stresses the runtime token generator: arbitrary accents produce a palette as
//  complete as the baked seed, scales actually scale, applying bumps the
//  revision, and malformed input doesn't crash.
//

import XCTest
import SwiftUI
@testable import GlobalUIComponents

final class ThemeGeneratorRobustnessTests: XCTestCase {

    private func nonClearPaletteCount(_ t: Theme) -> Int {
        Theme.PaletteColorKey.allCases.filter { t.palette($0) != .clear }.count
    }

    func testGeneratedPaletteIsAsCompleteAsBakedSeed() {
        let baked = Theme(); baked.loadTheme(named: "defaultTheme")
        let expected = nonClearPaletteCount(baked)
        XCTAssertGreaterThan(expected, 0)

        for hex in ["7C3AED", "FF0000", "00AA88", "FF8800", "123456"] {
            let t = Theme()
            t.apply(ThemeConfig(primaryHex: hex))
            XCTAssertEqual(nonClearPaletteCount(t), expected, "accent \(hex) palette incomplete")
            XCTAssertNotEqual(t.foreground(.fgHero), .clear, "accent \(hex) fgHero")
        }
    }

    func testRadiusAndSpacingScalesApply() {
        let t = Theme.shared
        t.apply(ThemeConfig(primaryHex: "056BFD", radiusScale: 1, spacingScale: 1))
        let r1 = Theme.RadiusKey.md.value
        let s1 = Theme.SpacingKey.md.value
        XCTAssertGreaterThan(r1, 0); XCTAssertGreaterThan(s1, 0)

        t.apply(ThemeConfig(primaryHex: "056BFD", radiusScale: 2, spacingScale: 2))
        XCTAssertEqual(Theme.RadiusKey.md.value, r1 * 2, accuracy: 1)
        XCTAssertEqual(Theme.SpacingKey.md.value, s1 * 2, accuracy: 1)

        t.loadTheme(named: "defaultTheme")   // restore shared state
    }

    func testApplyIncrementsRevision() {
        let before = Theme.shared.revision
        Theme.shared.apply(ThemeConfig(primaryHex: "FF8800"))
        XCTAssertGreaterThan(Theme.shared.revision, before)
        Theme.shared.loadTheme(named: "defaultTheme")
    }

    func testMalformedAccentDoesNotCrash() {
        let t = Theme()
        // Garbage hex must be handled gracefully (no crash); we don't assert color.
        t.apply(ThemeConfig(primaryHex: "zzzzzz"))
        t.apply(ThemeConfig(primaryHex: ""))
        t.apply(ThemeConfig(primaryHex: "#GGG"))
        XCTAssertTrue(true)
    }

    func testDarkGenerationDiffersFromLight() {
        let light = Theme(); light.apply(ThemeConfig(primaryHex: "056BFD", dark: false))
        let dark = Theme();  dark.apply(ThemeConfig(primaryHex: "056BFD", dark: true))
        XCTAssertNotEqual(light.background(.bgWhite), dark.background(.bgWhite),
                          "dark generation should invert surfaces")
    }
}
