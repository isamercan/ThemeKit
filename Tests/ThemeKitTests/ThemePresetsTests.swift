import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias DaisyNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias DaisyNativeColor = NSColor
#endif

final class ThemePresetsTests: XCTestCase {
    private func hex(_ data: Theme.ThemeData, _ name: String) -> String? {
        data.colors?.first(where: { $0.name == name })?.hex
    }

    private func rgb(_ c: Color) -> String {
        let ui = DaisyNativeColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    func testCatalogIntegrity() {
        let all = ThemePreset.all
        XCTAssertGreaterThanOrEqual(all.count, 30)
        // Unique ids.
        XCTAssertEqual(Set(all.map(\.id)).count, all.count)
        // Every swatch is a clean 6-digit hex.
        for t in all {
            for h in [t.primary, t.secondary, t.accent, t.base] {
                XCTAssertEqual(h.count, 6, "\(t.id): '\(h)' is not 6 hex digits")
                XCTAssertTrue(h.allSatisfy(\.isHexDigit), "\(t.id): '\(h)' has non-hex chars")
            }
        }
        // Lookup works.
        XCTAssertEqual(ThemePreset.named("dracula")?.name, "Dracula")
        XCTAssertNil(ThemePreset.named("does-not-exist"))
    }

    func testConfigCarriesBaseHex() {
        let dracula = ThemePreset.named("dracula")!
        XCTAssertEqual(dracula.config.primaryHex, "ff79c6")
        XCTAssertEqual(dracula.config.baseHex, "282a36")
        XCTAssertTrue(dracula.config.dark)
    }

    func testBaseHexDrivesSurfaceExactly() {
        // Cupcake (light): bg-white takes the base tone verbatim (blend amount 0),
        // while the primary still propagates to hero/palette in light mode.
        let d = ThemeGenerator.generate(primaryHex: "65c3c8", tint: 0.07, dark: false,
                                        font: "Montserrat", fontScale: 1, radiusScale: 1,
                                        spacingScale: 1, shadowScale: 1, baseHex: "faf7f5")
        XCTAssertEqual(hex(d, "background.bg-white"), "faf7f5")     // the daisyUI base
        XCTAssertEqual(hex(d, "background.bg-hero"), "65c3c8")      // raw primary (light)
        XCTAssertEqual(hex(d, "palette.primary.500"), "65c3c8")
        // The elevated surface is the base nudged toward the contrast, not pure base.
        XCTAssertNotEqual(hex(d, "background.bg-secondary"), "faf7f5")
    }

    func testWithoutBaseHexSurfaceIsNotForced() {
        // Sanity: omitting baseHex keeps the generator's own surface (not 282a36).
        let d = ThemeGenerator.generate(primaryHex: "ff79c6", tint: 0.07, dark: true,
                                        font: "Montserrat", fontScale: 1, radiusScale: 1,
                                        spacingScale: 1, shadowScale: 1)
        XCTAssertNotEqual(hex(d, "background.bg-white"), "282a36")
    }

    @MainActor
    func testApplyDaisyThemeUpdatesLiveTokens() {
        // Cupcake (light) — both primary and base land verbatim in the live theme.
        ThemePreset.named("cupcake")!.apply()
        XCTAssertEqual(rgb(Theme.shared.background(.bgHero)), "65c3c8")   // primary
        XCTAssertEqual(rgb(Theme.shared.background(.bgWhite)), "faf7f5")  // base surface
        XCTAssertEqual(Theme.shared.currentConfig?.baseHex, "faf7f5")

        // Dracula (dark) — the base surface still wins even though dark primary is mixed.
        ThemePreset.named("dracula")!.apply()
        XCTAssertEqual(rgb(Theme.shared.background(.bgWhite)), "282a36")
        XCTAssertEqual(Theme.shared.currentConfig?.baseHex, "282a36")
        XCTAssertTrue(Theme.shared.isDark)

        // restore default so other tests aren't affected
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    func testBaseHexSurvivesConfigRoundTrip() throws {
        let original = ThemePreset.named("cupcake")!.config
        let restored = try ThemeConfig(jsonData: original.jsonData())
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.baseHex, "faf7f5")
    }
}
