//
//  MultiSelectTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for MultiSelect's tag overflow split (visible chips vs "+N").
//

import XCTest
@testable import ThemeKit

final class MultiSelectTests: XCTestCase {

    private let picks = ["Istanbul", "Ankara", "Izmir", "Antalya", "Bursa"]

    func testNoLimitShowsAll() {
        let layout = MultiSelect<String>.tagLayout(selected: picks, maxTagCount: nil)
        XCTAssertEqual(layout.visible, picks)
        XCTAssertEqual(layout.overflow, 0)
    }

    func testLimitSplitsOverflow() {
        let layout = MultiSelect<String>.tagLayout(selected: picks, maxTagCount: 2)
        XCTAssertEqual(layout.visible, ["Istanbul", "Ankara"])
        XCTAssertEqual(layout.overflow, 3)
    }

    func testCountEqualToLimitHasNoOverflow() {
        let layout = MultiSelect<String>.tagLayout(selected: ["A", "B"], maxTagCount: 2)
        XCTAssertEqual(layout.visible, ["A", "B"])
        XCTAssertEqual(layout.overflow, 0)
    }

    func testLimitAboveCountShowsAll() {
        let layout = MultiSelect<String>.tagLayout(selected: ["A", "B"], maxTagCount: 10)
        XCTAssertEqual(layout.visible, ["A", "B"])
        XCTAssertEqual(layout.overflow, 0)
    }

    func testZeroLimitOverflowsEverything() {
        let layout = MultiSelect<String>.tagLayout(selected: picks, maxTagCount: 0)
        XCTAssertTrue(layout.visible.isEmpty)
        XCTAssertEqual(layout.overflow, 5)
    }
}
