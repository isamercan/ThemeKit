//
//  HotelModels.swift
//  Demo
//  Created by İsa Mercan on 23.06.2026.
//
//  Sample data, routing and the favorites store for the hotel example flow.
//

import SwiftUI
import CoreLocation

struct Hotel: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let area: String
    let score: Double
    let scoreLabel: String
    let reviewCount: Int
    let pricePerNight: Int
    let oldPrice: Int?
    let discount: Int?
    let amenities: [String]
    let color: Color
    let freeCancellation: Bool
    let coordinate: CLLocationCoordinate2D

    static func == (lhs: Hotel, rhs: Hotel) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }

    static let samples: [Hotel] = [
        Hotel(name: "Grand Bosphorus Hotel", area: "Besiktas", score: 9.2, scoreLabel: "Excellent", reviewCount: 1284,
              pricePerNight: 4250, oldPrice: 5200, discount: 18, amenities: ["wifi", "pool", "spa", "breakfast"], color: .blue, freeCancellation: true,
              coordinate: .init(latitude: 41.0438, longitude: 29.0094)),
        Hotel(name: "Sea Pearl Resort", area: "Sariyer", score: 8.7, scoreLabel: "Very Good", reviewCount: 642,
              pricePerNight: 3100, oldPrice: nil, discount: nil, amenities: ["wifi", "pool", "gym"], color: .teal, freeCancellation: true,
              coordinate: .init(latitude: 41.1670, longitude: 29.0578)),
        Hotel(name: "Old City Boutique", area: "Fatih", score: 9.0, scoreLabel: "Excellent", reviewCount: 980,
              pricePerNight: 2750, oldPrice: 3000, discount: 8, amenities: ["wifi", "breakfast"], color: .orange, freeCancellation: false,
              coordinate: .init(latitude: 41.0186, longitude: 28.9497)),
        Hotel(name: "Skyline Suites", area: "Sisli", score: 8.4, scoreLabel: "Very Good", reviewCount: 410,
              pricePerNight: 2200, oldPrice: nil, discount: nil, amenities: ["wifi", "gym", "parking"], color: .purple, freeCancellation: true,
              coordinate: .init(latitude: 41.0602, longitude: 28.9877)),
    ]
}

enum HotelRoute: Hashable {
    case results
    case detail(Hotel)
    case checkout(Hotel)
    case favorites
}

/// Shared wishlist state injected into the example flow.
final class FavoritesStore: ObservableObject {
    @Published private(set) var ids: Set<UUID> = []

    func contains(_ hotel: Hotel) -> Bool { ids.contains(hotel.id) }
    func toggle(_ hotel: Hotel) {
        if ids.contains(hotel.id) { ids.remove(hotel.id) } else { ids.insert(hotel.id) }
    }
    func hotels(from all: [Hotel]) -> [Hotel] { all.filter { ids.contains($0.id) } }
    var count: Int { ids.count }
}

enum Amenity {
    static func icon(_ key: String) -> String {
        switch key {
        case "wifi": return "wifi"
        case "pool": return "figure.pool.swim"
        case "spa": return "sparkles"
        case "breakfast": return "fork.knife"
        case "gym": return "dumbbell"
        case "parking": return "parkingsign"
        default: return "checkmark"
        }
    }
    static func label(_ key: String) -> String {
        switch key {
        case "wifi": return "Wifi"
        case "pool": return "Pool"
        case "spa": return "Spa"
        case "breakfast": return "Breakfast"
        case "gym": return "Gym"
        case "parking": return "Parking"
        default: return key.capitalized
        }
    }
}

extension Int {
    var priceText: String { "$" + String(self).replacingOccurrences(of: "(?<=\\d)(?=(\\d{3})+$)", with: ",", options: .regularExpression) }
}
