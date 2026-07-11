//
//  AirportPickerSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel AirportPicker organism.
//  Opt-in + iOS-only (see SnapshotSupport.swift); records references on the
//  pinned Simulator, skips in CI. Bindings use `.constant` and the internal
//  `seedQuery(_:)` (via @testable) drives the typed-query states so every
//  branch of the sectioned list renders deterministically.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
import ThemeKit
@testable import ThemeKitTravel

@MainActor
final class AirportPickerSnapshotTests: SnapshotTestCase {

    private let ist = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
    private let saw = Airport(code: "SAW", name: "Sabiha Gokcen Airport", city: "Istanbul", countryCode: "TR")
    private let lhr = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
    private let lgw = Airport(code: "LGW", name: "Gatwick Airport", city: "London", countryCode: "GB")
    private let jfk = Airport(code: "JFK", name: "John F. Kennedy Airport", city: "New York", countryCode: "US")
    private let cdg = Airport(code: "CDG", name: "Charles de Gaulle Airport", city: "Paris", countryCode: "FR")

    func testAirportPicker_states() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 24) {
                // Pre-typing sections: nearby + recent (with Clear) + popular.
                AirportPicker(selection: .constant(nil), suggestions: [])
                    .nearby([saw])
                    .recent([lhr, jfk], onClear: { })
                    .popular([ist, cdg])
                // Typed query with results — accent chips + selected checkmark.
                AirportPicker(selection: .constant(lhr), suggestions: [lhr, lgw])
                    .seedQuery("Lon")
                    .accent(.info)
                // Caller lookup in flight — Skeleton rows (static first frame).
                AirportPicker(selection: .constant(nil), suggestions: [])
                    .seedQuery("Par")
                    .loading()
                // No matches — built-in empty state.
                AirportPicker(selection: .constant(nil), suggestions: [])
                    .seedQuery("zzz")
                // No matches — custom `.emptyContent` slot (T2).
                AirportPicker(selection: .constant(nil), suggestions: [])
                    .seedQuery("zzz")
                    .emptyContent { Text("Try a city name or IATA code").textStyle(.bodySm400) }
                // Sheet presentation — FieldButton trigger echoing the selection.
                AirportPicker(selection: .constant(ist), suggestions: [])
                    .presentation(.sheet)
                AirportPicker(selection: .constant(nil), suggestions: [])
                    .presentation(.sheet)
            }
        )
    }
}
#endif
