//
//  TravelSnapshotTests.swift
//  ThemeKitTests
//
//  Visual-regression coverage for the travel suite. Opt-in + iOS-only (see
//  SnapshotSupport.swift); records references on the pinned Simulator, skips in CI.
//
//  Deterministic components only — CountdownTimer (ticks every second) and
//  LocationCard (async MKMapSnapshotter) are excluded because their pixels change
//  between renders. Bindings use `.constant` and dates are fixed so references
//  are reproducible.
//

#if canImport(UIKit)
import SnapshotTesting
import SwiftUI
import XCTest
@testable import ThemeKit

@MainActor
final class TravelSnapshotTests: SnapshotTestCase {

    private let dep = Date(timeIntervalSinceReferenceDate: 800_000_000)   // fixed → reproducible
    private var arr: Date { dep.addingTimeInterval(2 * 3_600 + 20 * 60) }

    // MARK: - Atoms

    func testPriceTag_variants() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 12) {
                PriceTag(1_299).original(1_899).unit("/ night").size(.large).emphasis(.hero).discountBadge()
                PriceTag(2_499, currencyCode: "EUR").from()
                PriceTag(0).free()
                PriceTag(1_299).soldOut()
            }
        )
    }

    func testPointsBadge_styles() {
        assertComponentSnapshot(
            VStack(alignment: .leading, spacing: 10) {
                PointsBadge(1_250).unit("mil").style(.earn).size(.large)
                PointsBadge(500).style(.redeem)
                PointsBadge(8_430).style(.balance)
            }
        )
    }

    func testQRCode() { assertComponentSnapshot(QRCode("THEMEKIT-PASS-BID12025").size(140)) }

    func testBarcode() { assertComponentSnapshot(Barcode("9824097217421298").height(52).showsValue()) }

    // MARK: - Molecules

    func testAmenityGrid_limitedAndHighlighted() {
        assertComponentSnapshot(
            AmenityGrid([
                Amenity("Free Wi-Fi", systemImage: "wifi"),
                Amenity("Pool", systemImage: "figure.pool.swim"),
                Amenity("Breakfast", systemImage: "fork.knife"),
                Amenity("Parking", systemImage: "parkingsign"),
                Amenity("Gym", systemImage: "dumbbell"),
                Amenity("Spa", systemImage: "sparkles"),
            ]).columns(2).limit(4).highlighted(["Free Wi-Fi"])
        )
    }

    func testPriceHistogram() {
        assertComponentSnapshot(
            PriceHistogram(bins: [2, 5, 9, 14, 18, 22, 19, 12, 8, 5, 3, 2],
                           lowerValue: .constant(800), upperValue: .constant(3_200), in: 0...5_000)
                .showsBounds().resultCount(87)
        )
    }

    func testInstallmentSelector() {
        assertComponentSnapshot(
            InstallmentSelector(total: 12_000, options: [1, 3, 6, 12], selection: .constant(3))
                .interestFreeUpTo(3).recommended(3)
        )
    }

    func testCurrencyPicker() {
        assertComponentSnapshot(
            CurrencyPicker(selection: .constant("TRY"), currencies: Currency.common)
        )
    }

    // MARK: - Organisms

    func testFlightCard_single() {
        assertComponentSnapshot(
            FlightCard(airline: "Anadolu Air", from: "IST", to: "ESB", departure: dep, arrival: arr)
                .price(1_299).badge("Cheapest").scarcity(5).onSelect { }
        )
    }

    func testFlightCard_multiLeg() {
        assertComponentSnapshot(
            FlightCard(legs: [
                FlightLeg(airline: "Anadolu Air", from: "IST", to: "AMS", departure: dep, arrival: dep.addingTimeInterval(4 * 3_600)),
                FlightLeg(airline: "Blue Wings", from: "AMS", to: "IST", departure: dep.addingTimeInterval(72 * 3_600),
                          arrival: dep.addingTimeInterval(78 * 3_600), stops: 1, layover: "1 stop · 2h 10m · CDG"),
            ]).price(7_178).onSelect { }
        )
    }

    func testFareSummary() {
        assertComponentSnapshot(
            FareSummary([
                .item("Base fare", 1_100),
                .item("Taxes & fees", 199),
                .discount("Member discount", 100),
                .total("Total", 1_199),
            ])
        )
    }

    func testReviewCard() {
        assertComponentSnapshot(
            ReviewCard(author: "Elif Kaya", score: 9.2, text: "Spotless rooms and a great location right by the marina.")
                .date(dep).title("Would stay again").verified().stars()
        )
    }

    func testLoyaltyCard() {
        assertComponentSnapshot(
            LoyaltyCard(tier: "Gold", points: 8_430).memberName("Elif Kaya").progress(0.62, toNextTier: "Platinum"),
            width: 340
        )
    }

    func testSeatMap_withLabelsAndLegend() {
        let rows: [[SeatSlot]] = (10...13).map { r in
            [.seat(Seat("\(r)A", premium: r == 10)), .seat(Seat("\(r)B")), .seat(Seat("\(r)C", occupied: r == 12)),
             .aisle,
             .seat(Seat("\(r)D")), .seat(Seat("\(r)E")), .seat(Seat("\(r)F"))]
        }
        assertComponentSnapshot(
            SeatMap(rows: rows, selection: .constant(["12A"])).showsLabels().legend()
        )
    }
}
#endif
