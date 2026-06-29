import XCTest
@testable import ThemeKit

@MainActor
final class RadiusRoleTests: XCTestCase {

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    func testGeneratedThemeCarriesRoleTokens() {
        Theme.shared.applyGenerated(primaryHex: "056bfd")
        XCTAssertEqual(Theme.RadiusRole.box.value, 16)
        XCTAssertEqual(Theme.RadiusRole.field.value, 8)
        XCTAssertEqual(Theme.RadiusRole.selector.value, 6)
    }

    func testRadiusScaleScalesRoles() {
        Theme.shared.applyGenerated(primaryHex: "056bfd", radiusScale: 2)
        XCTAssertEqual(Theme.RadiusRole.box.value, 32)
        XCTAssertEqual(Theme.RadiusRole.field.value, 16)
        XCTAssertEqual(Theme.RadiusRole.selector.value, 12)
        // A "sharp" theme zeroes every role at once.
        Theme.shared.applyGenerated(primaryHex: "056bfd", radiusScale: 0)
        XCTAssertEqual(Theme.RadiusRole.box.value, 0)
        XCTAssertEqual(Theme.RadiusRole.field.value, 0)
    }

    func testBundledThemeFallsBackToSizeKeys() {
        // Bundled JSON themes don't define role tokens — the role must fall back to
        // its size key, so existing themes keep their corners (visual-neutral).
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        XCTAssertEqual(Theme.RadiusRole.box.value, Theme.RadiusKey.md.value)
        XCTAssertEqual(Theme.RadiusRole.field.value, Theme.RadiusKey.sm.value)
        XCTAssertEqual(Theme.RadiusRole.selector.value, Theme.RadiusKey.xs.value)
    }

    func testRoleFallbackMapping() {
        XCTAssertEqual(Theme.RadiusRole.box.fallback, .md)
        XCTAssertEqual(Theme.RadiusRole.field.fallback, .sm)
        XCTAssertEqual(Theme.RadiusRole.selector.fallback, .xs)
        XCTAssertEqual(Set(Theme.RadiusRole.allCases.map(\.rawValue)).count, 3)
    }
}
