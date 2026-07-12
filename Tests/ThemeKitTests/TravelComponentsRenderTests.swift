//
//  TravelComponentsRenderTests.swift
//  ThemeKitTests
//
//  Liveness / render coverage for the travel + booking component suite — proves
//  every new component's body builds and lays out through ImageRenderer under both
//  the light default theme and a generated dark theme.
//

import XCTest
import SwiftUI
@testable import ThemeKit
@testable import ThemeKitTravel

@available(iOS 16.0, macOS 13.0, *)
final class TravelComponentsRenderTests: XCTestCase {

    @MainActor
    private func renders<V: View>(_ view: V, _ label: String) {
        let renderer = ImageRenderer(content: view.frame(width: 340, height: 240))
        #if canImport(UIKit)
        XCTAssertNotNil(renderer.uiImage, "\(label) failed to render")
        #else
        XCTAssertNotNil(renderer.nsImage, "\(label) failed to render")
        #endif
    }

    @MainActor
    private func renderAll() {
        let dep = Date(timeIntervalSince1970: 1_760_000_000)

        // Atoms
        renders(SearchBadge("SAW"), "SearchBadge")
        renders(IconTile("airplane").accent(.turquoise), "IconTile")
        renders(FlightStatusBadge(.delayed).time("+35m"), "FlightStatusBadge")
        renders(SwapButton { }, "SwapButton")

        // Molecules
        renders(SearchField("From").value(code: "IST", title: "Istanbul", subtitle: "All airports"), "SearchField")
        renders(FieldButton("2 Guests · Economy") { }.label("Passengers"), "FieldButton")
        renders(SuggestionRow("Ankara") { }.icon("airplane").code("ANK").subtitle("Any"), "SuggestionRow")
        renders(RecentSearchRow(from: "IST", to: "AYT") { }.roundTrip().dates("18 Jul"), "RecentSearchRow")
        renders(TripTypeToggle(["One way", "Round trip"], selection: .constant(0)), "TripTypeToggle")
        renders(StepperRow("Adult", value: .constant(2)).subtitle("+12 yrs"), "StepperRow")
        renders(LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)"), "LayoverRow")
        renders(SmartSuggestion("Cheaper on Sat 13 Sep.").label("Smart tip"), "SmartSuggestion")
        renders(PriceBreakdown(190_960).original(248_000).discountBadge("-23%").extra("Extra 8%", 175_683), "PriceBreakdown")
        renders(FlightRoute(from: "IST", to: "AYT", departure: dep, arrival: dep.addingTimeInterval(5_400)).stops(1), "FlightRoute")
        renders(SortTab(SortOption("Best", value: "₺2.777", icon: "star.fill"), isSelected: true) { }, "SortTab")
        renders(DatePriceCard(DatePriceItem("18 Jul", price: 1_767), isSelected: true) { }.cheapest(), "DatePriceCard")
        renders(FilterRow("Direct", isOn: .constant(true)).count(128), "FilterRow")
        renders(SortSummaryBar([SortOption("Best", value: "₺2.777")], selection: .constant(0)).onMore { }, "SortSummaryBar")
        renders(DatePriceStrip([DatePriceItem("18 Jul", price: 1_767)], selection: .constant(0)), "DatePriceStrip")
        renders(PriceTrendChart([PriceTrendPoint("18", price: 1_767)], selection: .constant(0)).showsAxis(), "PriceTrendChart")
        renders(PaymentCardField(number: .constant("4242"), expiry: .constant(""), cvv: .constant("")), "PaymentCardField")
        renders(InstallmentPicker([InstallmentOption(count: 3, total: 9_900, monthly: 3_300)], selection: .constant(3)), "InstallmentPicker")
        renders(MapPriceMarker("₺1.250").selected(), "MapPriceMarker")
        renders(PassengerRow("İsa Mercan").type("Adult").seat("14C").status("Checked in"), "PassengerRow")

        // Organisms
        renders(FilterList([FilterOption("Direct", count: 128)], selection: .constant([])).title("Stops").bordered(), "FilterList")
        renders(FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront")], selection: .constant([])).onFilter { }.onSort { }, "FilterBar")
        renders(HotelResultCard(name: "Mirage Park Resort").score(8.9, reviews: 949).price(190_960).original(248_000).discountBadge("-23%"), "HotelResultCard")
        renders(RoomCard(name: "Deluxe Room").board("All-inclusive").price(9_600).onSelect { }, "RoomCard")
        renders(StickyBookingBar("Book now") { }.price(9_600).original(12_000), "StickyBookingBar")
        renders(AgentPriceRow("Trip.com") { }.rating(4.2).badge("Cheapest").price(3_538), "AgentPriceRow")
        renders(PriceAlertCard("Get price alerts", isOn: .constant(true)).price(3_538).trend(.down, "-8%"), "PriceAlertCard")
        renders(AncillaryCard("Checked baggage").icon("suitcase.fill").price(450).quantity(.constant(1)), "AncillaryCard")
        renders(BoardingPass(passenger: "İsa Mercan", from: "SAW", to: "BER").airline("Pegasus").gate("A12", seat: "14C").barcode("PC1234"), "BoardingPass")
        renders(FlightTicketCard(from: "NYC", to: "SFO").duration("1h 45m").times(departure: "10:00", arrival: "11:30").price(140), "FlightTicketCard")
        renders(MapCallout(title: "Mirage Park").score(8.9).price(9_600).onSelect { }, "MapCallout")
        renders(SheetHeader("Passengers").onBack { }.onClose { }.progress(0.4), "SheetHeader")

        renderNewFlexibilityVariants(dep)
    }

    /// New variants / presets / axes added by the #280 full-flexibility sweep —
    /// exercises the alternate anatomies (variant enums, style presets, emphasis,
    /// seat shapes) that the default-state `renderAll()` never touches. Runs under
    /// both the light and dark themes via `renderAll()`.
    @MainActor
    private func renderNewFlexibilityVariants(_ dep: Date) {
        let payments: [PaymentMethodOption] = [
            .init(id: "card", kind: .card, title: "Credit / debit card"),
            .init(id: "wallet", kind: .wallet, title: "Digital wallet", subtitle: "Pay in one tap"),
        ]
        let cards = [
            SavedCard(id: "visa", brand: .visa, last4: "4242",
                      holder: "Alex Morgan", expiryMonth: 8, expiryYear: 2032),
        ]
        let info = FlightStatusInfo(
            leg: FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                           departure: dep, arrival: dep.addingTimeInterval(4 * 3_600)),
            status: .boarding, gate: "B12", terminal: "1")
        var draft = TripSearchDraft()
        draft.origin = Airport(code: "IST", name: "Istanbul Airport", city: "Istanbul", countryCode: "TR")
        draft.destination = Airport(code: "LHR", name: "Heathrow Airport", city: "London", countryCode: "GB")
        draft.departureDate = dep
        let leg = FlightLeg(airline: "Skyline Air", from: "IST", to: "LHR",
                            departure: dep, arrival: dep.addingTimeInterval(4 * 3_600))

        // Molecules / atoms — new variant enums, emphasis, size/shape
        renders(CabinClassSelector(selection: .constant(.business)).variant(.cards).showsGlyphs(), "CabinClass.cards")
        renders(FlightStatusBadge(.boarding).flightStatusBadgeStyle(.solid), "StatusBadge.solid")
        renders(FlightStatusBadge(.delayed).flightStatusBadgeStyle(.outline), "StatusBadge.outline")
        renders(FlightStatusBadge(.arrived).flightStatusBadgeStyle(.dot), "StatusBadge.dot")
        renders(FlightStatusBadge(.boarding).size(.large).shape(.rounded), "StatusBadge.size.shape")
        renders(RecentSearchRow(from: "IST", to: "AYT") { }.variant(.pill).dates("18 Jul"), "RecentSearch.pill")
        renders(RecentSearchRow(from: "IST", to: "AYT") { }.variant(.bordered).dates("18 Jul"), "RecentSearch.bordered")
        renders(LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").variant(.pill), "Layover.pill")
        renders(LayoverRow(duration: "2h 15m", airport: "Istanbul (IST)").variant(.banner).warning("Self-transfer"), "Layover.banner")
        renders(TripTypeToggle(["One way", "Round trip"], selection: .constant(0)).variant(.underline).size(.large), "TripToggle.underline")

        // Organisms — new variant enums / layouts
        renders(PaymentMethodSelector(payments, selection: .constant("card")).variant(.grid), "Payment.grid")
        renders(PaymentMethodSelector(payments, selection: .constant("card")).variant(.carousel), "Payment.carousel")
        renders(PaymentMethodSelector(payments, selection: .constant("card")).variant(.compactList), "Payment.compactList")
        renders(SavedCardsList(cards, selection: .constant("visa")).variant(.wallet).flagsExpired(), "SavedCards.wallet")
        renders(FlightTracker(info).variant(.compact).progress(0.62), "FlightTracker.compact")
        renders(FareFamilyCard("Eco Fly", price: 3_116).layout(.column), "FareFamily.column")
        renders(TransportCrossSellCard(.bus, from: "Riverton", to: "Lakeside")
            .variant(.tile).size(.small).price(19).onSelect { }, "Transport.tile")
        renders(TripSearchCard(draft: .constant(draft), onSearch: { _ in }).variant(.hero), "TripSearch.hero")
        renders(TripSearchCard(draft: .constant(draft), onSearch: { _ in }).variant(.compact), "TripSearch.compact")
        renders(TripSearchCard(draft: .constant(draft), onSearch: { _ in }).variant(.inlineBar), "TripSearch.inlineBar")

        // SeatMap — new seat shapes + size ramp
        renders(SeatMap(columns: "AB CD", rows: Array(1...4), selection: .constant(Set<String>()))
            .seatShape(.seatback), "SeatMap.seatback")
        renders(SeatMap(columns: "AB CD", rows: Array(1...4), selection: .constant(Set<String>()))
            .seatShape(.circle).seatSize(.compact), "SeatMap.circle")

        // FlightListItem — three new style presets
        let item = FlightListItem(legs: [leg]).price(214, currencyCode: "USD", caption: "from").badge("Best")
        renders(item.flightListItemStyle(.tile), "FlightListItem.tile")
        renders(item.flightListItemStyle(.hero), "FlightListItem.hero")
        renders(item.flightListItemStyle(.receipt), "FlightListItem.receipt")
    }

    @MainActor
    func testTravelComponentsRenderLight() {
        Theme.shared.loadTheme(named: "defaultTheme")
        renderAll()
    }

    @MainActor
    func testTravelComponentsRenderDark() {
        Theme.shared.apply(ThemeConfig(primaryHex: "056bfd", dark: true))
        renderAll()
        Theme.shared.loadTheme(named: "defaultTheme")   // restore
    }

    func testNeutralPresetIsRegistered() {
        let neutral = ThemePreset.named("neutral")
        XCTAssertNotNil(neutral, "Neutral preset should be registered")
        XCTAssertEqual(neutral?.tint, 0, "Neutral preset should have zero accent bleed")
    }
}
