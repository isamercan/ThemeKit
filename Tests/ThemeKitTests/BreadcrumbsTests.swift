//
//  BreadcrumbsTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for Breadcrumbs' pure collapse logic (middle → "…").
//

import XCTest
@testable import ThemeKit

final class BreadcrumbsTests: XCTestCase {

    private typealias Entry = Breadcrumbs.Entry

    func testNoMaxItemsShowsAll() {
        XCTAssertEqual(Breadcrumbs.collapse(count: 4, maxItems: nil),
                       [.crumb(0), .crumb(1), .crumb(2), .crumb(3)])
    }

    func testWithinLimitShowsAll() {
        XCTAssertEqual(Breadcrumbs.collapse(count: 3, maxItems: 4),
                       [.crumb(0), .crumb(1), .crumb(2)])
    }

    func testCollapsesMiddleKeepingFirstAndLast() {
        // 5 crumbs, max 3 → first + ellipsis(1,2,3) + last.
        XCTAssertEqual(Breadcrumbs.collapse(count: 5, maxItems: 3),
                       [.crumb(0), .ellipsis([1, 2, 3]), .crumb(4)])
    }

    func testKeepsMoreTailWhenMaxItemsLarger() {
        // 6 crumbs, max 4 → first + ellipsis(1,2,3) + last two.
        XCTAssertEqual(Breadcrumbs.collapse(count: 6, maxItems: 4),
                       [.crumb(0), .ellipsis([1, 2, 3]), .crumb(4), .crumb(5)])
    }

    func testTinyMaxItemsStillKeepsEnds() {
        XCTAssertEqual(Breadcrumbs.collapse(count: 5, maxItems: 1),
                       [.crumb(0), .ellipsis([1, 2, 3]), .crumb(4)])
    }
}
