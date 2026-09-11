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

        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "ff5722")
        XCTAssertEqual(Theme.shared.custom.radius(.cardHero), 20)
        XCTAssertEqual(Theme.shared.custom.spacing(.gutter), 22)
        XCTAssertNotNil(Theme.shared.custom.textStyle(.price))
        XCTAssertEqual(Theme.shared.custom.shadow(.lift)?.count, 1)
    }

    func testBuiltInTokensAreUnaffected() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        // The custom namespace rides alongside — it does not displace the typed API.
        XCTAssertEqual(rgb(Theme.shared.background(.bgWhite)), "ffffff")
        XCTAssertEqual(Theme.shared.radius(.sm), 8)
        XCTAssertEqual(Theme.shared.spacing(.md), 16)
    }

    /// The seal: a token holds the bare name and the lookup adds the prefix, so a
    /// consumer cannot reach a generated key or a `package`-level component token.
    func testLookupsCannotReachThemeKitsOwnTokens() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertNil(Theme.shared.custom.radius("rd-sm"))
        XCTAssertNil(Theme.shared.custom.spacing("sp-md"))
        XCTAssertNil(Theme.shared.custom.color("background.bg-white"))
    }

    /// Consumer tokens live in their own storage, so they never land in — or shadow —
    /// the dictionaries ThemeKit's own tokens resolve from.
    func testCustomMetricsDoNotEnterTheBuiltInStores() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        // `custom.card-hero` must not be readable as a plain radius token name.
        XCTAssertEqual(Theme.shared.radius(.md), 0, "a theme omitting rd-md leaves it unset, not filled by a custom token")
        XCTAssertEqual(Theme.shared.custom.radius(.cardHero), 20)
    }

    /// The likeliest real mistake: pasting the qualified name out of the theme file.
    /// It must not silently resolve `custom.custom.…`; `qualifiedName` is the way back.
    func testQualifiedNameRoundTrip() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(Theme.CustomToken.fareBadge.qualifiedName, "custom.fare-badge")
        XCTAssertEqual(Theme.CustomToken(rawValue: "fare-badge"), .fareBadge)
        // An empty name resolves the bare prefix and must not match anything.
        XCTAssertNil(Theme.shared.custom.color(""))
    }

    func testEnumerationListsWhatTheThemeDeclares() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(Theme.shared.custom.colors, [.fareBadge])
        XCTAssertEqual(Theme.shared.custom.radii, [.cardHero])
        XCTAssertEqual(Theme.shared.custom.spacings, [.gutter])
        XCTAssertEqual(Theme.shared.custom.textStyles, [.price])
        XCTAssertEqual(Theme.shared.custom.shadows, [.lift])
    }

    /// A consumer text style anchors to the Dynamic Type band its size implies —
    /// not `.body` — so it scales like a built-in style of the same size.
    func testCustomTextStyleAnchorsToItsSizeBand() {
        // 27pt sits in the .title2 band. Before this, a name the ramp doesn't know
        // anchored to .body regardless of size, so custom type scaled differently
        // from built-in type at the same size.
        XCTAssertEqual(TextStyle.relativeTextStyle(forSize: 27), .title2)
        XCTAssertEqual(TextStyle.headingBase.relativeTextStyle, .title2)
    }

    func testMissingCustomTokenIsNilNotADefault() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)

        XCTAssertNil(Theme.shared.custom.color(.fareBadge))
        XCTAssertNil(Theme.shared.custom.radius(.cardHero))
    }

    func testSwitchingThemesClearsThePreviousCustomTokens() {
        Theme.shared.setTheme(jsonData: Data(json.utf8))
        XCTAssertNotNil(Theme.shared.custom.color(.fareBadge))

        // Documented scope: the config path regenerates the token set, so the
        // consumer namespace does not survive it.
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))
        XCTAssertNil(Theme.shared.custom.color(.fareBadge))
        XCTAssertTrue(Theme.shared.custom.colors.isEmpty)
    }
}

private extension Theme.CustomToken {
    static let fareBadge: Self = "fare-badge"
    static let cardHero: Self = "card-hero"
    static let gutter: Self = "gutter"
    static let price: Self = "price"
    static let lift: Self = "lift"
}
