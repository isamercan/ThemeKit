//
//  TripSearchCardSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel TripSearchCard organism
//  (F2.3 · §9.6) — round-trip vs one-way anatomy, hero and compact variants,
//  the empty-draft placeholder state and the promo slot. iOS-only + opt-in
//  (see SnapshotSupport.swift). Bindings use `.constant`; dates are fixed
//  epochs so the rendered fields never drift with the wall clock.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
import ThemeKit
@testable import ThemeKitTravel

@MainActor
final class TripSearchCardSnapshotTests: SnapshotTestCase {

    private let ist = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
    private let lhr = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
    private let jfk = Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US")

    /// Fixed midday-UTC epochs (2026-08-10 / 2026-08-17) — timezone-safe days.
    private static let departure = Date(timeIntervalSince1970: 1_786_363_200)
    private static let ret = Date(timeIntervalSince1970: 1_786_968_000)

    private func draft(tripType: TripType = .roundTrip, filled: Bool = true) -> TripSearchDraft {
        var draft = TripSearchDraft()
        draft.tripType = tripType
        guard filled else { return draft }
        draft.origin = ist
        draft.destination = lhr
        draft.departureDate = Self.departure
        draft.returnDate = Self.ret
        draft.passengers = PassengerCount(adults: 2, children: 1)
        draft.cabin = .business
        return draft
    }

    func testTripSearchCard_states() {
        assertComponentSnapshot(
            VStack(spacing: 24) {
                // Round trip — full anatomy: toggle, route + swap, two dates,
                // passengers, cabin, enabled CTA.
                TripSearchCard(draft: .constant(draft())) { _ in }
                // One way — the return DateField is gone; accent + promo slot.
                TripSearchCard(draft: .constant(draft(tripType: .oneWay))) { _ in }
                    .accent(.info)
                    .promo { Text("Members save up to 20%").textStyle(.bodySm400) }
                // Hero — larger padding + CTA, elevated chrome.
                TripSearchCard(draft: .constant(draft())) { _ in }
                    .variant(.hero)
                // Empty draft — placeholders + disabled CTA; trimmed axes.
                TripSearchCard(draft: .constant(draft(filled: false))) { _ in }
                    .showsTripType(false)
                    .showsCabinPicker(false)
                    .ctaTitle("Find fares")
                // Compact — collapsed summary row.
                TripSearchCard(draft: .constant(draft())) { _ in }
                    .variant(.compact)
                // Compact, seeded expanded — the collapse header over the form.
                TripSearchCard(draft: .constant(draft())) { _ in }
                    .variant(.compact)
                    .seedExpanded()
            }
            .padding()
        )
    }
}
#endif
