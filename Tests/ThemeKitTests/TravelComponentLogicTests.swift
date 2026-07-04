//
//  TravelComponentLogicTests.swift
//  ThemeKitTests
//
//  Unit tests for the pure logic extracted out of the travel components
//  (formatting, capacity maths, derived identity). Views stay declarative;
//  the arithmetic is testable. Written with XCTest to match the rest of the
//  suite (the Swift Testing runner SIGTRAPs on this toolchain).
//

import XCTest
@testable import ThemeKit

final class TravelComponentLogicTests: XCTestCase {

    // MARK: - PriceTag discount

    func testDiscountPercentRoundsAndGuards() {
        XCTAssertEqual(PriceTag.discountPercent(original: 1_899, amount: 1_299), 32)
        XCTAssertEqual(PriceTag.discountPercent(original: 100, amount: 75), 25)
        XCTAssertNil(PriceTag.discountPercent(original: nil, amount: 100))
        XCTAssertNil(PriceTag.discountPercent(original: 100, amount: 100))   // no saving
        XCTAssertNil(PriceTag.discountPercent(original: 100, amount: 120))   // amount > original
        XCTAssertNil(PriceTag.discountPercent(original: 0, amount: 0))
    }

    // MARK: - CountdownTimer formatting

    func testSegmentsRollDaysIntoHoursByDefault() {
        let segs = CountdownTimer.segments(86_400 + 3_720, showsDays: false)   // 1d 1h 2m
        XCTAssertEqual(segs.map { $0.value }, [25, 2, 0])
        XCTAssertEqual(segs.map { $0.label }, ["hrs", "min", "sec"])
    }

    func testSegmentsKeepDaysWhenRequested() {
        let segs = CountdownTimer.segments(86_400 + 3_720, showsDays: true)
        XCTAssertEqual(segs.map { $0.value }, [1, 1, 2, 0])
    }

    func testInlineIsZeroPadded() {
        XCTAssertEqual(CountdownTimer.inlineString(9 * 60 + 58, showsDays: false), "00:09:58")
    }

    func testCompactTakesTopTwoNonZeroUnits() {
        XCTAssertEqual(CountdownTimer.compactString(9 * 60 + 58, showsDays: false), "9m 58s")
        XCTAssertEqual(CountdownTimer.compactString(0, showsDays: false), "0s")
        XCTAssertEqual(CountdownTimer.compactString(2 * 86_400 + 3 * 3_600, showsDays: true), "2d 3h")
    }

    func testPad2IsSixtyFourBitSafe() {
        XCTAssertEqual(CountdownTimer.pad2(3), "03")
        XCTAssertEqual(CountdownTimer.pad2(58), "58")
        XCTAssertEqual(CountdownTimer.pad2(125), "125")
    }

    // MARK: - GuestSelector capacity

    func testGuestCountSumsGuestsNotRooms() {
        XCTAssertEqual(GuestSelection(rooms: 3, adults: 2, children: 1, infants: 1).guestCount, 4)
    }

    func testCappedUpperBoundRespectsCapacityAndRange() {
        XCTAssertEqual(GuestSelector.cappedUpperBound(range: 0...10, current: 1, remaining: 2), 3)
        XCTAssertEqual(GuestSelector.cappedUpperBound(range: 0...10, current: 2, remaining: 0), 2)   // full
        XCTAssertEqual(GuestSelector.cappedUpperBound(range: 1...16, current: 1, remaining: 0), 1)   // >= lower
        XCTAssertEqual(GuestSelector.cappedUpperBound(range: 0...5, current: 4, remaining: 10), 5)   // <= upper
    }

    // MARK: - Currency flag

    func testCurrencyFlagDerivesFromCode() {
        XCTAssertEqual(Currency(code: "TRY", symbol: "₺", name: "Turkish Lira").flag, "🇹🇷")
        XCTAssertEqual(Currency(code: "USD", symbol: "$", name: "US Dollar").flag, "🇺🇸")
        XCTAssertEqual(Currency(code: "GBP", symbol: "£", name: "British Pound").flag, "🇬🇧")
    }

    // MARK: - Stable, content-derived identity

    func testFareLineIdIsStableAndKindAware() {
        let a = FareLine.item("Base fare", 1_100)
        let b = FareLine.item("Base fare", 999)          // same label + kind → same id
        let c = FareLine.discount("Base fare", 1_100)    // different kind → different id
        XCTAssertEqual(a.id, b.id)
        XCTAssertNotEqual(a.id, c.id)
        XCTAssertEqual(a.id, "item:Base fare")
    }

    func testFlightLegIdIsStableForSameRouteAndTime() {
        let dep = Date(timeIntervalSinceReferenceDate: 1_000)
        let arr = dep.addingTimeInterval(3_600)
        let leg1 = FlightLeg(airline: "AA", from: "IST", to: "ESB", departure: dep, arrival: arr)
        let leg2 = FlightLeg(airline: "BB", from: "IST", to: "ESB", departure: dep, arrival: arr)
        XCTAssertEqual(leg1.id, leg2.id)                 // id is route + time, airline-independent
        XCTAssertEqual(leg1, FlightLeg(airline: "AA", from: "IST", to: "ESB", departure: dep, arrival: arr))
    }
}
