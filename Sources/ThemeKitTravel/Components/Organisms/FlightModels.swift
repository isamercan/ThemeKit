//
//  FlightModels.swift
//  ThemeKit
//
//  The consolidated, brand-neutral flight model vocabulary shared by the flight
//  family (``FlightCard``, ``FlightListItem``, ``FareSummary``, ``FareFeatureRow``,
//  ``FlightStatusBadge``…). Models are the *vocabulary*; per-component
//  configurations slice them for a style. Fully generic — no product/domain
//  coupling, no view code.
//

import Foundation
import ThemeKit

/// A flight status pill's state — on-time / boarding / delayed / gate-closed /
/// departed / arrived / cancelled. Rendered by ``FlightStatusBadge``.
public enum FlightStatus: String, Sendable, CaseIterable {
    case onTime, boarding, delayed, gateClosed, departed, arrived, cancelled

    /// Default English display label (overridable at every render site).
    /// Public so editions (e.g. `FlightTracker`) reuse the canonical wording.
    public var label: String {
        switch self {
        case .onTime: "On time"; case .boarding: "Boarding"; case .delayed: "Delayed"
        case .gateClosed: "Gate closed"; case .departed: "Departed"; case .arrived: "Arrived"; case .cancelled: "Cancelled"
        }
    }
    /// The status's semantic tone — the single source of truth for status
    /// colouring across the flight family (badge, tracker progress, estimates).
    public var semantic: SemanticColor {
        switch self {
        case .onTime, .arrived: .success
        case .boarding, .departed: .info
        case .delayed, .gateClosed: .warning
        case .cancelled: .error
        }
    }
    /// SF Symbol name paired with the status.
    public var icon: String {
        switch self {
        case .onTime: "checkmark.circle.fill"; case .boarding: "figure.walk"; case .delayed: "clock.fill"
        case .gateClosed: "lock.fill"; case .departed: "airplane.departure"; case .arrived: "airplane.arrival"; case .cancelled: "xmark.circle.fill"
        }
    }
}

/// One leg of a multi-leg ``FlightCard`` (outbound, return, connection…).
public struct FlightLeg: Identifiable, Sendable, Equatable, Codable {
    /// Stable, content-derived identity (no per-init `UUID()` churn in `ForEach`).
    public var id: String { "\(origin)-\(destination)@\(Int(departure.timeIntervalSinceReferenceDate))" }
    public let airline: String
    public let origin: String
    public let destination: String
    public let departure: Date
    public let arrival: Date
    public var stops: Int
    /// Layover summary shown under the path, e.g. `"1 stop · 6h 45m · ESB"`.
    public var layover: String?

    public init(airline: String, from origin: String, to destination: String,
                departure: Date, arrival: Date, stops: Int = 0, layover: String? = nil) {
        self.airline = airline
        self.origin = origin
        self.destination = destination
        self.departure = departure
        self.arrival = arrival
        self.stops = stops
        self.layover = layover
    }
}

/// One purchasable fare option on a flight (fare-family shopping — Delta/THY
/// style "Basic / Classic / Flex" columns). Rendered by ``FlightListItemStyle``s
/// that surface multiple prices per flight (e.g. `.fareBoard`).
public struct FlightFare: Identifiable, Sendable, Equatable {
    /// Stable, content-derived identity (no per-init `UUID()` churn in `ForEach`).
    public var id: String { name }
    public let name: String
    public let price: Decimal
    /// SF Symbol names for 1–2 headline perks (e.g. `"suitcase.fill"`).
    public var perks: [String]

    public init(_ name: String, price: Decimal, perks: [String] = []) {
        self.name = name
        self.price = price
        self.perks = perks
    }
}

/// One line of a ``FareSummary``.
public struct FareLine: Identifiable, Sendable, Equatable, Codable {
    public enum Kind: String, Sendable, Codable { case item, discount, total }
    /// Stable, content-derived identity (no per-init `UUID()` churn in `ForEach`).
    public var id: String { "\(kind.rawValue):\(label)" }
    let label: String
    let amount: Decimal
    let kind: Kind
    let info: String?

    /// A regular charge (base fare, taxes, a service fee…).
    public static func item(_ label: String, _ amount: Decimal, info: String? = nil) -> FareLine {
        .init(label: label, amount: amount, kind: .item, info: info)
    }
    /// A saving — rendered green with a leading minus.
    public static func discount(_ label: String, _ amount: Decimal, info: String? = nil) -> FareLine {
        .init(label: label, amount: amount, kind: .discount, info: info)
    }
    /// The emphasised total — rendered as a hero `PriceTag` under a divider.
    public static func total(_ label: String, _ amount: Decimal, info: String? = nil) -> FareLine {
        .init(label: label, amount: amount, kind: .total, info: info)
    }
}
