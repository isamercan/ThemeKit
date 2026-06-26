//
//  TableSortKeyTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for DataTable's comparable sort key (the core new sorting logic).
//

import Foundation
import XCTest
@testable import ThemeKit

final class TableSortKeyTests: XCTestCase {

    func testNumberOrdering() {
        XCTAssertTrue(TableSortKey.number(1) < TableSortKey.number(2))
        XCTAssertFalse(TableSortKey.number(2) < TableSortKey.number(1))
    }

    func testStringUsesNaturalNumericOrdering() {
        // "item2" before "item10" (lexicographic would reverse these).
        XCTAssertTrue(TableSortKey.string("item2") < TableSortKey.string("item10"))
    }

    func testDateOrdering() {
        let earlier = Date(timeIntervalSince1970: 0)
        let later = Date(timeIntervalSince1970: 100)
        XCTAssertTrue(TableSortKey.date(earlier) < TableSortKey.date(later))
    }

    func testSortingRowsByKey() {
        let values = [3.0, 1.0, 2.0]
        let sorted = values.sorted { TableSortKey.number($0) < TableSortKey.number($1) }
        XCTAssertEqual(sorted, [1.0, 2.0, 3.0])
    }
}
