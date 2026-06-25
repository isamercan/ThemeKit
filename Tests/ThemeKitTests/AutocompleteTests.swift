//
//  AutocompleteTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for Autocomplete's static matcher (case-insensitive, capped, empty).
//

import XCTest
@testable import ThemeKit

final class AutocompleteTests: XCTestCase {

    private let fruits = ["Apple", "Apricot", "Banana", "Cherry", "Avocado"]

    func testEmptyQueryReturnsNothing() {
        XCTAssertTrue(Autocomplete.staticMatches("", in: fruits, max: 5).isEmpty)
    }

    func testCaseInsensitiveMatch() {
        let matches = Autocomplete.staticMatches("AP", in: fruits, max: 5)
        XCTAssertEqual(matches, ["Apple", "Apricot"])
    }

    func testRespectsMaxResults() {
        // "a" matches Apple, Apricot, Banana, Avocado — capped at 2.
        XCTAssertEqual(Autocomplete.staticMatches("a", in: fruits, max: 2).count, 2)
    }

    func testNoMatch() {
        XCTAssertTrue(Autocomplete.staticMatches("zzz", in: fruits, max: 5).isEmpty)
    }
}
