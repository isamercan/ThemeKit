//
//  DateFieldTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 26.06.2026.
//
//  Coverage for DateField's pure date formatting (style / locale / custom pattern).
//  Time-of-day output is timezone-dependent and intentionally not asserted here.
//

import XCTest
@testable import ThemeKit

final class DateFieldTests: XCTestCase {

    private let enUS = Locale(identifier: "en_US")

    /// 2026-01-05 at noon UTC — a Monday; noon keeps the day stable across realistic
    /// timezones so date-only assertions don't flake.
    private func jan5() -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 5; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }

    private func text(_ style: DateFieldStyle, _ locale: Locale, _ components: DateFieldComponents = .date) -> String {
        DateField.text(for: jan5(), style: style, locale: locale, components: components)
    }

    func testAbbreviated() {
        XCTAssertEqual(text(.abbreviated, enUS), "Jan 5, 2026")
    }

    func testNumeric() {
        XCTAssertEqual(text(.numeric, enUS), "1/5/2026")
    }

    func testLong() {
        XCTAssertEqual(text(.long, enUS), "January 5, 2026")
    }

    func testFullIncludesWeekday() {
        let s = text(.full, enUS)
        XCTAssertTrue(s.contains("Monday"), s)
        XCTAssertTrue(s.contains("January 5"), s)
    }

    func testCustomPatternIsLocaleIndependentForNumericTokens() {
        XCTAssertEqual(text(.custom("yyyy-MM-dd"), enUS), "2026-01-05")
    }

    func testLocaleChangesMonthName() {
        // Same style, different locale → different rendering.
        XCTAssertNotEqual(text(.abbreviated, enUS), text(.abbreviated, Locale(identifier: "tr_TR")))
    }
}
