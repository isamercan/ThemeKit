//
//  TransportCrossSellSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the ThemeKitTravel `TransportCrossSellCard`
//  organism (F3.2 · ADR §9.8). Opt-in + iOS-only (see SnapshotSupport.swift).
//  The RTL case is the plan's flagged mirror scenario: the notch cut and the
//  dashed perforation must sit at the mirrored tear line, and the route arrow
//  must point the other way.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit
import ThemeKitTravel

@MainActor
final class TransportCrossSellSnapshotTests: SnapshotTestCase {

    // MARK: - F3.2 TransportCrossSellCard (begin)

    /// All four modes in the default ribbon chrome — mode-tinted accents,
    /// price-from (explicit code so references don't depend on host locale),
    /// badge, CTA and the notched tear line.
    func testTransportCrossSell_modes() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                    .price(19, currencyCode: "USD")
                    .duration("6h 30m")
                    .departures("Every 30 min from Central Station")
                    .badge("Cheapest")
                    .onSelect {}
                TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                    .price(34, currencyCode: "EUR")
                    .duration("4h 15m")
                    .onSelect("View timetable") {}
                TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
                    .price(12, currencyCode: "USD")
                    .departures("3 sailings daily")
                TransportCrossSellCard(.car, from: "Riverton", to: "Lakeside")
                    .price(55, currencyCode: "USD", caption: "per day")
                    .duration("5h drive")
                    .accent(.success)
                    .onSelect("Rent a car") {}
            }
            .padding()
        )
    }

    /// Inline (ListRow-anatomy) variant, plus the logo slot replacing the glyph.
    func testTransportCrossSell_inline() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                    .price(34, currencyCode: "USD")
                    .duration("4h 15m")
                    .badge("Fastest")
                    .variant(.inline)
                    .onSelect {}
                TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                    .price(19, currencyCode: "USD")
                    .logo { Icon(systemName: "leaf.fill").size(.lg).accent(.success) }
                    .onSelect {}
            }
            .padding()
        )
    }

    /// The flagged RTL case — notches/perforation cut at the mirrored tear x,
    /// glyph section on the right, route arrow mirrored (both variants).
    func testTransportCrossSell_rtl() {
        assertComponentSnapshot(
            VStack(spacing: 16) {
                TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
                    .price(19, currencyCode: "USD")
                    .duration("6h 30m")
                    .badge("Cheapest")
                    .onSelect {}
                TransportCrossSellCard(.train, from: "Riverton", to: "Lakeside")
                    .price(34, currencyCode: "USD")
                    .variant(.inline)
                    .onSelect {}
            }
            .padding(),
            layoutDirection: .rightToLeft,
            named: "rtl"
        )
    }

    /// Dark — token re-skin of the coupon surface, perforation and accents.
    func testTransportCrossSell_dark() {
        assertComponentSnapshot(
            TransportCrossSellCard(.ferry, from: "Harbor City", to: "North Isle")
                .price(12, currencyCode: "USD")
                .departures("3 sailings daily")
                .onSelect {}
                .padding(),
            colorScheme: .dark,
            named: "dark"
        )
    }

    // MARK: - F3.2 TransportCrossSellCard (end)
}
#endif
