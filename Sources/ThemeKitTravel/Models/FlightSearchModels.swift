//
//  FlightSearchModels.swift
//  ThemeKitTravel
//
//  Canonical flight-search domain models (ADR-F3 §4.2) — the shared vocabulary
//  for `AirportPicker`, `CabinClassSelector` and `TripSearchCard`. Value types
//  only: generic, data-driven, no backend schema. Apps map their own DTOs onto
//  these; components take them (or flat convenience slices of them) in `init`.
//

import Foundation
import ThemeKit

// MARK: - Airport

/// An airport a search leg departs from or arrives at.
///
/// Identity is the IATA code — content-derived and stable (no per-init `UUID()`
/// churn in `ForEach`, matching the `FlightLeg.id` precedent).
public struct Airport: Identifiable, Sendable, Hashable, Codable {
    public var id: String { code }
    /// IATA location code, e.g. `"IST"`.
    public let code: String
    /// Full airport name, e.g. `"Istanbul Airport"`.
    public let name: String
    /// The city the airport serves.
    public let city: String
    /// ISO 3166-1 alpha-2 region code; display names resolve via `Locale`.
    public let countryCode: String?

    public init(code: String, name: String, city: String, countryCode: String? = nil) {
        self.code = code
        self.name = name
        self.city = city
        self.countryCode = countryCode
    }
}

// MARK: - CabinClass

/// The service cabin a search or fare applies to. Drives `CabinClassSelector`.
public enum CabinClass: String, CaseIterable, Sendable, Codable {
    case economy, premiumEconomy, business, first

    /// Localized display name (English source; overridable via the edition catalog).
    public var label: String {
        switch self {
        case .economy: String(themeKitTravel: "Economy")
        case .premiumEconomy: String(themeKitTravel: "Premium Economy")
        case .business: String(themeKitTravel: "Business")
        case .first: String(themeKitTravel: "First")
        }
    }

    /// SF Symbol representing the cabin.
    public var glyph: String {
        switch self {
        case .economy: "chair"
        case .premiumEconomy: "chair.lounge"
        case .business: "briefcase"
        case .first: "crown"
        }
    }
}

// MARK: - TripType

/// The itinerary shape of a search. Drives `TripTypeToggle` / `TripSearchCard`.
public enum TripType: String, CaseIterable, Sendable, Codable {
    case oneWay, roundTrip, multiCity

    /// Localized display name (English source; overridable via the edition catalog).
    public var label: String {
        switch self {
        case .oneWay: String(themeKitTravel: "One way")
        case .roundTrip: String(themeKitTravel: "Round trip")
        case .multiCity: String(themeKitTravel: "Multi-city")
        }
    }
}

// MARK: - PassengerCount

/// How many travelers a search covers. Invariants are self-healing: `adults`
/// never drops below 1, `children`/`infants` never below 0 — enforced in the
/// initializer, on direct mutation, and on decode.
public struct PassengerCount: Sendable, Equatable, Codable {
    public var adults: Int { didSet { adults = max(1, adults) } }
    public var children: Int { didSet { children = max(0, children) } }
    public var infants: Int { didSet { infants = max(0, infants) } }

    public init(adults: Int = 1, children: Int = 0, infants: Int = 0) {
        self.adults = max(1, adults)
        self.children = max(0, children)
        self.infants = max(0, infants)
    }

    /// All travelers, regardless of age band.
    public var total: Int { adults + children + infants }

    // Decode routes through the clamping initializer so persisted or hand-made
    // payloads can't smuggle an invalid count past the invariants.
    private enum CodingKeys: String, CodingKey { case adults, children, infants }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.init(adults: try container.decode(Int.self, forKey: .adults),
                  children: try container.decode(Int.self, forKey: .children),
                  infants: try container.decode(Int.self, forKey: .infants))
    }
}

// MARK: - TripSearchDraft

/// The in-progress state of a flight search — the single value `TripSearchCard`
/// binds to (`draft: Binding<TripSearchDraft>`). Dates are self-healing: a
/// return date never precedes the departure date (whichever side is mutated,
/// the return date is pulled forward to keep the pair ordered).
public struct TripSearchDraft: Sendable, Equatable {
    public var tripType: TripType = .roundTrip
    public var origin: Airport?
    public var destination: Airport?
    public var departureDate: Date? { didSet { clampDates() } }
    /// Meaningful only for `.roundTrip`.
    public var returnDate: Date? { didSet { clampDates() } }
    public var passengers: PassengerCount = .init()
    public var cabin: CabinClass = .economy

    public init() {}

    /// Swaps origin and destination (the round-arrow affordance on search forms).
    public mutating func swapRoute() {
        swap(&origin, &destination)
    }

    private mutating func clampDates() {
        if let departure = departureDate, let ret = returnDate, ret < departure {
            returnDate = departure
        }
    }
}
