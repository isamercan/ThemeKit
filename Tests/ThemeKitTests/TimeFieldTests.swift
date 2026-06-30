//
//  TimeFieldTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 30.06.2026.
//
//  Coverage for TimeField's pure helpers: time-of-day formatting (locale / 12h /
//  24h) and minute-interval rounding. Dates are built in the *current* calendar so
//  the wall-clock time is preserved when formatted with the default timezone.
//

import XCTest
@testable import ThemeKit

final class TimeFieldTests: XCTestCase {

    private let enUS = Locale(identifier: "en_US")

    private func time(_ hour: Int, _ minute: Int) -> Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 5; c.hour = hour; c.minute = minute
        return Calendar.current.date(from: c)!
    }

    private func minute(of date: Date) -> Int {
        Calendar.current.component(.minute, from: date)
    }

    private func hour(of date: Date) -> Int {
        Calendar.current.component(.hour, from: date)
    }

    // MARK: - Formatting

    func test24HourCycle() {
        XCTAssertEqual(TimeField.text(for: time(14, 30), hourCycle: .h24, locale: enUS), "14:30")
        XCTAssertEqual(TimeField.text(for: time(9, 5), hourCycle: .h24, locale: enUS), "09:05")
    }

    func test12HourCycleHasMeridiem() {
        let pm = TimeField.text(for: time(14, 30), hourCycle: .h12, locale: enUS)
        XCTAssertEqual(pm, "2:30 PM")
        let am = TimeField.text(for: time(9, 5), hourCycle: .h12, locale: enUS)
        XCTAssertEqual(am, "9:05 AM")
    }

    func test24HourCycleHasNoMeridiem() {
        let s = TimeField.text(for: time(14, 30), hourCycle: .h24, locale: enUS)
        XCTAssertFalse(s.contains("AM") || s.contains("PM"), s)
    }

    func testLocaleCycleDiffersByLocale() {
        // en_US shortened time is 12-hour (AM/PM); tr_TR is 24-hour → different strings.
        let us = TimeField.text(for: time(14, 30), hourCycle: .locale, locale: enUS)
        let tr = TimeField.text(for: time(14, 30), hourCycle: .locale, locale: Locale(identifier: "tr_TR"))
        XCTAssertNotEqual(us, tr)
    }

    // MARK: - Minute-interval rounding

    func testRoundDownToInterval() {
        XCTAssertEqual(minute(of: TimeField.rounded(time(14, 7), toMinuteInterval: 15)), 0)
    }

    func testRoundUpToInterval() {
        XCTAssertEqual(minute(of: TimeField.rounded(time(14, 8), toMinuteInterval: 15)), 15)
    }

    func testRoundCarriesIntoNextHour() {
        let r = TimeField.rounded(time(14, 53), toMinuteInterval: 15)
        XCTAssertEqual(minute(of: r), 0)
        XCTAssertEqual(hour(of: r), 15)
    }

    func testIntervalOfOneOrLessIsUnchanged() {
        let d = time(14, 37)
        XCTAssertEqual(TimeField.rounded(d, toMinuteInterval: 1), d)
        XCTAssertEqual(TimeField.rounded(d, toMinuteInterval: 0), d)
    }

    func testFiveMinuteInterval() {
        XCTAssertEqual(minute(of: TimeField.rounded(time(10, 12), toMinuteInterval: 5)), 10)
        XCTAssertEqual(minute(of: TimeField.rounded(time(10, 13), toMinuteInterval: 5)), 15)
    }
}
