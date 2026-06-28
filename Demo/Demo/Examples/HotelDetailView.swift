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
                            Badge("Fırsat", style: .error, leadingSystemImage: "flame.fill").padding()
                        }
                    }

                VStack(alignment: .leading, spacing: 16) {
                    Title(hotel.name, subtitle: hotel.area)
                    RatingSummary(score: hotel.score, label: hotel.scoreLabel, reviewCount: hotel.reviewCount, onReviews: {})

                    HStack(spacing: 8) {
                        ForEach(hotel.amenities, id: \.self) { a in
                            Tag(Amenity.label(a), leadingSystemImage: Amenity.icon(a))
                        }
                    }

                    Card {
                        HStack {
                            Stat(title: "Gecelik", value: hotel.pricePerNight.priceText, systemImage: "tag")
                            Spacer()
                            Stat(title: "Yorum", value: "\(hotel.reviewCount)", systemImage: "text.bubble")
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Konum").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                        Map(initialPosition: .region(MKCoordinateRegion(center: hotel.coordinate, span: .init(latitudeDelta: 0.02, longitudeDelta: 0.02)))) {
                            Marker(hotel.name, coordinate: hotel.coordinate).tint(Theme.shared.background(.bgHero))
                        }
                        .frame(height: 180)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                        .allowsHitTesting(false)
                        HStack(spacing: 4) {
                            Icon(systemName: "mappin.circle", size: .sm, color: Theme.shared.text(.textTertiary))
                            Text(hotel.area + ", İstanbul").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                        }
                    }

                    VStack(spacing: 8) {
                        Accordion("İptal politikası", leadingSystemImage: "calendar", initiallyExpanded: true) {
                            Text(hotel.freeCancellation ? "Girişten 24 saat öncesine kadar ücretsiz iptal." : "İptal koşulları rezervasyon sırasında belirtilir.")
                        }
                        Accordion("Otel kuralları", leadingSystemImage: "list.bullet") {
                            Text("Giriş 14:00 · Çıkış 12:00 · Evcil hayvan kabul edilmez.")
                        }
                    }

                    Text("Yorumlar").textStyle(.headingSm).foregroundStyle(Theme.shared.text(.textPrimary))
                    ChatBubble("Harika bir konaklamaydı, manzara muhteşemdi!", side: .incoming, author: "Ayşe", time: "2 gün önce", avatarSystemImage: "person.fill")
                    ChatBubble("Personel çok ilgiliydi, kesinlikle tavsiye ederim.", side: .incoming, author: "Mehmet", time: "1 hafta önce", avatarSystemImage: "person.fill")
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
                    Text("/ gece").textStyle(.bodySm400).foregroundStyle(Theme.shared.text(.textSecondary))
                }
                PrimaryButton("Rezerve et", block: true) { path.append(.checkout(hotel)) }
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
