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
import ThemeKitTravel

private struct SampleFlight: Identifiable {
    let id = UUID()
    let airline: String
    let from: String
    let to: String
    let departure: Date
    let arrival: Date
    var stops: Int = 0
    var layover: String? = nil
    var cabin: String = "Economy"
    var carryOn: String? = "8 kg"
    var checked: String? = nil
    let price: Decimal
    var original: Decimal? = nil
    var badge: String? = nil
    var deal: String? = nil
    var dealTone: SemanticColor = .warning

    /// Deliberately varied so each `.tray` card exercises different knobs —
    /// stops, baggage, cabin, a strikethrough discount, a badge, a deal note.
    static let all: [SampleFlight] = {
        let base = Calendar.current.date(from: DateComponents(year: 2026, month: 5, day: 3, hour: 7)) ?? Date(timeIntervalSince1970: 0)
        func at(_ h: Int, _ m: Int = 0) -> Date { base.addingTimeInterval(TimeInterval(h * 3600 + m * 60)) }
        return [
            .init(airline: "Skyline Air", from: "SAW", to: "AYT", departure: at(0), arrival: at(3, 15),
                  checked: "20 kg", price: 12_700, original: 22_700, badge: "Best value"),
            .init(airline: "Aegean Jet", from: "IST", to: "AYT", departure: at(2), arrival: at(6),
                  stops: 1, layover: "SAW", carryOn: "Hand baggage", price: 13_450),
            .init(airline: "Blue Wings", from: "IST", to: "AYT", departure: at(1), arrival: at(3, 20),
                  price: 11_980, badge: "Cheapest"),
            .init(airline: "Skyline Air", from: "SAW", to: "AYT", departure: at(5), arrival: at(8, 15),
                  cabin: "Economy Plus", checked: "30 kg", price: 14_200, original: 16_000),
            .init(airline: "Aegean Jet", from: "IST", to: "AYT", departure: at(11), arrival: at(13, 5),
                  stops: 1, layover: "ESB", carryOn: "Hand baggage", price: 12_100,
                  deal: "Last 2 seats", dealTone: .warning),
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

                ForEach(flights) { f in
                    flightCard(f).flightListItemStyle(.tray)
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                }

                variantsSection
            }
            .padding(.vertical, Theme.SpacingKey.sm.value)
        }
    }

    /// The shared card data — the same flight, rendered by any FlightListItem style.
    private func flightCard(_ f: SampleFlight) -> FlightListItem {
        FlightListItem(legs: [FlightLeg(airline: f.airline, from: f.from, to: f.to,
                                        departure: f.departure, arrival: f.arrival,
                                        stops: f.stops, layover: f.layover)])
            .cabin(f.cabin)
            .baggage(f.carryOn, checked: f.checked)
            .price(f.price, currencyCode: "TRY", caption: "from")
            .original(f.original)
            .badge(f.badge)
            .deal(f.deal, tone: f.dealTone)
            .onDetails {}
            .onSelect {}
    }

    /// A few other FlightListItem styles rendering the same flight — swap with
    /// `.flightListItemStyle(_:)`.
    private var variantsSection: some View {
        let f = flights[0]
        return VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            Text("Other list styles")
                .textStyle(.labelBase700).foregroundStyle(theme.text(.textSecondary))
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.top, Theme.SpacingKey.md.value)
            styleLabel("Timeline")
            flightCard(f).flightListItemStyle(.timeline).padding(.horizontal, Theme.SpacingKey.md.value)
            styleLabel("Compact")
            flightCard(f).flightListItemStyle(.compact).padding(.horizontal, Theme.SpacingKey.md.value)
            styleLabel("Deal")
            flightCard(f).flightListItemStyle(.deal).padding(.horizontal, Theme.SpacingKey.md.value)
        }
    }

    private func styleLabel(_ text: String) -> some View {
        Text(text).textStyle(.labelSm600).foregroundStyle(theme.text(.textTertiary))
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.top, Theme.SpacingKey.sm.value)
    }

    /// The Figma "Filter Section": outlined chips + circle buttons, then an info
    /// link and a chart/grid view toggle.
    private var filterSection: some View {
        VStack(spacing: Theme.SpacingKey.sm.value) {
            // FilterBar's native behaviour: icon + label Filter/Sort buttons that
            // collapse to icons as the chips scroll left, and expand back at the start.
            FilterBar([QuickFilter("Cheapest", id: "cheapest"), QuickFilter("Fastest"),
                       QuickFilter("Fast & Cheap"), QuickFilter("Direct")], selection: $filters)
                .chipStyle(.outlined).size(.small)
                .onFilter {}.onSort {}

            HStack {
                TextLink("About prices & deals") {}
                Spacer(minLength: Theme.SpacingKey.sm.value)
                SegmentedControl([SegmentItem(icon: "chart.bar.fill"), SegmentItem(icon: "square.grid.2x2.fill")],
                                 selection: $viewMode)
                    .tinted().dividers().shape(.round).fullWidth(false).size(.small)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .background(theme.background(.bgWhite))
    }
}

#Preview {
    FlightResultsView().environment(Theme.shared)
}
