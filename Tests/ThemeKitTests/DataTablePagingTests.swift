//
//  DataTablePagingTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for DataTable's pure paging math (page count + per-page index range).
//

import XCTest
@testable import ThemeKit

final class DataTablePagingTests: XCTestCase {

    private struct TableRow: Identifiable { let id: Int }
    private typealias Table = DataTable<TableRow>

    // MARK: - pageCount

    func testPageCountOffWhenNoPageSize() {
        XCTAssertEqual(Table.pageCount(rowCount: 10, pageSize: nil), 1)
        XCTAssertEqual(Table.pageCount(rowCount: 10, pageSize: 0), 1)
    }

    func testPageCountRoundsUp() {
        XCTAssertEqual(Table.pageCount(rowCount: 10, pageSize: 3), 4)
        XCTAssertEqual(Table.pageCount(rowCount: 9, pageSize: 3), 3)
    }

    func testPageCountFewerRowsThanPageSize() {
        XCTAssertEqual(Table.pageCount(rowCount: 3, pageSize: 5), 1)
    }

    func testPageCountEmpty() {
        XCTAssertEqual(Table.pageCount(rowCount: 0, pageSize: 5), 1)
    }

    // MARK: - pageRange

    func testFirstPageRange() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: 3, page: 1), 0..<3)
    }

    func testMiddlePageRange() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: 3, page: 2), 3..<6)
    }

    func testLastPageIsPartial() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: 3, page: 4), 9..<10)
    }

    func testPageBeyondEndClampsToLast() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: 3, page: 99), 9..<10)
    }

    func testPageBelowOneClampsToFirst() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: 3, page: 0), 0..<3)
    }

    func testRangeIsFullWhenPagingOff() {
        XCTAssertEqual(Table.pageRange(rowCount: 10, pageSize: nil, page: 1), 0..<10)
    }
}
