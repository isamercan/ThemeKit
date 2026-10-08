//
//  DateWheelPickerTests.swift
//  ThemeKitTests
//  Created by İsa Mercan on 02.10.2026.
//

import XCTest
import SwiftUI
@testable import ThemeKit

final class DateWheelPickerTests: XCTestCase {

    private let calendar = Calendar(identifier: .gregorian)

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    func testADayTheMonthLacksMovesToItsLastDay() {
        XCTAssertEqual(DateWheelPicker.date(day: 31, month: 2, year: 2023, in: calendar, within: nil), day(2023, 2, 28))
        XCTAssertEqual(DateWheelPicker.date(day: 31, month: 2, year: 2024, in: calendar, within: nil), day(2024, 2, 29))
        XCTAssertEqual(DateWheelPicker.date(day: 31, month: 4, year: 2024, in: calendar, within: nil), day(2024, 4, 30))
    }

    func testTheRangeStopsTheDateAtItsEnds() {
        let range = day(1990, 1, 1)...day(2000, 12, 31)

        XCTAssertEqual(DateWheelPicker.date(day: 5, month: 6, year: 1985, in: calendar, within: range), day(1990, 1, 1))
        XCTAssertEqual(DateWheelPicker.date(day: 5, month: 6, year: 2010, in: calendar, within: range), day(2000, 12, 31))
        XCTAssertEqual(DateWheelPicker.date(day: 9, month: 12, year: 1994, in: calendar, within: range), day(1994, 12, 9))
    }

    func testAColumnShowsFiveRowsOfFortyWithFourBetween() {
        XCTAssertEqual(DateWheelColumn.height, 5 * 40 + 4 * 4)
        XCTAssertEqual(DateWheelColumn.pitch, 44)
    }

    func testDaysAndMonthsWrapYearsStop() {
        XCTAssertEqual(DateWheelColumn.index(12, count: 12, cyclic: true), 0, "after December comes January")
        XCTAssertEqual(DateWheelColumn.index(-1, count: 12, cyclic: true), 11)
        XCTAssertEqual(DateWheelColumn.index(130, count: 121, cyclic: false), 120)
        XCTAssertNil(DateWheelColumn.resolved(-1, count: 121, cyclic: false), "nothing drawn before the first year")
        XCTAssertEqual(DateWheelColumn.resolved(13, count: 12, cyclic: true), 1)
    }

    func testASelectionOutsideTheRangeShowsAtItsNearerEnd() {
        let range = day(1927, 10, 9)...day(2014, 10, 9)

        XCTAssertEqual(DateWheelPicker.shown(day(2026, 10, 9), within: range), day(2014, 10, 9),
                       "a date after the range shows at its end, not at the first year")
        XCTAssertEqual(DateWheelPicker.shown(day(1900, 1, 1), within: range), day(1927, 10, 9))
        XCTAssertEqual(DateWheelPicker.shown(day(1990, 5, 5), within: range), day(1990, 5, 5))
        XCTAssertEqual(DateWheelPicker.shown(day(2026, 10, 9), within: nil), day(2026, 10, 9))
    }

    func testTheYearsAreTheRangesElseACenturyBackAndTwentyOn() {
        XCTAssertEqual(DateWheelPicker.years(in: day(1927, 10, 9)...day(2014, 10, 9), calendar: calendar),
                       Array(1927...2014))
        XCTAssertEqual(DateWheelPicker.years(in: nil, calendar: calendar, now: day(2026, 10, 7)), Array(1926...2046))
    }

    func testAFlingLandsOnAWholeRowAndAYearColumnStopsAtItsEnds() {
        XCTAssertEqual(DateWheelColumn.landing(12.4, count: 88, cyclic: false), 12)
        XCTAssertEqual(DateWheelColumn.landing(130.7, count: 88, cyclic: false), 87)
        XCTAssertEqual(DateWheelColumn.landing(-6, count: 88, cyclic: false), 0)
        XCTAssertEqual(DateWheelColumn.landing(40.6, count: 12, cyclic: true), 41, "a cyclic drum keeps its turns")
    }

    func testATapTurnsACyclicDrumTheShortWayRound() {
        XCTAssertEqual(DateWheelColumn.nearest(0, from: 11, count: 12, cyclic: true), 12, "December → January goes on")
        XCTAssertEqual(DateWheelColumn.nearest(11, from: 0, count: 12, cyclic: true), -1, "January → December goes back")
        XCTAssertEqual(DateWheelColumn.nearest(5, from: 26.2, count: 12, cyclic: true), 29)
        XCTAssertEqual(DateWheelColumn.nearest(5, from: 30, count: 88, cyclic: false), 5)
    }

    func testALongerSpinTakesLongerButNoMoreThanASecondAndAQuarter() {
        XCTAssertEqual(DateWheelColumn.spinDuration(rows: 0), 0.2, accuracy: 0.001)
        XCTAssertLessThan(DateWheelColumn.spinDuration(rows: 1), DateWheelColumn.spinDuration(rows: 25))
        XCTAssertEqual(DateWheelColumn.spinDuration(rows: 400), 1.25)
    }

    @MainActor
    func testItBuildsWithAStyle() {
        struct Plain: DateWheelPickerStyle {
            func makeRow(configuration: DateWheelPickerRowConfiguration) -> some View { Text(configuration.label) }
            func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> some View { Text(configuration.title) }
        }
        let view = DateWheelPicker(selection: .constant(day(1994, 12, 9)))
            .columnTitles(day: "Day", month: "Month", year: "Year")
            .dateWheelPickerStyle(Plain())
        XCTAssertNotNil(view)
    }

    /// A style draws the choice's band itself; one that doesn't draws none, as before.
    @MainActor
    func testAStyleCanDrawTheSelectionBand() {
        struct Banded: DateWheelPickerStyle {
            func makeRow(configuration: DateWheelPickerRowConfiguration) -> some View { Text(configuration.label) }
            func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> some View { Text(configuration.title) }
            func makeSelectionBand(configuration: DateWheelPickerSelectionConfiguration) -> some View {
                Capsule().fill(configuration.isEnabled ? Color.blue : Color.gray)
            }
        }
        struct Bandless: DateWheelPickerStyle {
            func makeRow(configuration: DateWheelPickerRowConfiguration) -> some View { Text(configuration.label) }
            func makeHeader(configuration: DateWheelPickerHeaderConfiguration) -> some View { Text(configuration.title) }
        }
        XCTAssertTrue(Bandless.SelectionBand.self == EmptyView.self, "no band unless a style draws one")
        XCTAssertFalse(DefaultDateWheelPickerStyle.SelectionBand.self == EmptyView.self, "ThemeKit's style draws one")
        let view = DateWheelPicker(selection: .constant(day(1994, 12, 9))).dateWheelPickerStyle(Banded())
        XCTAssertNotNil(view)
    }

    @MainActor
    func testTheFloatingLabelTakesTheStyleItIsGiven() {
        let field = TextInput("First name", text: .constant("Ada")).floatingLabelTextStyle(.overline400)
        XCTAssertNotNil(field)
    }
}

final class FieldButtonErrorTests: XCTestCase {
    @MainActor
    func testAnErrorAndALabelStyleCanBeSet() {
        let field = FieldButton("Turkey") {}
            .label("Passport nationality")
            .labelTextStyle(.overline400)
            .errorText("This field is required.")
        XCTAssertNotNil(field)
    }

    @MainActor
    func testTheValuesStyleCanBeSet() {
        let field = FieldButton("IST, Istanbul") {}
            .label("From")
            .valueTextStyle(.bodyBase500)
        XCTAssertNotNil(field)
    }
}
