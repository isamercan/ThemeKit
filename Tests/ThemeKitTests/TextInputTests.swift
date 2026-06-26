//
//  TextInputTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for TextInput's character-counter formatting and soft-limit check.
//

import XCTest
@testable import ThemeKit

final class TextInputTests: XCTestCase {

    // MARK: - counterText

    func testCountStyleWithMaxLength() {
        XCTAssertEqual(TextInput.counterText(count: 12, maxLength: 50, style: .count), "12/50")
    }

    func testCountStyleWithoutMaxLength() {
        // No limit configured → plain character count.
        XCTAssertEqual(TextInput.counterText(count: 7, maxLength: nil, style: .count), "7")
    }

    func testRemainingStyleWithMaxLength() {
        XCTAssertEqual(TextInput.counterText(count: 12, maxLength: 50, style: .remaining), "38 left")
    }

    func testRemainingStyleCanGoNegativeWhenOver() {
        // Soft limit lets the field exceed max; "remaining" reads negative.
        XCTAssertEqual(TextInput.counterText(count: 55, maxLength: 50, style: .remaining), "-5 left")
    }

    func testRemainingStyleWithoutMaxLengthFallsBackToCount() {
        XCTAssertEqual(TextInput.counterText(count: 7, maxLength: nil, style: .remaining), "7")
    }

    // MARK: - isOverLimit

    func testNotOverLimitAtMax() {
        XCTAssertFalse(TextInput.isOverLimit(count: 50, maxLength: 50))
    }

    func testOverLimit() {
        XCTAssertTrue(TextInput.isOverLimit(count: 51, maxLength: 50))
    }

    func testNeverOverLimitWithoutMaxLength() {
        XCTAssertFalse(TextInput.isOverLimit(count: 9999, maxLength: nil))
    }
}
