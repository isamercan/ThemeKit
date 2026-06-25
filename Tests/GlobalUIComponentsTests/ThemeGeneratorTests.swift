import XCTest
import SwiftUI
@testable import GlobalUIComponents
#if canImport(UIKit)
import UIKit
typealias NativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
typealias NativeColor = NSColor
#endif

final class ThemeGeneratorTests: XCTestCase {
    private func hex(_ data: Theme.ThemeData, _ name: String) -> String? {
        data.colors?.first(where: { $0.name == name })?.hex
    }

    func testPinkPrimaryPropagatesToAllPrimaryDerivedTokens() {
        let d = ThemeGenerator.generate(primaryHex: "ff0d87", tint: 0.13, dark: false,
                                        font: "Montserrat", fontScale: 1, radiusScale: 1, spacingScale: 1, shadowScale: 1)
        // bg-hero, palette.primary.500, text-hero all derive from primary/500 → must equal the seed.
        XCTAssertEqual(hex(d, "background.bg-hero"), "ff0d87")
        XCTAssertEqual(hex(d, "palette.primary.500"), "ff0d87")
        XCTAssertEqual(hex(d, "text.text-hero"), "ff0d87")
        // info follows primary on a full re-skin → bg-info should be the pink seed too.
        XCTAssertEqual(hex(d, "background.systemcolors.bg-info"), "ff0d87")
        XCTAssertEqual(hex(d, "palette.info.500"), "ff0d87")
        // success stays semantic green (NOT pink).
        XCTAssertEqual(hex(d, "background.systemcolors.bg-success"), "12b76a")
    }

    @MainActor
    func testApplyGeneratedUpdatesLiveThemeState() {
        Theme.shared.applyGenerated(primaryHex: "ff0d87", tint: 0.13)
        // The live theme dictionaries must reflect the pink seed everywhere primary flows.
        func rgb(_ c: Color) -> String {
            let ui = NativeColor(c)
            var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
            ui.getRed(&r, green: &g, blue: &b, alpha: &a)
            return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
        }
        XCTAssertEqual(rgb(Theme.shared.background(.bgHero)), "ff0d87")
        XCTAssertEqual(rgb(Theme.shared.palette(.primary500)), "ff0d87")
        XCTAssertEqual(rgb(SemanticColor.primary.base), "ff0d87")          // ladder s500
        XCTAssertEqual(rgb(Theme.shared.background(.systemcolorsBgInfo)), "ff0d87")
        // restore default so other tests aren't affected
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    func testThemeConfigJSONRoundTrip() throws {
        let original = ThemeConfig(primaryHex: "#FF0D87", tint: 0.13, dark: true, font: "SystemRounded",
                                   fontScale: 1.1, radiusScale: 1.5, spacingScale: 0.9, shadowScale: 1.4)
        let restored = try ThemeConfig(jsonData: original.jsonData())
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.primaryHex, "ff0d87")   // normalized (no '#', lowercased)
    }

    @MainActor
    func testApplyConfigAndPersistence() {
        let key = "test.themeConfig"
        UserDefaults.standard.removeObject(forKey: key)

        Theme.shared.apply(ThemeConfig(primaryHex: "12b76a", tint: 0.1))
        XCTAssertEqual(Theme.shared.currentConfig?.primaryHex, "12b76a")
        XCTAssertTrue(Theme.shared.persistConfig(key: key))

        // Switch to a bundled named theme — currentConfig clears.
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertNil(Theme.shared.currentConfig)

        // Restore the persisted custom config.
        XCTAssertTrue(Theme.shared.applyPersistedConfig(key: key))
        XCTAssertEqual(Theme.shared.currentConfig?.primaryHex, "12b76a")

        UserDefaults.standard.removeObject(forKey: key)
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    @MainActor
    func testGeneratedTokenJSONIsLoadable() throws {
        let config = ThemeConfig(primaryHex: "ee9124", tint: 0.11)
        let json = try XCTUnwrap(Theme.shared.generatedTokenJSON(for: config))
        // The exported full-token JSON must load straight back via setTheme.
        Theme.shared.setTheme(jsonData: json)
        XCTAssertNil(Theme.shared.currentConfig)   // loaded as raw tokens, not a recipe
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
    }

    func testDefaultMatchesBakedSeed() {
        let d = ThemeGenerator.generate(primaryHex: "056bfd", tint: 0.06, dark: false,
                                        font: "Montserrat", fontScale: 1, radiusScale: 1, spacingScale: 1, shadowScale: 1)
        XCTAssertEqual(hex(d, "background.bg-hero"), "056bfd")
        XCTAssertEqual(hex(d, "palette.primary.500"), "056bfd")
    }
}
