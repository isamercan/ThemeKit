//
//  ThemeKitTravel.swift
//  ThemeKitTravel
//
//  The ThemeKitTravel domain edition — an opt-in module that packages the
//  flight/booking component family and WRAPS ThemeKit's neutral primitives
//  (`TextInput`, `Select`, `DateField`, `FormValidator`, …) into booking-flow
//  organisms. It follows the #229 modular direction:
//
//      ThemeKitCore  (token engine)
//        └─ ThemeKit  (neutral catalog)
//             └─ ThemeKitTravel  (domain edition — composition, not forking)
//
//  Dependency is strictly one-way (Core ← ThemeKit ← Travel); nothing in
//  `ThemeKit` may name a `ThemeKitTravel` type. There is deliberately NO
//  `@_exported import ThemeKit`: consumers import both modules explicitly —
//
//      import ThemeKit
//      import ThemeKitTravel
//
//  mirroring `ThemeKitCalendar`, so the neutral namespace is never re-polluted
//  by a domain edition.
//
//  Architecture of record: `THEMEKITTRAVEL_ARCHITECTURE.md` (ADR-F1…F7).
//

import ThemeKit

/// Namespace + metadata marker for the ThemeKitTravel domain edition.
///
/// The type is intentionally lightweight — the edition's surface is its
/// components and models, not this enum. It exists so a consumer (or a
/// diagnostic/telemetry line) has a stable, discoverable handle on the edition,
/// and so the packaging is verifiable before any component ships.
public enum TravelEdition {

    /// Human-readable edition name.
    public static let name = "ThemeKitTravel"

    /// The vertical this edition covers. Later clusters (Stay, Transport) join
    /// the *same* module (never sibling modules — booking renders flight
    /// components, so siblings would cycle); cluster membership is expressed via
    /// DocC topics + naming, never folders. Flight ships first.
    public static let clusters = ["Flight", "Stay", "Transport"]
}
