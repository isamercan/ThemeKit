//
//  FlightStatusModels.swift
//  ThemeKitTravel
//
//  Canonical live flight-status model (ADR-F3 §4.2) — consumed by
//  `FlightTracker`. Wraps the neutral vocabulary rather than re-declaring it:
//  `FlightLeg` is the canonical leg (scheduled times) and `FlightStatus` is the
//  7-case atom enum from `FlightStatusBadge`; this adds the day-of-travel
//  overlay (gates, belts, estimates) on top.
//

import Foundation
import ThemeKit

/// Live operational status for one flight leg.
public struct FlightStatusInfo: Sendable, Equatable {
    /// The canonical leg — carries the *scheduled* departure/arrival.
    public var leg: FlightLeg
    /// Reused 7-case status atom (on-time / boarding / delayed / …).
    public var status: FlightStatus
    public var gate: String?
    public var terminal: String?
    public var checkInDesk: String?
    public var baggageBelt: String?
    /// Estimated departure, vs `leg.departure` (scheduled).
    public var estimatedDeparture: Date?
    /// Estimated arrival, vs `leg.arrival` (scheduled).
    public var estimatedArrival: Date?
    /// Aircraft type display string, e.g. `"A321neo"`.
    public var aircraft: String?

    public init(leg: FlightLeg,
                status: FlightStatus,
                gate: String? = nil,
                terminal: String? = nil,
                checkInDesk: String? = nil,
                baggageBelt: String? = nil,
                estimatedDeparture: Date? = nil,
                estimatedArrival: Date? = nil,
                aircraft: String? = nil) {
        self.leg = leg
        self.status = status
        self.gate = gate
        self.terminal = terminal
        self.checkInDesk = checkInDesk
        self.baggageBelt = baggageBelt
        self.estimatedDeparture = estimatedDeparture
        self.estimatedArrival = estimatedArrival
        self.aircraft = aircraft
    }
}
