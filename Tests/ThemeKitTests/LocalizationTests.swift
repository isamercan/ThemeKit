//
//  LocalizationTests.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Verifies the String Catalog wiring: shipped defaults are English (the kit is
//  English-only), interpolation works, and callers can still override.
//

import XCTest
import Foundation
@testable import ThemeKit

final class LocalizationTests: XCTestCase {
    // Default validation messages resolve to the English source strings.
    func testDefaultMessagesAreEnglish() {
        XCTAssertEqual(ValidationRule.required().message, "This field is required")
        XCTAssertEqual(ValidationRule.email().message, "Enter a valid email")
        XCTAssertEqual(ValidationRule.numeric().message, "Digits only")
        XCTAssertEqual(ValidationRule.match("x").message, "Doesn't match")
    }

    // Interpolated keys resolve and embed their numbers.
    func testInterpolatedMessages() {
        XCTAssertEqual(ValidationRule.minLength(6).message, "At least 6 characters")
        XCTAssertEqual(ValidationRule.range(1...10).message, "Between 1 and 10")
    }

    // The public bridge initializer resolves from the bundle.
    func testPublicBridgeInitializer() {
        XCTAssertEqual(String(themeKit: "Digits only"), "Digits only")
    }

    // Callers can still override every default (non-breaking).
    func testOverrideWins() {
        XCTAssertEqual(ValidationRule.required("Required").message, "Required")
        XCTAssertEqual(ValidationRule.email("Custom").message, "Custom")
    }
}
