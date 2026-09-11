import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias CustomNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias CustomNativeColor = NSColor
#endif

@MainActor
final class CustomTokenTests: XCTestCase {
    private func rgb(_ c: Color) -> String {
        let ui = CustomNativeColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    /// A theme carrying consumer tokens alongside the built-in ones.
    private let json = """
    {
      "colors": [
        { "name": "background.bg-white", "hex": "ffffff" },
        { "name": "custom.fare-badge",   "hex": "ff5722" }
      ],
      "radius":  [ { "name": "rd-sm", "radius": 8 }, { "name": "custom.card-hero", "radius": 20 } ],
      "spacing": [ { "name": "sp-md", "spacing": 16 }, { "name": "custom.gutter", "spacing": 22 } ],
      "typography": [
        { "name": "custom.price", "font": "System", "size": 27, "weight": "bold", "lineHeight": 32 }
      ],
      "shadows": [
        { "name": "custom.lift", "layers": [ { "color": "00000033", "radius": 4, "x": 0, "y": 1 } ] }
      ]
    }
    """

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    func testCustomTokensSurviveTheJSONRoundTrip() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(rgb(Theme.shared.customColor("fare-badge")!), "ff5722")
        XCTAssertEqual(Theme.shared.customRadius("card-hero"), 20)
        XCTAssertEqual(Theme.shared.customSpacing("gutter"), 22)
        XCTAssertNotNil(Theme.shared.customTextStyle("price"))
        XCTAssertEqual(Theme.shared.customShadow("lift")?.count, 1)
    }

    func testBuiltInTokensAreUnaffected() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        // The custom namespace rides alongside — it does not displace the typed API.
        XCTAssertEqual(rgb(Theme.shared.background(.bgWhite)), "ffffff")
        XCTAssertEqual(Theme.shared.radius(.sm), 8)
        XCTAssertEqual(Theme.shared.spacing(.md), 16)
    }

    /// The seal: an accessor prepends the prefix, so a consumer cannot reach a
    /// built-in key or a `package`-level component token through the string API.
    func testAccessorsCannotReachThemeKitsOwnTokens() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertNil(Theme.shared.customRadius("rd-sm"))
        XCTAssertNil(Theme.shared.customSpacing("sp-md"))
        XCTAssertNil(Theme.shared.customColor("background.bg-white"))
        // Nor by smuggling the prefix in by hand.
        XCTAssertNil(Theme.shared.customSpacing("../sp-md"))
    }

    func testMissingCustomTokenIsNilNotADefault() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)

        XCTAssertNil(Theme.shared.customColor("fare-badge"))
        XCTAssertNil(Theme.shared.customRadius("card-hero"))
    }

    func testSwitchingThemesClearsThePreviousCustomTokens() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))
        XCTAssertNotNil(Theme.shared.customColor("fare-badge"))

        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))
        XCTAssertNil(Theme.shared.customColor("fare-badge"))
    }
}
