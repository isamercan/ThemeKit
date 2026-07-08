//
//  FlightResultsView.swift
//  Demo
//
//  Example screen — a flight search-results page assembled entirely from ThemeKit
//  components: a brand PageHeader + search-summary pill, a DatePriceStrip timeline,
//  a FilterBar filter section with a chart/grid view toggle, and a list of
//  FlightListItem cards. Generic sample data; the brand blue resolves from theme.
//

import SwiftUI
import ThemeKit

private struct SampleFlight: Identifiable {
    let id = UUID()
    let airline: String
    let from: String
    let to: String
    let departure: Date
    let arrival: Date
    let price: Decimal

    static let all: [SampleFlight] = {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 7)) ?? Date(timeIntervalSince1970: 0)
        func at(_ h: Int, _ m: Int = 0) -> Date { base.addingTimeInterval(TimeInterval(h * 3600 + m * 60)) }
        return [
            .init(airline: "Skyline Air", from: "SAW", to: "AYT", departure: at(0), arrival: at(3, 15), price: 12_700),
            .init(airline: "Skyline Air", from: "SAW", to: "AYT", departure: at(2), arrival: at(5, 15), price: 12_700),
            .init(airline: "Aegean Jet", from: "IST", to: "AYT", departure: at(4), arrival: at(6, 5), price: 13_450),
            .init(airline: "Skyline Air", from: "SAW", to: "AYT", departure: at(6), arrival: at(9, 15), price: 12_700),
            .init(airline: "Blue Wings", from: "IST", to: "AYT", departure: at(8), arrival: at(10, 20), price: 11_980),
        ]
    }()
}

struct FlightResultsView: View {
    @Environment(\.theme) private var theme

    @State private var dateSelection = 1
    @State private var filters: Set<String> = ["cheapest"]
    @State private var viewMode = 0   // 0 = chart, 1 = grid
    @State private var query = ""

    private let dates = [
        DatePriceItem("2 May", price: 1_500), DatePriceItem("3 May", price: 1_500),
        DatePriceItem("4 May", price: 1_500), DatePriceItem("5 May", price: 1_650),
        DatePriceItem("6 May", price: 1_420), DatePriceItem("7 May", price: 1_560),
    ]
    private let flights = SampleFlight.all

    var body: some View {
        VStack(spacing: 0) {
            header
            results
        }
        .background(theme.background(.bgElevatorPrimary))
    }

    // MARK: Brand header + search summary

    private var header: some View {
        VStack(spacing: 0) {
            PageHeader("Skyline")
                .leading(systemImage: "line.3.horizontal") {}
                .logo(Text("SKYLINE").font(.system(size: 20, weight: .heavy)).foregroundStyle(SemanticColor.primary.onSolid))
                .actions([.init(systemImage: "person.circle.fill", accessibilityLabel: "Profile") {}])
                .pageHeaderStyle(.brand)

            RecentSearchRow(from: "Istanbul", to: "Antalya") {}
                .icon(nil).dates("14 Jan").passengers("7")
                .pill().surface(.bgWhite).onSearch {}
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.bottom, Theme.SpacingKey.sm.value)
        }
        .background(SemanticColor.primary.solid, ignoresSafeAreaEdges: .top)
    }

    // MARK: Timeline + filters + flight list

    private var results: some View {
        ScrollView {
            LazyVStack(spacing: Theme.SpacingKey.sm.value) {
                DatePriceStrip(dates, selection: $dateSelection).strip().currency("TRY").highlightCheapest(false)

                filterSection

                ForEach(flights) { flight in
                    FlightListItem(airline: flight.airline, from: flight.from, to: flight.to,
                                   departure: flight.departure, arrival: flight.arrival)
                        .price(flight.price, currencyCode: "TRY")
                        .onSelect("Details") {}
                        .flightListItemStyle(.tray)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                }
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
        }
    }

    /// The Figma "Filter Section": outlined chips + circle buttons, then an info
    /// link and a chart/grid view toggle.
    private var filterSection: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            FilterBar([QuickFilter("Cheapest", id: "cheapest"), QuickFilter("Fastest"),
                       QuickFilter("Fast & Cheap"), QuickFilter("Direct")], selection: $filters)
                .chipStyle(.outlined).leadingShape(.circle).size(.small)
                .onFilter {}.onSort {}

            HStack {
                TextLink("About prices & deals") {}
                Spacer(minLength: Theme.SpacingKey.sm.value)
                SegmentedControl([SegmentItem(icon: "chart.bar.fill"), SegmentItem(icon: "square.grid.2x2.fill")],
                                 selection: $viewMode)
                    .fullWidth(false).size(.small)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite))
    }
}

#Preview {
    FlightResultsView().environment(Theme.shared)
}
