//
//  OTPInputTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for OTPInput's input sanitizer (digits-only, length cap).
//

import XCTest
@testable import ThemeKit

final class OTPInputTests: XCTestCase {

    func testFiltersNonDigits() {
        XCTAssertEqual(OTPInput.sanitize("12ab34", digitCount: 6), "1234")
    }

    func testCapsToDigitCount() {
        XCTAssertEqual(OTPInput.sanitize("123456789", digitCount: 6), "123456")
    }

    func testEmptyWhenNoDigits() {
        XCTAssertEqual(OTPInput.sanitize("abc-!", digitCount: 4), "")
    }

    func testPastedCodeIsAccepted() {
        // Simulates pasting a full code with stray formatting.
        XCTAssertEqual(OTPInput.sanitize("1 2-3 4", digitCount: 4), "1234")
    }
}
