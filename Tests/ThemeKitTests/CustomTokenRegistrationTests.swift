import XCTest
import SwiftUI
@testable import ThemeKit
#if canImport(UIKit)
import UIKit
private typealias RegNativeColor = UIColor
#elseif canImport(AppKit)
import AppKit
private typealias RegNativeColor = NSColor
#endif

@MainActor
final class CustomTokenRegistrationTests: XCTestCase {
    private func rgb(_ c: Color) -> String {
        let ui = RegNativeColor(c)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()), Int((b * 255).rounded()))
    }

    private let set = Theme.CustomTokenSet(
        colors: [.fareBadge: Color(hex: "ff5722")],
        darkColors: [.fareBadge: Color(hex: "c63f14")],
        radii: [.cardHero: 20],
        spacings: [.gutter: 22]
    )

    override func setUp() {
        super.setUp()
        Theme.shared.registerCustomTokens(set)
    }

    override func tearDown() {
        Theme.shared.registerCustomTokens(.init())
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    /// The point of registration: the app's tokens outlive every theme entry point.
    func testRegisteredTokensSurviveEveryThemePath() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd"))
        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "ff5722", "config path")
        XCTAssertEqual(Theme.shared.custom.radius(.cardHero), 20)

        ThemePreset.named("light")?.apply()
        XCTAssertNotNil(Theme.shared.custom.color(.fareBadge), "preset path")

        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertNotNil(Theme.shared.custom.color(.fareBadge), "named theme path")

        Theme.shared.setTheme(css: ":root { --accent: #ff0000; }")
        XCTAssertNotNil(Theme.shared.custom.color(.fareBadge), "css path")

        Theme.shared.setTheme(jsonData: Data(#"{"colors":[]}"#.utf8))
        XCTAssertNotNil(Theme.shared.custom.color(.fareBadge), "json path")
    }

    /// A registered token is the app's, so a theme declaring the same name loses.
    func testRegisteredTokensOutrankTheThemesOwn() {
        let json = #"{"colors":[{"name":"custom.fare-badge","hex":"00ff00"}]}"#
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "ff5722")
    }

    /// A theme-declared token the app doesn't register still comes through.
    func testThemeTokensStillLoadAlongsideRegisteredOnes() {
        let json = #"{"colors":[{"name":"custom.promo","hex":"00ff00"}]}"#
        Theme.shared.setTheme(jsonData: Data(json.utf8))

        XCTAssertEqual(rgb(Theme.shared.custom.color("promo")!), "00ff00")
        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "ff5722")
    }

    func testDarkVariantIsPickedForTheActiveScheme() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd", dark: true))
        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "c63f14")

        Theme.shared.setColorScheme(dark: false)
        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "ff5722")
    }

    /// A token with no dark override keeps its light value in dark mode.
    func testTokensWithoutADarkOverrideKeepTheirLightValue() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd", dark: true))
        XCTAssertEqual(Theme.shared.custom.radius(.cardHero), 20)
    }

    /// `setTheme(jsonData:)` used to leave `baseThemeName` stale, so a later
    /// `setColorScheme(dark:)` silently reloaded ThemeKit's own bundled theme.
    func testColorSchemeSwitchDoesNotDiscardADataTheme() {
        let json = #"{"colors":[{"name":"custom.promo","hex":"00ff00"}]}"#
        Theme.shared.setTheme(jsonData: Data(json.utf8))
        XCTAssertEqual(Theme.shared.baseThemeName, Theme.dataThemeName)

        Theme.shared.setColorScheme(dark: true)

        XCTAssertTrue(Theme.shared.isDark)
        XCTAssertNotNil(Theme.shared.custom.color("promo"), "the data theme must survive the switch")
        XCTAssertEqual(rgb(Theme.shared.custom.color(.fareBadge)!), "c63f14", "and re-pick the dark registered value")
    }

    func testClearingRegistrationRemovesTheTokens() {
        Theme.shared.registerCustomTokens(.init())
        Theme.shared.loadTheme(named: Theme.defaultThemeName)

        XCTAssertNil(Theme.shared.custom.color(.fareBadge))
        XCTAssertTrue(Theme.shared.registeredCustomTokens.isEmpty)
    }
}

private extension Theme.CustomToken {
    static let fareBadge: Self = "fare-badge"
    static let cardHero: Self = "card-hero"
    static let gutter: Self = "gutter"
}
