//
//  PaginationTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for Pagination's pure page-window builder (-1 = ellipsis sentinel).
//

import XCTest
@testable import ThemeKit

final class PaginationTests: XCTestCase {

    private func window(_ current: Int, _ total: Int, sib: Int = 1, bound: Int = 1) -> [Int] {
        Pagination.pageWindow(current: current, total: total, siblingCount: sib, boundaryCount: bound)
    }

    func testSmallTotalHasNoEllipsis() {
        XCTAssertEqual(window(3, 5), [1, 2, 3, 4, 5])
    }

    func testEllipsisAtEndNearStart() {
        XCTAssertEqual(window(2, 10), [1, 2, 3, -1, 10])
    }

    func testEllipsisAtStartNearEnd() {
        XCTAssertEqual(window(9, 10), [1, -1, 8, 9, 10])
    }

    func testEllipsisBothSidesInMiddle() {
        XCTAssertEqual(window(6, 10), [1, -1, 5, 6, 7, -1, 10])
    }

    func testLoneGapIsFilledNotHidden() {
        // total 7 → every page fits once boundaries+siblings expand, no ellipsis.
        XCTAssertEqual(window(4, 7), [1, 2, 3, 4, 5, 6, 7])
    }

    func testSiblingCountWidensWindow() {
        XCTAssertEqual(window(10, 20, sib: 2), [1, -1, 8, 9, 10, 11, 12, -1, 20])
    }

    func testBoundaryCountShowsMoreEnds() {
        XCTAssertEqual(window(10, 20, sib: 1, bound: 2), [1, 2, -1, 9, 10, 11, -1, 19, 20])
    }

    func testCurrentIsClampedIntoRange() {
        XCTAssertEqual(window(999, 10), [1, -1, 9, 10])
    }

    func testSinglePage() {
        XCTAssertEqual(window(1, 1), [1])
    }

    func testZeroTotalIsEmpty() {
        XCTAssertEqual(window(1, 0), [])
    }
}
