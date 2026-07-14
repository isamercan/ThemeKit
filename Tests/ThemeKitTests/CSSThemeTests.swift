//
//  CSSThemeTests.swift
//  ThemeKitTests
//
//  Pins `CSSTheme` (the native Swift CSS importer) against the exact tokens the
//  offline `tools/import_css_theme.py` produces for the same HeroUI CSS — the two
//  independent implementations must not drift. Both use identical OKLCH math and
//  the same `ThemeGenerator` ladder, with banker's rounding, so the output is
//  byte-identical (not merely close). Also checks light/dark switching and that
//  the `--radius` roles (declared once in `:root`) are inherited by the dark scheme.
//

import XCTest
import SwiftUI
@testable import ThemeKit
@testable import ThemeKitCore

final class CSSThemeTests: XCTestCase {

    // The HeroUI theme CSS (same source as tools/themes/heroui.css & the bundled
    // herouiTheme.json). Trimmed to the variables the importer reads.
    private let css = """
    :root, .light, .default {
      --accent: oklch(62.04% 0.1950 253.83);
      --accent-foreground: oklch(99.11% 0 0);
      --background: oklch(97.02% 0.0000 253.83);
      --border: oklch(90.00% 0.0000 253.83);
      --danger: oklch(65.32% 0.2328 25.74);
      --default: oklch(94.00% 0.0000 253.83);
      --focus: oklch(62.04% 0.1950 253.83);
      --foreground: oklch(21.03% 0.0000 253.83);
      --muted: oklch(55.17% 0.0000 253.83);
      --success: oklch(73.29% 0.1935 150.81);
      --surface: oklch(100.00% 0.0000 253.83);
      --surface-secondary: oklch(95.24% 0.0000 253.83);
      --surface-tertiary: oklch(93.73% 0.0000 253.83);
      --warning: oklch(78.19% 0.1585 72.33);
      --radius: 0.5rem;
      --field-radius: 0.75rem;
    }
    .dark {
      --accent: oklch(62.04% 0.1950 253.83);
      --background: oklch(12.00% 0.0000 253.83);
      --border: oklch(28.00% 0.0000 253.83);
      --danger: oklch(59.40% 0.1967 24.63);
      --default: oklch(27.40% 0.0000 253.83);
      --focus: oklch(62.04% 0.1950 253.83);
      --foreground: oklch(99.11% 0.0000 253.83);
      --muted: oklch(70.50% 0.0000 253.83);
      --success: oklch(73.29% 0.1935 150.81);
      --surface: oklch(21.03% 0.0000 253.83);
      --surface-secondary: oklch(25.70% 0.0000 253.83);
      --surface-tertiary: oklch(27.21% 0.0000 253.83);
      --warning: oklch(82.03% 0.1388 76.34);
    }
    """

    private func hex(_ d: Theme.ThemeData, _ name: String) -> String? {
        d.colors?.first(where: { $0.name == name })?.hex
    }
    private func radius(_ d: Theme.ThemeData, _ name: String) -> CGFloat? {
        d.radius?.first(where: { $0.name == name })?.radius
    }

    func testLightSchemeMatchesImporterOutput() {
        let d = CSSTheme.parse(css).themeData(dark: false, font: "Inter")
        // Exact semantic overrides (straight from OKLCH → sRGB).
        XCTAssertEqual(hex(d, "background.bg-base"), "f5f5f5")
        XCTAssertEqual(hex(d, "background.bg-white"), "ffffff")
        XCTAssertEqual(hex(d, "background.bg-hero"), "0485f7")
        XCTAssertEqual(hex(d, "text.text-primary"), "181818")
        XCTAssertEqual(hex(d, "text.text-tertiary"), "727272")
        XCTAssertEqual(hex(d, "border.border-primary"), "dedede")
        XCTAssertEqual(hex(d, "background.systemcolors.bg-error"), "ff383c")
        XCTAssertEqual(hex(d, "background.systemcolors.bg-success"), "17c964")
        XCTAssertEqual(hex(d, "background.systemcolors.bg-warning"), "f5a524")
        // Reseeded ladders: primary follows the accent, error follows danger.
        XCTAssertEqual(hex(d, "palette.primary.500"), "0485f7")
        XCTAssertEqual(hex(d, "palette.error.500"), "ff383c")
        // Radius roles from --radius (0.5rem=8) / --field-radius (0.75rem=12).
        XCTAssertEqual(radius(d, "radius-box"), 8)
        XCTAssertEqual(radius(d, "radius-field"), 12)
        // Font propagates to the type ramp.
        XCTAssertEqual(d.typography?.first?.font, "Inter")
    }

    func testDarkSchemeMatchesImporterOutput() {
        let d = CSSTheme.parse(css).themeData(dark: true, font: "Inter")
        XCTAssertEqual(hex(d, "background.bg-base"), "060606")
        XCTAssertEqual(hex(d, "background.bg-white"), "181818")
        XCTAssertEqual(hex(d, "text.text-primary"), "fcfcfc")
        XCTAssertEqual(hex(d, "text.text-tertiary"), "a0a0a0")
        XCTAssertEqual(hex(d, "border.border-primary"), "292929")
        XCTAssertEqual(hex(d, "background.systemcolors.bg-error"), "db3b3e")
        XCTAssertEqual(hex(d, "background.systemcolors.bg-warning"), "f7b750")
        XCTAssertEqual(hex(d, "background.bg-hero"), "0485f7")   // accent constant across schemes
        // Radius declared once in :root is inherited by the dark scheme.
        XCTAssertEqual(radius(d, "radius-box"), 8)
        XCTAssertEqual(radius(d, "radius-field"), 12)
    }

    func testParseDetectsDarkBlock() {
        let parsed = CSSTheme.parse(css)
        XCTAssertTrue(parsed.hasDarkScheme)
        XCTAssertEqual(CSSTheme.parseColor(parsed.light["accent"] ?? "")?.hex, "0485f7")
    }

    func testSetThemeCSSAppliesAndSwitchesScheme() {
        let t = Theme()
        t.setTheme(css: css, font: "Inter", dark: false)
        XCTAssertNotNil(t.currentCSS)
        XCTAssertFalse(t.isDark)
        XCTAssertEqual(t.background(.bgBase), Color(hex: "f5f5f5"))

        // setColorScheme re-derives the dark block from the same CSS.
        t.setColorScheme(dark: true)
        XCTAssertTrue(t.isDark)
        XCTAssertEqual(t.background(.bgBase), Color(hex: "060606"))

        // Switching to a JSON theme clears the CSS state.
        t.loadTheme(named: "defaultTheme")
        XCTAssertNil(t.currentCSS)
    }

    func testBundledHeroUICSSLoads() {
        let t = Theme()
        t.loadTheme(cssNamed: "heroui", font: "Inter")
        XCTAssertNotNil(t.currentCSS)
        XCTAssertEqual(t.background(.bgHero), Color(hex: "0485f7"))
    }
}
