//
//  HotelFavoritesView.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Example flow: the wishlist — saved hotels (or an empty state) built from the
//  shared FavoritesStore.
//

import SwiftUI
import ThemeKit

struct HotelFavoritesView: View {
    @Binding var path: [HotelRoute]
    @EnvironmentObject private var favorites: FavoritesStore

    private var saved: [Hotel] { favorites.hotels(from: Hotel.samples) }

    var body: some View {
        Group {
            if saved.isEmpty {
                EmptyState("No favorites yet")
                    .icon("heart")
                    .message("Tap the heart on hotels you like to save them here.")
                    .primaryAction("Browse hotels") { if path.last == .favorites { path.removeLast() } }
                    .padding()
                    .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(saved) { hotel in
                            ZStack(alignment: .topTrailing) {
                                Button { path.append(.detail(hotel)) } label: { HotelCard(hotel: hotel) }
                                    .buttonStyle(.plain)
                                Button {
                                    withAnimation(Motion.fast.animation) { favorites.toggle(hotel) }
                                } label: {
                                    Image(systemName: "heart.fill")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.shared.foreground(.systemcolorsFgError))
                                        .frame(width: 34, height: 34)
                                        .background(Theme.shared.background(.bgWhite), in: Circle())
                                        .themeShadow(.soft)
                                }
                                .buttonStyle(.plain)
                                .padding(10)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Favorites · \(saved.count)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    let store = FavoritesStore()
    store.toggle(Hotel.samples[0])
    return NavigationStack { HotelFavoritesView(path: .constant([.favorites])) }
        .environmentObject(store)
        .environment(Theme.shared)
        .environmentObject(DemoThemeStore())
}
