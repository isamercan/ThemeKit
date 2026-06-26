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
    @State private var destination = "İstanbul"
    @State private var checkIn: Date? = .now
    @State private var checkOut: Date? = Calendar.current.date(byAdding: .day, value: 3, to: .now)
    @State private var guests = 2
    @State private var tripType: String? = "Tatil"

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Title("Konaklama bul", subtitle: "Dünya genelinde 2M+ otel")

                    PromoBanner(title: "Erken rezervasyon", subtitle: "Yaz tatilinde %30'a varan indirim",
                                systemImage: "sun.max.fill", ctaTitle: "Keşfet", action: {})

                    Card {
                        VStack(spacing: 14) {
                            SearchBar(text: $destination, placeholder: "Nereye gidiyorsun?")
                            HStack(spacing: 12) {
                                DateField(label: "Giriş", date: $checkIn, style: .custom("EEE, d MMM"),
                                          allowClear: true, leadingSystemImage: "calendar")
                                DateField(label: "Çıkış", date: $checkOut, style: .custom("EEE, d MMM"),
                                          allowClear: true, leadingSystemImage: "calendar")
                            }
                            InputNumber(label: "Misafir sayısı", value: $guests, range: 1...9, large: true)
                        }
                    }

                    FilterGroup(title: "Seyahat tipi", options: ["Tatil", "İş", "Aile", "Romantik"], selection: $tripType) { $0 }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Otel Ara")
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
                PrimaryButton("\(guests) misafir · Otelleri ara", isContentWidth: true) { path.append(.results) }
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
        .environmentObject(Theme.shared)
        .environmentObject(DemoThemeStore())
}
