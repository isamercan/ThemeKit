//
//  PaymentModels.swift
//  ThemeKitTravel
//
//  Canonical payment-selection models (ADR-F3 §4.2) — consumed by
//  `PaymentMethodSelector` and `SavedCardsList`. `SavedCard` reuses the neutral
//  `CardBrand` enum from `PaymentCardField` (F0.4 added `Codable` to it so
//  `SavedCard`'s `Codable` synthesizes). Generic and data-driven — no PSP schema.
//

import Foundation
import ThemeKit

// MARK: - PaymentMethodOption

/// One selectable way to pay — a card, a wallet, or a bank transfer.
/// Identity is caller-supplied (the app's own method identifier).
public struct PaymentMethodOption: Identifiable, Sendable, Equatable {
    /// The family of payment method, used for the default iconography.
    public enum Kind: String, Sendable, Codable {
        case card, wallet, transfer

        /// SF Symbol used when the caller doesn't pass one.
        var defaultSystemImage: String {
            switch self {
            case .card: "creditcard"
            case .wallet: "wallet.pass"
            case .transfer: "building.columns"
            }
        }
    }

    public let id: String
    public let kind: Kind
    public let title: String
    public var subtitle: String?
    /// SF Symbol shown beside the title; defaulted per `kind` when omitted.
    public var systemImage: String

    public init(id: String, kind: Kind, title: String,
                subtitle: String? = nil, systemImage: String? = nil) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage ?? kind.defaultSystemImage
    }
}

// MARK: - SavedCard

/// A card on file — brand, masked digits and expiry. `Codable` so an app can
/// persist its wallet; expiry math stays in the model so every consumer agrees
/// on when a card stops being offerable.
public struct SavedCard: Identifiable, Sendable, Equatable, Codable {
    public let id: String
    /// Reused from the neutral `PaymentCardField` family.
    public let brand: CardBrand
    /// The last four digits, e.g. `"4242"`.
    public let last4: String
    public var holder: String?
    /// 1…12 (clamped); formatted by the consuming component with the env locale.
    public var expiryMonth: Int?
    /// Full (`2028`) or two-digit (`28`, treated as 2000-based) year.
    public var expiryYear: Int?

    public init(id: String, brand: CardBrand, last4: String, holder: String? = nil,
                expiryMonth: Int? = nil, expiryYear: Int? = nil) {
        self.id = id
        self.brand = brand
        self.last4 = last4
        self.holder = holder
        self.expiryMonth = expiryMonth.map { min(12, max(1, $0)) }
        self.expiryYear = expiryYear
    }

    /// Whether the card's validity window has passed. A card is valid through the
    /// last instant of its expiry month; missing expiry data reads as not expired
    /// (the model can't rule the card out). Pass a fixed `date`/`calendar` for
    /// deterministic tests.
    public func isExpired(asOf date: Date = .now, calendar: Calendar = .current) -> Bool {
        guard let month = expiryMonth, let year = expiryYear else { return false }
        let fullYear = year < 100 ? year + 2000 : year
        var components = DateComponents()
        components.year = fullYear
        components.month = month
        components.day = 1
        guard let firstOfExpiryMonth = calendar.date(from: components),
              let firstInvalidInstant = calendar.date(byAdding: .month, value: 1, to: firstOfExpiryMonth)
        else { return false }
        return date >= firstInvalidInstant
    }
}
