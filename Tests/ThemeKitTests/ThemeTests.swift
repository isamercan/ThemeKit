import XCTest
import SwiftUI
@testable import ThemeKit

final class ThemeTests: XCTestCase {

    func testDefaultThemeLoadsSemanticColors() {
        let theme = Theme()
        // fg-hero (#056bfd) is defined in defaultTheme.json — must not fall back to clear.
        XCTAssertNotEqual(theme.foreground(.fgHero), .clear)
        XCTAssertNotEqual(theme.background(.bgHero), .clear)
        XCTAssertNotEqual(theme.text(.textPrimary), .clear)
    }

    func testRadiusTokensResolve() {
        Theme.shared.loadTheme(named: "defaultTheme")
        XCTAssertEqual(Theme.RadiusKey.sm.value, 8)
        XCTAssertEqual(Theme.RadiusKey.md.value, 16)
        XCTAssertEqual(Theme.RadiusKey.base.value, 24)
        XCTAssertEqual(Theme.RadiusKey.xl4.value, 64)
    }

    func testSpacingTokensResolve() {
        Theme.shared.loadTheme(named: "defaultTheme")
        XCTAssertEqual(Theme.SpacingKey.xs.value, 4)
        XCTAssertEqual(Theme.SpacingKey.md.value, 16)
        XCTAssertEqual(Theme.SpacingKey.base.value, 24)
    }

    func testSwitchingThemeChangesHeroAccent() {
        let theme = Theme()
        theme.loadTheme(named: "defaultTheme")
        let base = theme.background(.bgHero)
        theme.loadTheme(named: "oceanTheme")
        XCTAssertNotEqual(base, theme.background(.bgHero))
    }

    func testAlphaHexParsing() {
        // bg-overlay is #00092966 (8-digit, alpha). Should parse, not be clear-from-failure.
        let overlay = Color(hex: "00092966")
        XCTAssertNotEqual(overlay, Color(hex: "zzzzzz")) // invalid → .clear
    }

    func testTextStyleSpecs() {
        XCTAssertEqual(TextStyle.headingBase.spec.size, 24)
        XCTAssertEqual(TextStyle.bodyBase400.spec.size, 14)
        XCTAssertEqual(TextStyle.displayLg.spec.lineHeight, 68)
    }
}
