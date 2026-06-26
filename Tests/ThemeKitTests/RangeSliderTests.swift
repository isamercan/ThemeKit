//
//  RangeSliderTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for RangeSlider's pure snap-to-step + clamp helpers.
//

import XCTest
@testable import ThemeKit

final class RangeSliderTests: XCTestCase {

    // MARK: - snap

    func testSnapRoundsToNearestStep() {
        XCTAssertEqual(RangeSlider.snap(217, step: 50), 200)
        XCTAssertEqual(RangeSlider.snap(230, step: 50), 250)
    }

    func testSnapHalfwayRoundsUp() {
        XCTAssertEqual(RangeSlider.snap(225, step: 50), 250)
    }

    func testSnapZeroStepIsNoOp() {
        XCTAssertEqual(RangeSlider.snap(217, step: 0), 217)
    }

    // MARK: - clamped

    func testClampedWithinBounds() {
        XCTAssertEqual(RangeSlider.clamped(500, in: 0...1000), 500)
    }

    func testClampedBelowLower() {
        XCTAssertEqual(RangeSlider.clamped(-20, in: 0...1000), 0)
    }

    func testClampedAboveUpper() {
        XCTAssertEqual(RangeSlider.clamped(1500, in: 0...1000), 1000)
    }
}
