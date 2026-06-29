//
//  SearchBarTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for SearchBar's dropdown presentation logic — which list (recent /
//  suggestions / loading / empty) shows for a given field state.
//

import XCTest
@testable import ThemeKit

final class SearchBarTests: XCTestCase {

    private typealias Content = SearchBar.DropdownContent

    private func content(
        text: String = "",
        isFocused: Bool = true,
        recent: [String] = [],
        results: [String] = [],
        isLoading: Bool = false,
        hasSuggestions: Bool = true,
        maxRecent: Int = 6
    ) -> Content {
        SearchBar.dropdownContent(
            text: text, isFocused: isFocused, recent: recent, results: results,
            isLoading: isLoading, hasSuggestions: hasSuggestions, maxRecent: maxRecent
        )
    }

    func testHiddenWhenNotFocused() {
        XCTAssertEqual(content(isFocused: false, recent: ["a"]), .hidden)
    }

    func testEmptyFieldWithoutRecentIsHidden() {
        XCTAssertEqual(content(text: "", recent: []), .hidden)
    }

    func testEmptyFieldShowsRecent() {
        XCTAssertEqual(content(text: "", recent: ["Istanbul", "Bursa"]), .recent(["Istanbul", "Bursa"]))
    }

    func testRecentIsCappedAtMaxRecent() {
        XCTAssertEqual(content(text: "", recent: ["a", "b", "c"], maxRecent: 2), .recent(["a", "b"]))
    }

    func testTypingWithoutSuggestionSourceIsHidden() {
        // No suggestion source configured → classic bar, no dropdown.
        XCTAssertEqual(content(text: "ist", hasSuggestions: false), .hidden)
    }

    func testLoadingTakesPrecedenceOverResults() {
        XCTAssertEqual(content(text: "ist", results: ["stale"], isLoading: true), .loading)
    }

    func testEmptyResultsShowNoResults() {
        XCTAssertEqual(content(text: "zzz", results: []), .noResults)
    }

    func testMatchingResultsAreShown() {
        XCTAssertEqual(content(text: "ist", results: ["Istanbul"]), .results(["Istanbul"]))
    }
}
