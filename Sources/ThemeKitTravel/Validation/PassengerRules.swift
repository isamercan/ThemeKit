//
//  PassengerRules.swift
//  ThemeKitTravel
//
//  The traveler-document VALIDATION RULE PACK (§9.2 / ADR-F6): domain factories
//  on the neutral `ValidationRule` so an app declares document policy in one
//  `FormValidator` literal:
//
//      FormValidator<PassengerFormField>([
//          .documentNumber: [.required(), .documentNumber],
//          .documentExpiry: [.expiryInFuture(after: tripDate)],
//      ])
//
//  Canonical strings (ADR-F6, §1.4 rev 4): rules validate the SERIALIZED form
//  value from `PassengerDraft.formValues` — dates are pinned to ISO-8601
//  calendar dates (`yyyy-MM-dd`), enums to their `rawValue`. Date factories
//  parse ISO-8601 only; a non-ISO string fails the rule (never crashes).
//

import Foundation
import ThemeKit

// MARK: - ISO-8601 calendar-date serialization (ADR-F6)

/// The edition's single date⇄string convention: ISO-8601 calendar date
/// ("2027-04-19"), locale-independent in both directions. Shared by
/// `PassengerDraft.formValues` (serialize) and the rule pack (parse).
enum ISO8601Day {
    static func string(from date: Date) -> String {
        date.formatted(.iso8601.year().month().day().dateSeparator(.dash))
    }

    static func date(from string: String) -> Date? {
        try? Date(string, strategy: .iso8601.year().month().day().dateSeparator(.dash))
    }
}

// MARK: - Traveler-document rules

public extension ValidationRule {
    /// A generic machine-readable travel-document number (passport / national
    /// ID): 5–20 letters and digits, no spaces or punctuation. Deliberately
    /// permissive — per-country policy belongs to the app's own rule.
    static var documentNumber: ValidationRule {
        .regex("^[A-Za-z0-9]{5,20}$",
               String(themeKitTravel: "Enter a valid document number"))
    }

    /// The document's expiry date (an ISO-8601 calendar-date string, per
    /// `PassengerDraft.formValues`) must fall strictly after `reference` —
    /// pass the trip date so documents expiring mid-trip fail. Skipped while
    /// the value is empty (pair with `.required()` to also demand a date).
    static func expiryInFuture(after reference: Date = .now,
                               _ message: String? = nil) -> ValidationRule {
        ValidationRule(message ?? String(themeKitTravel: "Document must be valid on the travel date")) { value in
            guard let date = ISO8601Day.date(from: value) else { return false }
            return date > reference
        }
    }
}
