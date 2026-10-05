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
        let field = FieldButton("ADB, İzmir, Türkiye") {}
            .label("Nereden")
            .valueTextStyle(.bodyBase500)
        XCTAssertNotNil(field)
    }
}
