import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias BrandNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias BrandNativeColor = NSColor
#endif

@MainActor
final class BrandColorTests: XCTestCase {
    private func rgb(_ c: Color) -> String {
        let ui = BrandNativeColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    func testConfigCarriesSecondaryAndAccent() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd", secondaryHex: "f43098", accentHex: "00d3bb"))
        // The base (step 500) of each brand ladder is the seed.
        XCTAssertEqual(rgb(SemanticColor.secondary.base), "f43098")
        XCTAssertEqual(rgb(SemanticColor.accent.base), "00d3bb")
        // solid == base for the brand colors.
        XCTAssertEqual(rgb(SemanticColor.accent.solid), "00d3bb")
        // A lighter step exists (the full ladder generated).
        XCTAssertNotEqual(rgb(SemanticColor.accent.shade(.s50)), "00d3bb")
    }

    func testBrandColorsFallBackToPrimaryWhenUndefined() {
        // A theme without secondary/accent → those resolve to primary, never clear.
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))
        XCTAssertEqual(rgb(SemanticColor.accent.base), rgb(SemanticColor.primary.base))
        XCTAssertEqual(rgb(SemanticColor.secondary.base), rgb(SemanticColor.primary.base))
        // Bundled JSON themes have no brand ladders either → still primary, not clear.
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertEqual(rgb(SemanticColor.accent.base), rgb(SemanticColor.primary.base))
    }

    func testDaisyThemeAppliesSecondaryAndAccent() {
        // Dracula: secondary bd93f9, accent ffb86c (light-mode ladder seed == hex).
        DaisyTheme.named("light")!.apply()   // light theme so the dark mix doesn't shift the seed
        let light = DaisyTheme.named("light")!
        XCTAssertEqual(rgb(SemanticColor.secondary.base), light.secondary)
        XCTAssertEqual(rgb(SemanticColor.accent.base), light.accent)
    }

    func testConfigRoundTripsBrandHexes() throws {
        let original = ThemeConfig(primaryHex: "056bfd", secondaryHex: "f43098", accentHex: "00d3bb")
        let restored = try ThemeConfig(jsonData: original.jsonData())
        XCTAssertEqual(restored, original)
        XCTAssertEqual(restored.secondaryHex, "f43098")
        XCTAssertEqual(restored.accentHex, "00d3bb")
    }
}
