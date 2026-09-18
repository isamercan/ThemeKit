//
//  ContentContrastTests.swift
//  ThemeKitTests
//
//  Auto-contrast content colors: on-solid foreground must stay legible on light
//  accents (dark text) and dark accents (white text) alike.
//

import XCTest
import SwiftUI
@testable import ThemeKit
@_spi(ThemeKitInternal) @testable import ThemeKitCore   // ColorContrast now lives in Core

final class ContentContrastTests: XCTestCase {
    override func tearDown() {
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)   // restore
        super.tearDown()
    }

    func testLuminanceOrdersWhiteAboveBlack() {
        XCTAssertGreaterThan(ColorContrast.luminance(of: .white), ColorContrast.luminance(of: .black))
        XCTAssertTrue(ColorContrast.contentIsDark(on: .white), "white bg → dark content")
        XCTAssertFalse(ColorContrast.contentIsDark(on: .black), "black bg → white content")
    }

    func testLightPrimaryTakesDarkContent() {
        Theme.shared.apply(ThemeConfig(primaryHex: "e0a82e"))   // bumblebee amber — light
        XCTAssertTrue(ColorContrast.contentIsDark(on: SemanticColor.primary.solid),
                      "a light amber primary should take dark on-solid content")
    }

    func testDarkPrimaryKeepsWhiteContent() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))   // default blue — deep
        XCTAssertFalse(ColorContrast.contentIsDark(on: SemanticColor.primary.solid),
                       "a deep blue primary should keep white on-solid content")
    }

    /// The bug this guards: the fill came from the variant's status token while the text
    /// came from a NAMED foreground token. A brand whose export spells that token as a
    /// marketing color painted, say, orange text on a saturated blue toast. Text is now
    /// derived from the fill for every variant — no named token in between.
    func testToastTextIsDerivedFromItsOwnFill() {
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)
        let theme = Theme.shared
        for variant in [AlertToastType.success, .warning, .danger, .info, .neutral, .accent] {
            XCTAssertEqual(variant.foreground(theme),
                           ColorContrast.content(on: variant.background(theme)),
                           "\(variant) toast text must be the contrast color of its own fill")
        }
    }

    func testWarningStaysDark() {
        // The old hardcoded `.warning → dark` rule is now derived, not special-cased.
        Theme.shared.loadTheme(named: "defaultTheme", dark: false)
        XCTAssertTrue(ColorContrast.contentIsDark(on: SemanticColor.warning.solid),
                      "amber warning is light → dark content")
    }
}
