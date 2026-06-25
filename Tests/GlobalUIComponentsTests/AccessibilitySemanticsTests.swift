//
//  AccessibilitySemanticsTests.swift
//  GlobalUIComponentsTests
//
//  Locks the *content* of the VoiceOver labels added to display components —
//  the bits that are pure logic. The view-tree wiring (accessibilityElement /
//  Label / Value) is verified visually via the snapshot suite and on-device.
//

import XCTest
import SwiftUI
@testable import GlobalUIComponents

final class AccessibilitySemanticsTests: XCTestCase {

    // A status dot conveys state with color; VoiceOver must get a spoken
    // equivalent for every kind, never an empty string.
    func testStatusKindHasSpokenNameForEveryCase() {
        let kinds: [StatusKind] = [.online, .offline, .busy, .away, .neutral]
        for kind in kinds {
            XCTAssertFalse(kind.accessibleName.isEmpty, "\(kind) has no accessible name")
        }
    }

    // The meaningful states must be distinguishable to a VoiceOver user.
    func testDistinctStatesHaveDistinctNames() {
        let names = Set([StatusKind.online, .offline, .busy, .away].map(\.accessibleName))
        XCTAssertEqual(names.count, 4, "status states collapsed to the same spoken name")
    }

    // The trend arrow glyph is silent to VoiceOver; the spoken text must carry
    // both the direction and the magnitude.
    func testStatTrendSpeaksDirectionAndValue() {
        XCTAssertTrue(StatTrend.up("12%").accessibleText.contains("12%"))
        XCTAssertTrue(StatTrend.down("3%").accessibleText.contains("3%"))
        XCTAssertNotEqual(StatTrend.up("5%").accessibleText, StatTrend.down("5%").accessibleText,
                          "up and down trends must read differently")
    }
}
