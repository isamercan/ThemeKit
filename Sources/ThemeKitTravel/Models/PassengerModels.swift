//
//  PassengerModels.swift
//  ThemeKitTravel
//
//  Canonical traveler-details models (ADR-F3 §4.2) — the value `PassengerForm`
//  binds to. Generic and data-driven: no airline/agency schema, no document
//  validation policy (that belongs to the app's rule pack via FormValidator).
//
//  Note: `DialCode` is NOT an edition model — it ships neutral alongside
//  `PhoneField` in `ThemeKit/Molecules` (§1.4 OQ-4), so phone entry is absent here.
//

import Foundation
import ThemeKit

// MARK: - PassengerGender

/// Gender as airlines record it on a booking. Drives the form's selector.
public enum PassengerGender: String, CaseIterable, Sendable, Codable {
    case female, male, unspecified

    /// Localized display name (English source; overridable via the edition catalog).
    public var label: String {
        switch self {
        case .female: String(themeKitTravel: "Female")
        case .male: String(themeKitTravel: "Male")
        case .unspecified: String(themeKitTravel: "Unspecified")
        }
    }
}

// MARK: - PassengerDraft

/// The in-progress state of one traveler's details form. Starts empty; every
/// field is directly settable so `PassengerForm` can bind row-by-row.
/// `Codable` so a checkout flow can persist a half-finished traveler.
public struct PassengerDraft: Sendable, Equatable, Codable {
    public var givenName = ""
    public var familyName = ""
    public var gender: PassengerGender?
    public var dateOfBirth: Date?
    /// ISO 3166-1 region code; display names resolve via `Locale`.
    public var nationality: String?
    /// Passport or national ID number.
    public var documentNumber = ""
    public var documentExpiry: Date?

    public init() {}
}

public extension PassengerDraft {
    /// The canonical-strings serialization (ADR-F6) `FormValidator` consumes:
    ///
    ///     if form.validateAll(traveler.formValues) == nil { proceed(traveler) }
    ///
    /// Pinned conventions (§1.4 rev 4): dates serialize as ISO-8601 calendar
    /// dates (`"2027-04-19"`, locale-independent — the rule pack's date
    /// factories parse the same shape), enums as their `rawValue`, and absent
    /// optionals as `""` (so `.required()` applies naturally).
    var formValues: [PassengerFormField: String] {
        [
            .givenName: givenName,
            .familyName: familyName,
            .gender: gender?.rawValue ?? "",
            .dateOfBirth: dateOfBirth.map(ISO8601Day.string(from:)) ?? "",
            .nationality: nationality ?? "",
            .documentNumber: documentNumber,
            .documentExpiry: documentExpiry.map(ISO8601Day.string(from:)) ?? "",
        ]
    }
}
