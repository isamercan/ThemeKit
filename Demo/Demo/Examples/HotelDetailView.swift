//
//  HotelDetailView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Example flow: hotel detail — hero, rating, amenities, policies, reviews and a
//  sticky booking dock with a confirmation toast.
//

import SwiftUI
import MapKit
import ThemeKit

struct HotelDetailView: View {
    let hotel: Hotel
    @Binding var path: [HotelRoute]
    @EnvironmentObject private var favorites: FavoritesStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hotel.color.opacity(0.3)
                    .frame(height: 220)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .bottomLeading) {
                        if hotel.discount != nil {
                            Badge("Deal").badgeStyle(.error).icon("flame.fill").padding()
                        }
                    }

                VStack(alignment: .leading, spacing: 16) {
                    Title(hotel.name).subtitle(hotel.area)
                    RatingSummary(score: hotel.score).label(hotel.scoreLabel).reviews(count: hotel.reviewCount, onTap: {})

                    HStack(spacing: 8) {
                        ForEach(hotel.amenities, id: \.self) { a in
                            Tag(Amenity.label(a)).icon(Amenity.icon(a))
                        }
                    }

                    Card {
                        HStack {
                            Stat(title: "Per night", value: hotel.pricePerNight.priceText).icon("tag")
                            Spacer()
                            Stat(title: "Reviews", value: "\(hotel.reviewCount)").icon("text.bubble")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Location").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                        Map(initialPosition: .region(MKCoordinateRegion(center: hotel.coordinate, span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)))) {
                            Marker(hotel.name, coordinate: hotel.coordinate).tint(Theme.shared.background(.bgHero))
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                        .allowsHitTesting(false)
                        HStack(spacing: 4) {
                            Icon(systemName: "mappin.circle").size(.sm).color(Theme.shared.text(.textTertiary))
                            Text(hotel.area + ", Istanbul").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                    }

                    VStack(spacing: 8) {
                        Accordion("Cancellation policy", initiallyExpanded: true) {
                            Text(hotel.freeCancellation ? "Free cancellation up to 24 hours before check-in." : "Cancellation terms are shown during booking.")
                        }
                        .icon("calendar")
                        Accordion("House rules") {
                            Text("Check-in 2:00 PM · Check-out 12:00 PM · No pets allowed.")
                        }
                        .icon("list.bullet")
                    }

                    Text("Reviews").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                    ChatBubble("It was a wonderful stay, the view was amazing!", author: "Emma", time: "2 days ago").side(.incoming).icon("person.fill")
                    ChatBubble("The staff were very attentive, I highly recommend it.", author: "James", time: "1 week ago").side(.incoming).icon("person.fill")
                }
                .padding()
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(hotel.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(Motion.fast.animation) { favorites.toggle(hotel) }
                } label: {
                    Image(systemName: favorites.contains(hotel) ? "heart.fill" : "heart")
                        .foregroundStyle(favorites.contains(hotel) ? Theme.shared.foreground(.systemcolorsFgError) : Theme.shared.text(.textPrimary))
                }
            }
        }
        .buttonDock {
            HStack(spacing: Theme.SpacingKey.md.value) {
                VStack(alignment: .leading, spacing: 0) {
                    Text(hotel.pricePerNight.priceText).textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                    Text("/ night").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
                PrimaryButton("Reserve") { path.append(.checkout(hotel)) }.fullWidth()
            }
            .padding(.bottom, 4)
        }
    }
}

#Preview {
    NavigationStack {
        HotelDetailView(hotel: Hotel.samples[0], path: .constant([]))
    }
    .environment(Theme.shared)
    .environmentObject(DemoThemeStore())
    .environmentObject(FavoritesStore())
}
