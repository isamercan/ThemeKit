//
//  TravelShowcaseView.swift
//  Demo — LOCAL preview of the travel suite + hardening features (not committed).
//
import SwiftUI
import ThemeKit
import ThemeKitTravel

struct TravelShowcaseView: View {
    @State private var seats: Set<String> = []
    @State private var assignment: [String: String] = [:]

    private var seatRows: [[SeatSlot]] {
        (10...13).map { r in
            [.seat(Seat("\(r)A", premium: r == 10)), .seat(Seat("\(r)B")), .seat(Seat("\(r)C", occupied: r == 12)),
             .aisle,
             .seat(Seat("\(r)D")), .seat(Seat("\(r)E", occupied: r == 13)), .seat(Seat("\(r)F"))]
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("QRCode + Barcode — new atoms (CoreImage, no dep)") {
                    HStack(spacing: 20) {
                        QRCode("https://themekit.dev/pass/BID12025BKG").size(120)
                        Barcode("9824097217421298").height(52).showsValue()
                    }
                }
                section("LoyaltyCard — Canvas progress + logo + flip(.qr)") {
                    LoyaltyCard(tier: "Gold", points: 8_430)
                        .memberName("Elif Kaya").progress(0.62, toNextTier: "Platinum")
                        .membership(.qr("MEMBER-8430-ELIF")).flippable()
                        .logo { Image(systemName: "airplane.circle.fill").font(.title3).foregroundStyle(.white) }
                }
                section("FlightCard — multi-leg (outbound + return, layover)") {
                    FlightCard(legs: [
                        FlightLeg(airline: "Anadolu Air", from: "IST", to: "AMS",
                                  departure: .now, arrival: .now.addingTimeInterval(4 * 3_600)),
                        FlightLeg(airline: "Blue Wings", from: "AMS", to: "IST",
                                  departure: .now.addingTimeInterval(72 * 3_600),
                                  arrival: .now.addingTimeInterval(78 * 3_600),
                                  stops: 1, layover: "1 stop · 2h 10m · CDG"),
                    ]).price(7_178).scarcity(5).onSelect { }
                }
                section("SeatMap — passenger assignment (tap tabs) + zoom") {
                    SeatMap(rows: seatRows, selection: $seats)
                        .passengers([Passenger(id: "a", initials: "AA"), Passenger(id: "b", initials: "SA")],
                                    assignment: $assignment)
                        .showsLabels().legend().zoomable()
                }
                section("LocationCard — snapshot (list-perf) + directions + POIs") {
                    LocationCard(title: "Marina Bay Hotel", latitude: 38.4237, longitude: 27.1428)
                        .subtitle("Kordon Cd. No:12, İzmir").distance("1.2 km to center")
                        .snapshot().directions()
                        .pois([LocationPin(title: "Beach", latitude: 38.4265, longitude: 27.1390)])
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Travel Components")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).textStyle(.labelSm600).foregroundStyle(.secondary)
            content()
        }
    }
}
