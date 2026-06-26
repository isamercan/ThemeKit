//
//  InputNumberTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for InputNumber's clamp + text parsing (digits-only, optional sign).
//

import XCTest
@testable import ThemeKit

final class InputNumberTests: XCTestCase {

    // MARK: - clamp

    func testClampBelowLowerBound() {
        XCTAssertEqual(InputNumber.clamp(-3, to: 0...9), 0)
    }

    func testClampAboveUpperBound() {
        XCTAssertEqual(InputNumber.clamp(42, to: 0...9), 9)
    }

    func testClampWithinRange() {
        XCTAssertEqual(InputNumber.clamp(5, to: 0...9), 5)
    }

    // MARK: - parse

    func testParseDigits() {
        XCTAssertEqual(InputNumber.parse("12", range: 0...99), 12)
    }

    func testParseStripsNonDigits() {
        XCTAssertEqual(InputNumber.parse("1a2", range: 0...99), 12)
        XCTAssertEqual(InputNumber.parse("007", range: 0...99), 7)
    }

    func testParseEmptyReturnsNil() {
        XCTAssertNil(InputNumber.parse("", range: 0...99))
        XCTAssertNil(InputNumber.parse("abc", range: 0...99))
    }

    func testParseNegativeOnlyWhenRangeAllows() {
        XCTAssertEqual(InputNumber.parse("-5", range: -10...10), -5)
        // Range has no negatives → the minus is ignored, magnitude kept.
        XCTAssertEqual(InputNumber.parse("-5", range: 0...10), 5)
    }
}
