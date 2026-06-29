//
//  HotelSearchView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Example flow (root): hotel search form built from the real components.
//  Search → Results → Detail via a typed navigation path.
//

import SwiftUI
import ThemeKit

struct HotelSearchView: View {
    @StateObject private var favorites = FavoritesStore()
    @State private var path: [HotelRoute] = []
    @State private var destination = "Istanbul"
    @State private var checkIn: Date? = .now
    @State private var checkOut: Date? = Calendar.current.date(byAdding: .day, value: 3, to: .now)
    @State private var guests = 2
    @State private var tripType: String? = "Leisure"

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Title("Find your stay", subtitle: "2M+ hotels worldwide")

                    PromoBanner(title: "Early booking", subtitle: "Up to 30% off summer stays",
                                systemImage: "sun.max.fill", ctaTitle: "Explore", action: {})

                    Card {
                        VStack(spacing: 14) {
                            SearchBar(text: $destination, placeholder: "Where are you going?")
                            HStack(spacing: 12) {
                                DateField(label: "Check-in", date: $checkIn, style: .custom("EEE, d MMM"),
                                          allowClear: true, leadingSystemImage: "calendar")
                                DateField(label: "Check-out", date: $checkOut, style: .custom("EEE, d MMM"),
                                          allowClear: true, leadingSystemImage: "calendar")
                            }
                            InputNumber(label: "Guests", value: $guests, range: 1...9, large: true)
                        }
                    }

                    FilterGroup(title: "Trip type", options: ["Leisure", "Business", "Family", "Romantic"], selection: $tripType) { $0 }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Search hotels")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { path.append(.favorites) } label: {
                        Image(systemName: favorites.count > 0 ? "heart.fill" : "heart")
                            .foregroundStyle(favorites.count > 0 ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary))
                            .indicator { if favorites.count > 0 { Badge("\(favorites.count)", style: .error, size: .small) } }
                    }
                }
            }
            .navigationDestination(for: HotelRoute.self) { route in
                switch route {
                case .results: HotelResultsView(destination: destination, guests: guests, path: $path)
                case .detail(let hotel): HotelDetailView(hotel: hotel, path: $path)
                case .checkout(let hotel): HotelCheckoutView(hotel: hotel, path: $path)
                case .favorites: HotelFavoritesView(path: $path)
                }
            }
            .buttonDock {
                PrimaryButton("\(guests) guests · Search hotels", block: true) { path.append(.results) }
                    .padding(.bottom, 4)
            }
            .onAppear {
                // Deep-link for screenshots: launch with `-hotelStage results|detail`.
                switch UserDefaults.standard.string(forKey: "hotelStage") {
                case "results": if path.isEmpty { path = [.results] }
                case "detail": if path.isEmpty { path = [.results, .detail(Hotel.samples[0])] }
                case "checkout": if path.isEmpty { path = [.results, .detail(Hotel.samples[0]), .checkout(Hotel.samples[0])] }
                case "favorites": if path.isEmpty { path = [.favorites] }
                default: break
                }
            }
        }
        .environmentObject(favorites)
    }
}

#Preview {
    HotelSearchView()
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
