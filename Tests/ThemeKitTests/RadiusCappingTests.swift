import XCTest
@testable import ThemeKit
@testable import ThemeKitTravel

/// Math contract for the HeroUI-style radius helpers on `Theme.RadiusKey` and
/// `Theme.RadiusRole`: `value(cappedFor:)` clamps to half the element height,
/// `concentric(inset:)` subtracts the inset and floors at 0.
@MainActor
final class RadiusCappingTests: XCTestCase {

    override func tearDown() {
        Theme.shared.loadTheme(named: Theme.defaultThemeName)
        super.tearDown()
    }

    // MARK: value(cappedFor:)

    func testKeyCappedValueClampsToHalfHeight() {
        let raw = Theme.RadiusKey.base.value
        XCTAssertGreaterThan(raw, 5, "sanity: cap must engage for a 10pt element")
        XCTAssertEqual(Theme.RadiusKey.base.value(cappedFor: 10), 5)
        // A tall element never over-rounds — full radius comes back untouched.
        XCTAssertEqual(Theme.RadiusKey.base.value(cappedFor: 1_000), raw)
    }

    func testRoleCappedValueClampsToHalfHeight() {
        let raw = Theme.RadiusRole.box.value
        XCTAssertGreaterThan(raw, 4, "sanity: cap must engage for an 8pt element")
        XCTAssertEqual(Theme.RadiusRole.box.value(cappedFor: 8), 4)
        XCTAssertEqual(Theme.RadiusRole.box.value(cappedFor: 1_000), raw)
    }

    // MARK: concentric(inset:)

    func testConcentricSubtractsInset() {
        // The exact hand-computed relationship FlightListItemStyle used to write out.
        XCTAssertEqual(Theme.RadiusKey.base.concentric(inset: .xs),
                       Theme.RadiusKey.base.value - Theme.SpacingKey.xs.value)
        XCTAssertEqual(Theme.RadiusRole.box.concentric(inset: .xs),
                       Theme.RadiusRole.box.value - Theme.SpacingKey.xs.value)
    }

    func testConcentricFloorsAtZero() {
        // Zero-radius corner minus any inset must never go negative.
        XCTAssertEqual(Theme.RadiusKey.none.value, 0)
        XCTAssertEqual(Theme.RadiusKey.none.concentric(inset: .xl), 0)
        // A "sharp" theme zeroes every role — concentric stays floored at 0 too.
        Theme.shared.applyGenerated(primaryHex: "056bfd", radiusScale: 0)
        XCTAssertEqual(Theme.RadiusRole.box.concentric(inset: .lg), 0)
        XCTAssertEqual(Theme.RadiusKey.base.concentric(inset: .lg), 0)
    }
}
