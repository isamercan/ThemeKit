//
//  FlightDefaults.swift
//  ThemeKitTravel
//
//  A subtree-level "house style" for flight components — default accent, the SF
//  Symbol used where no airline logo is provided, and the time/date formats for
//  schedule-dense components. Set it once with `.flightDefaults(...)`; flight
//  components read it as their default when the corresponding modifier isn't set
//  explicitly. Additive and Open/Closed: a per-call modifier still wins.
//
//  Resolution order (ADR-F2): explicit per-call argument > `flightDefaults`
//  > `componentDefaults`/`formatDefaults` > environment natives (`\.locale`)
//  > the component's own constant.
//
//  ```swift
//  BookingFlow()
//      .flightDefaults(airlineSymbol: "airplane.circle",
//                      timeFormat: .dateTime.hour().minute())
//  ```
//

import SwiftUI
import ThemeKit

public struct FlightDefaults: Equatable, Sendable {
    /// Accent for flight components (falls back to `componentDefaults.accent`,
    /// then each component's own default — usually the hero foreground token).
    public var accent: SemanticColor?
    /// SF Symbol used where no airline logo slot is provided.
    public var airlineSymbol: String?
    /// Time format for schedule-dense flight components (FlightTracker,
    /// TripSearchCard summaries).
    public var timeFormat: Date.FormatStyle?
    /// Date format for schedule-dense flight components.
    public var dateFormat: Date.FormatStyle?

    public init(accent: SemanticColor? = nil,
                airlineSymbol: String? = nil,
                timeFormat: Date.FormatStyle? = nil,
                dateFormat: Date.FormatStyle? = nil) {
        self.accent = accent
        self.airlineSymbol = airlineSymbol
        self.timeFormat = timeFormat
        self.dateFormat = dateFormat
    }
}

private struct FlightDefaultsKey: EnvironmentKey {
    // Plain `static let` — `FlightDefaults` is `Sendable` (all fields are), so no
    // `nonisolated(unsafe)` escape hatch is needed (§1.4 revision 2).
    static let defaultValue = FlightDefaults()
}

public extension EnvironmentValues {
    var flightDefaults: FlightDefaults {
        get { self[FlightDefaultsKey.self] }
        set { self[FlightDefaultsKey.self] = newValue }
    }
}

public extension View {
    /// Sets the flight-family defaults for ThemeKitTravel components in this
    /// subtree. Only the provided fields are set (non-nil merge); a component's
    /// explicit modifier still overrides.
    func flightDefaults(accent: SemanticColor? = nil,
                        airlineSymbol: String? = nil,
                        timeFormat: Date.FormatStyle? = nil,
                        dateFormat: Date.FormatStyle? = nil) -> some View {
        transformEnvironment(\.flightDefaults) { d in
            if let accent { d.accent = accent }
            if let airlineSymbol { d.airlineSymbol = airlineSymbol }
            if let timeFormat { d.timeFormat = timeFormat }
            if let dateFormat { d.dateFormat = dateFormat }
        }
    }
}
