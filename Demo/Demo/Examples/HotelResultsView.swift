//
//  HotelResultsView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Example flow: results — sort control, list/map toggle, hotel cards with a
//  favorite toggle, and a MapKit map with tappable price pins.
//

import SwiftUI
import MapKit
import ThemeKit

struct HotelResultsView: View {
    let destination: String
    let guests: Int
    @Binding var path: [HotelRoute]

    @EnvironmentObject private var favorites: FavoritesStore
    @State private var sort = 0
    @State private var mode = UserDefaults.standard.integer(forKey: "hotelMode")   // 0 = list, 1 = map (screenshot hook)
    @State private var filter: String?
    @State private var page = 1
    @State private var camera: MapCameraPosition = .region(
        MKCoordinateRegion(center: .init(latitude: 41.06, longitude: 29.0), span: .init(latitudeDelta: 0.32, longitudeDelta: 0.32))
    )
    private let hotels = Hotel.samples

    var body: some View {
        VStack(spacing: 0) {
            SegmentedControl(["List", "Map"], selection: $mode)
                .padding([.horizontal, .top])

            if mode == 0 { listView } else { mapView }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("\(destination) · \(hotels.count) hotels")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var listView: some View {
        ScrollView {
            VStack(spacing: 16) {
                SegmentedControl(["Recommended", "Price", "Rating"], selection: $sort)
                FilterGroup(options: ["Free cancellation", "Pool", "Breakfast", "Spa"], selection: $filter) { $0 }

                ForEach(hotels) { hotel in
                    ZStack(alignment: .topTrailing) {
                        Button { path.append(.detail(hotel)) } label: { HotelCard(hotel: hotel) }
                            .buttonStyle(.plain)
                        heartButton(hotel)
                    }
                }

                Pagination(current: $page, total: 8).padding(.top, 4)
            }
            .padding()
        }
    }

    private var mapView: some View {
        Map(position: $camera) {
            ForEach(hotels) { hotel in
                Annotation(hotel.name, coordinate: hotel.coordinate) {
                    Button { path.append(.detail(hotel)) } label: {
                        Text(hotel.pricePerNight.priceText)
                            .textStyle(.labelSm700)
                            .foregroundStyle(Theme.shared.foreground(.fgSecondary))
                            .padding(.horizontal, Theme.SpacingKey.sm.value)
                            .frame(height: 28)
                            .background(favorites.contains(hotel) ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.background(.bgHero), in: Capsule())
                            .overlay(Capsule().stroke(Theme.shared.background(.bgWhite), lineWidth: 2))
                            .themeShadow(.soft)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private func heartButton(_ hotel: Hotel) -> some View {
        Button {
            withAnimation(Motion.fast.animation) { favorites.toggle(hotel) }
        } label: {
            Image(systemName: favorites.contains(hotel) ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(favorites.contains(hotel) ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary))
                .frame(width: 34, height: 34)
                .background(Theme.shared.background(.bgWhite), in: Circle())
                .themeShadow(.soft)
        }
        .buttonStyle(.plain)
        .padding(10)
    }
}

struct HotelCard: View {
    let hotel: Hotel

    var body: some View {
        Card(padding: 0) {
            VStack(alignment: .leading, spacing: 0) {
                ZStack(alignment: .topLeading) {
                    hotel.color.opacity(0.3)
                        .frame(height: 160)
                        .frame(maxWidth: .infinity)
                        .clipped()
                    if let discount = hotel.discount {
                        Badge("\(discount)% off").badgeStyle(.error).size(.small).padding(10)
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text(hotel.name)
                        .textStyle(.labelMd700)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                    HStack(spacing: 4) {
                        Image(systemName: "mappin").font(.system(size: 11)).foregroundStyle(Theme.shared.text(.textTertiary))
                        Text(hotel.area).textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                    }
                    RatingSummary(score: hotel.score, label: hotel.scoreLabel, reviewCount: hotel.reviewCount)
                    HStack(spacing: 6) {
                        ForEach(hotel.amenities.prefix(3), id: \.self) { a in
                            Tag(Amenity.label(a)).icon(Amenity.icon(a))
                        }
                    }
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        if let old = hotel.oldPrice {
                            Text(old.priceText).textStyle(.bodySm400).strikethrough().foregroundStyle(Theme.shared.text(.textTertiary))
                        }
                        Text(hotel.pricePerNight.priceText).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                        Text("/ night").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                        Spacer()
                        if hotel.freeCancellation {
                            Callout("Free cancellation").variant(.success)
                        }
                    }
                    .padding(.top, 2)
                }
                .padding()
            }
        }
    }
}
