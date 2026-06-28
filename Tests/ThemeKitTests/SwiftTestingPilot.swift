//
//  SwiftTestingPilot.swift
//  ThemeKit
//
//  Pilot for the modern Swift Testing framework (`@Test` / `#expect` / parameterized
//  `arguments:`) alongside the existing XCTest suites. Targets pure, deterministic
//  logic so it runs anywhere `swift test` does. New tests can follow this style;
//  the XCTest suites migrate opportunistically.
//

import Testing
import Foundation
@testable import ThemeKit

@Suite("DateField formatting")
struct DateFieldFormattingTests {
    /// 2026-01-05 at noon UTC — a Monday; noon keeps the day stable across realistic
    /// timezones so date-only assertions don't flake.
    private var jan5: Date {
        var c = DateComponents()
        c.year = 2026; c.month = 1; c.day = 5; c.hour = 12
        c.timeZone = TimeZone(identifier: "UTC")
        return Calendar(identifier: .gregorian).date(from: c)!
    }
    private let enUS = Locale(identifier: "en_US")

    @Test("en-US date styles render the expected string", arguments: [
        (DateFieldStyle.abbreviated, "Jan 5, 2026"),
        (DateFieldStyle.numeric, "1/5/2026"),
        (DateFieldStyle.long, "January 5, 2026"),
    ])
    func formats(_ style: DateFieldStyle, _ expected: String) {
        #expect(DateField.text(for: jan5, style: style, locale: enUS, components: .date) == expected)
    }

    @Test("a custom pattern is honoured verbatim")
    func customPattern() {
        let out = DateField.text(for: jan5, style: .custom("yyyy-MM-dd"), locale: enUS, components: .date)
        #expect(out == "2026-01-05")
    }
}
