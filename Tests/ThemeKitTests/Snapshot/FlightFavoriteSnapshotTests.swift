//
//  FlightFavoriteSnapshotTests.swift
//  ThemeKitTests
//
//  Guards unit F2.4 — the dual-mode favourite heart across the flight family.
//  For each of the 9 FlightListItem styles a pair is rendered: an uncontrolled
//  `.favorite()` (heart off) over a controlled `.favorite(.constant(true))`
//  (heart on, error-tone fill), so both glyph states and every style's heart
//  placement are pinned. A final case guards the parity sweep on
//  FlightCard / FlightResultRow / FlightTicketCard, including the no-arg
//  bookmark overload.
//
//  Opt-in like the rest of the visual suite: set RUN_SNAPSHOTS=1 on the
//  scheme's Test action (see docs/SNAPSHOT-TESTING.md).
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class FlightFavoriteSnapshotTests: SnapshotTestCase {

    // Fixed instants keep the rendered times deterministic across runs.
    private static let dep = Date(timeIntervalSince1970: 1_781_000_000)
    private static let arr = dep.addingTimeInterval(3.5 * 3600)

    /// A data-rich itinerary so every archetype has something to lay out
    /// (fares → .fareBoard, departures → .timetable, deal/trend → .deal,
    /// two legs → .slices/.journey).
    private func baseItem() -> FlightListItem {
        let out = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                            departure: Self.dep, arrival: Self.arr)
        let back = FlightLeg(airline: "Skyline Air", from: "LHR", to: "IST",
                             departure: Self.arr.addingTimeInterval(72 * 3600),
                             arrival: Self.arr.addingTimeInterval(75.5 * 3600))
        return FlightListItem(legs: [out, back])
            .sliceLabels(["Outbound", "Return"])
            .flightNo("SK 1123")
            .cabin("Economy")
            .price(214, currencyCode: "USD", caption: "from")
            .original(268)
            .deal("23% below typical", tone: .success)
            .trend([0.8, 0.75, 0.9, 0.6, 0.5, 0.42])
            .fares([
                FlightFare("Basic", price: 214),
                FlightFare("Flex", price: 289),
            ])
            .departures([Self.dep, Self.dep.addingTimeInterval(2 * 3600)], note: "Nonstop · every ~2h")
            .badge("Best")
            .baggage("8kg", checked: "23kg")
            .onSelect { }
            .onDetails { }
    }

    /// Heart off (uncontrolled `.favorite()`) over heart on (controlled
    /// `.favorite(.constant(true))`) under one style.
    private func assertPair<S: FlightListItemStyle>(
        _ style: sending S,
        named name: String,
        file: StaticString = #filePath,
        testName: String = #function,
        line: UInt = #line
    ) {
        assertComponentSnapshot(
            VStack(spacing: 12) {
                baseItem().favorite()
                baseItem().favorite(.constant(true))
            }
            .flightListItemStyle(style)
            .padding(8),
            named: name,
            file: file,
            testName: testName,
            line: line
        )
    }

    func testFlightFavorite_parity() {
        // All 9 built-in FlightListItem styles × (heart off / heart on).
        assertPair(.compact, named: "compact")
        assertPair(.timeline, named: "timeline")
        assertPair(.fareBoard, named: "fareBoard")
        assertPair(.deal, named: "deal")
        assertPair(.ticket, named: "ticket")
        assertPair(.journey, named: "journey")
        assertPair(.slices, named: "slices")
        assertPair(.timetable, named: "timetable")
        assertPair(.tray, named: "tray")

        // Heart parity sweep — the sibling flight components' uncontrolled
        // overloads (and FlightResultRow's no-arg bookmark).
        assertComponentSnapshot(
            VStack(spacing: 12) {
                FlightCard(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: Self.dep, arrival: Self.arr)
                    .price(214, currencyCode: "USD").favorite()
                FlightCard(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: Self.dep, arrival: Self.arr)
                    .price(214, currencyCode: "USD").favorite(.constant(true))
                FlightResultRow(airline: "Skyline Air", from: "IST", to: "LHR",
                                departure: Self.dep, arrival: Self.arr)
                    .flightNo("SK 1123").price(214, currencyCode: "USD")
                    .favorite().bookmark()
                FlightResultRow(airline: "Skyline Air", from: "IST", to: "LHR",
                                departure: Self.dep, arrival: Self.arr)
                    .flightNo("SK 1123").price(214, currencyCode: "USD")
                    .favorite(.constant(true)).bookmark(.constant(true))
                FlightTicketCard(from: "IST", to: "LHR")
                    .times(departure: "10:00", arrival: "13:30").duration("3h 30m")
                    .airline("Skyline Air").price(214, currencyCode: "USD")
                    .favorite()
                FlightTicketCard(from: "IST", to: "LHR")
                    .times(departure: "10:00", arrival: "13:30").duration("3h 30m")
                    .airline("Skyline Air").price(214, currencyCode: "USD")
                    .favorite(.constant(true))
            }
            .padding(8),
            named: "cards-parity"
        )
    }
}
#endif
