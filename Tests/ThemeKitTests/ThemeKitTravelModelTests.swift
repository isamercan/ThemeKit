import XCTest
import ThemeKit
import ThemeKitTravel

/// Contract tests for the ThemeKitTravel canonical model layer (ADR-F3 §4.2):
/// `PassengerCount` clamps, `TripSearchDraft` route-swap + date ordering, and
/// `SavedCard` expiry math + Codable round-trip. All dates are built from fixed
/// components (UTC Gregorian) — never `Date.now` — so the suite is deterministic.
final class ThemeKitTravelModelTests: XCTestCase {

    // MARK: - Fixtures

    /// UTC Gregorian, independent of the runner's locale/timezone.
    private let calendar: Calendar = {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        return cal
    }()

    private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day))!
    }

    // MARK: - PassengerCount clamps

    func testPassengerCountInitClampsAdultsToMinimumOne() {
        XCTAssertEqual(PassengerCount(adults: 0).adults, 1)
        XCTAssertEqual(PassengerCount(adults: -3).adults, 1)
        XCTAssertEqual(PassengerCount(adults: 2).adults, 2)
    }

    func testPassengerCountInitClampsChildrenAndInfantsToNonNegative() {
        let count = PassengerCount(adults: 1, children: -2, infants: -1)
        XCTAssertEqual(count.children, 0)
        XCTAssertEqual(count.infants, 0)
    }

    func testPassengerCountMutationReclamps() {
        var count = PassengerCount(adults: 2, children: 1, infants: 1)
        count.adults = 0
        count.children = -5
        count.infants = -1
        XCTAssertEqual(count.adults, 1)
        XCTAssertEqual(count.children, 0)
        XCTAssertEqual(count.infants, 0)
    }

    func testPassengerCountTotalSumsAllBands() {
        XCTAssertEqual(PassengerCount(adults: 2, children: 3, infants: 1).total, 6)
        XCTAssertEqual(PassengerCount().total, 1)   // default: 1 adult
    }

    func testPassengerCountDecodeClampsInvalidPayload() throws {
        let json = Data(#"{"adults":0,"children":-4,"infants":-1}"#.utf8)
        let decoded = try JSONDecoder().decode(PassengerCount.self, from: json)
        XCTAssertEqual(decoded, PassengerCount(adults: 1, children: 0, infants: 0))
    }

    // MARK: - TripSearchDraft

    func testSwapRouteExchangesOriginAndDestination() {
        let ist = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
        let lhr = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
        var draft = TripSearchDraft()
        draft.origin = ist
        draft.destination = lhr

        draft.swapRoute()
        XCTAssertEqual(draft.origin, lhr)
        XCTAssertEqual(draft.destination, ist)

        // Swapping with one side empty just moves the value across.
        draft.destination = nil
        draft.swapRoute()
        XCTAssertNil(draft.origin)
        XCTAssertEqual(draft.destination, lhr)
    }

    func testSettingReturnDateBeforeDepartureClampsToDeparture() {
        var draft = TripSearchDraft()
        draft.departureDate = date(2027, 6, 10)
        draft.returnDate = date(2027, 6, 5)
        XCTAssertEqual(draft.returnDate, date(2027, 6, 10))
    }

    func testMovingDepartureAfterReturnPullsReturnForward() {
        var draft = TripSearchDraft()
        draft.departureDate = date(2027, 6, 1)
        draft.returnDate = date(2027, 6, 4)
        draft.departureDate = date(2027, 6, 20)
        XCTAssertEqual(draft.returnDate, date(2027, 6, 20))
    }

    func testOrderedDatesAreLeftUntouched() {
        var draft = TripSearchDraft()
        draft.departureDate = date(2027, 6, 1)
        draft.returnDate = date(2027, 6, 8)
        XCTAssertEqual(draft.departureDate, date(2027, 6, 1))
        XCTAssertEqual(draft.returnDate, date(2027, 6, 8))
    }

    // MARK: - SavedCard.isExpired

    func testCardExpiredWhenMonthHasPassed() {
        let card = SavedCard(id: "c1", brand: .visa, last4: "4242", expiryMonth: 3, expiryYear: 2026)
        // Valid through the last instant of March 2026 — April 1 is expired.
        XCTAssertTrue(card.isExpired(asOf: date(2026, 4, 1), calendar: calendar))
        XCTAssertFalse(card.isExpired(asOf: date(2026, 3, 31), calendar: calendar))
    }

    func testCardNotExpiredForFutureExpiry() {
        let card = SavedCard(id: "c2", brand: .mastercard, last4: "5100", expiryMonth: 12, expiryYear: 2030)
        XCTAssertFalse(card.isExpired(asOf: date(2026, 7, 11), calendar: calendar))
    }

    func testTwoDigitExpiryYearIsTreatedAs2000Based() {
        let card = SavedCard(id: "c3", brand: .visa, last4: "0001", expiryMonth: 5, expiryYear: 24)
        XCTAssertTrue(card.isExpired(asOf: date(2026, 1, 1), calendar: calendar))    // 05/24 passed
        XCTAssertFalse(card.isExpired(asOf: date(2024, 5, 15), calendar: calendar))  // still in-month
    }

    func testMissingExpiryReadsAsNotExpired() {
        let card = SavedCard(id: "c4", brand: .amex, last4: "0005")
        XCTAssertFalse(card.isExpired(asOf: date(2099, 1, 1), calendar: calendar))
    }

    func testExpiryMonthClampsInto1Through12() {
        XCTAssertEqual(SavedCard(id: "c5", brand: .visa, last4: "1111", expiryMonth: 0, expiryYear: 2027).expiryMonth, 1)
        XCTAssertEqual(SavedCard(id: "c6", brand: .visa, last4: "2222", expiryMonth: 13, expiryYear: 2027).expiryMonth, 12)
    }

    // MARK: - SavedCard Codable round-trip

    func testSavedCardCodableRoundTrip() throws {
        let card = SavedCard(id: "wallet-1", brand: .troy, last4: "9792",
                             holder: "Alex Traveler", expiryMonth: 9, expiryYear: 2028)
        let decoded = try JSONDecoder().decode(SavedCard.self, from: JSONEncoder().encode(card))
        XCTAssertEqual(decoded, card)
    }
}
