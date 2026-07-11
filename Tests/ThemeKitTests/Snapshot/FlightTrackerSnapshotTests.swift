//
//  FlightTrackerSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel `FlightTracker` organism
//  (F3.3). Opt-in + iOS-only (see SnapshotSupport.swift); records references on
//  the pinned Simulator, skips in CI. All dates are fixed
//  `timeIntervalSinceReferenceDate` values so the rendered times (and the
//  struck-through schedule-vs-estimate rows) are reproducible; the relative
//  "Updated…" caption is deliberately not snapshotted.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class FlightTrackerSnapshotTests: SnapshotTestCase {

    // MARK: Fixtures — fixed dates (≈ 2026-01-15, 10:30 → 14:30 UTC)

    private let departure = Date(timeIntervalSinceReferenceDate: 790_000_200)
    private var arrival: Date { departure.addingTimeInterval(4 * 3600) }

    private var leg: FlightLeg {
        FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                  departure: departure, arrival: arrival)
    }

    // MARK: - F3.3 FlightTracker (begin)

    func testFlightTracker_states() {
        // On-time (facts grid) + boarding (details + footer slot) stacked.
        assertComponentSnapshot(
            VStack(spacing: 16) {
                FlightTracker(.init(leg: leg, status: .onTime,
                                    gate: "B12", terminal: "1", checkInDesk: "34–38"))

                FlightTracker(.init(leg: leg, status: .boarding,
                                    gate: "B12", terminal: "1", aircraft: "A321neo"))
                    .details([("Meal", "Included")])
                    .footer {
                        Text("Boarding closes 20 minutes before departure.")
                            .textStyle(.bodySm400)
                    }
            }
            .padding()
        )

        // Delayed — badge "+35m", scheduled times struck through, estimates in
        // the warning tone.
        assertComponentSnapshot(
            FlightTracker(.init(leg: leg, status: .delayed,
                                gate: "B12", terminal: "1",
                                estimatedDeparture: departure.addingTimeInterval(35 * 60),
                                estimatedArrival: arrival.addingTimeInterval(35 * 60)))
                .padding(),
            named: "delayed"
        )

        // En route — progress track at 62%, percent ring on the active
        // "Arrived" phase; arrived — belt fact, full timeline done.
        assertComponentSnapshot(
            VStack(spacing: 16) {
                FlightTracker(.init(leg: leg, status: .departed, aircraft: "A321neo"))
                    .progress(0.62)
                FlightTracker(.init(leg: leg, status: .arrived, terminal: "2", baggageBelt: "7"))
                    .progress(1)
            }
            .padding(),
            named: "progress"
        )

        // Cancelled — error phase in the timeline, no facts.
        assertComponentSnapshot(
            FlightTracker(.init(leg: leg, status: .cancelled))
                .padding(),
            named: "cancelled"
        )

        // Dark — token re-skin, accent override on the progress track.
        assertComponentSnapshot(
            FlightTracker(.init(leg: leg, status: .departed, gate: "22", terminal: "4"))
                .progress(0.3)
                .accent(.accent)
                .padding(),
            colorScheme: .dark,
            named: "dark"
        )

        // RTL — leading-aligned progress fill and route mirror.
        assertComponentSnapshot(
            FlightTracker(.init(leg: leg, status: .departed))
                .progress(0.62)
                .padding(),
            layoutDirection: .rightToLeft,
            named: "rtl"
        )
    }

    // MARK: - F3.3 FlightTracker (end)
}
#endif
