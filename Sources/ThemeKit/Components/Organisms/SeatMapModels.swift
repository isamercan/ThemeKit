//
//  SeatMapModels.swift
//  ThemeKit
//
//  Value types shared by the seat-map family (``SeatCell`` atom, ``SeatLegend``
//  molecule, ``SeatMap`` organism). Fully generic — no product/domain coupling.
//

import SwiftUI

/// A single seat and its fare features. The fare tier is the source of truth; the
/// `isPremium` / `isExitRow` … flags are convenience read-outs derived from it.
public struct Seat: Identifiable, Sendable, Hashable, Codable {
    public let id: String        // e.g. "12A"
    public var isOccupied: Bool
    /// The fare tier — standard / extra-legroom / exit / premium-economy / business / first.
    public var tier: SeatTier
    public var price: Decimal?
    /// Deck / floor this seat is on (e.g. 1 = main, 2 = upper). `nil` = single deck.
    public var floor: Int?

    public var isExtraLegroom: Bool { tier == .extraLegroom }
    public var isExitRow: Bool { tier == .exit }
    public var isPremium: Bool { tier == .premium }
    public var isBusiness: Bool { tier == .business }
    public var isFirst: Bool { tier == .first }

    /// Designated initializer. Pass `tier:` directly, or use the legacy `premium` /
    /// `extraLegroom` / `exitRow` flags (mapped to a tier for backward compatibility).
    public init(_ id: String,
                occupied: Bool = false,
                premium: Bool = false,
                extraLegroom: Bool = false,
                exitRow: Bool = false,
                tier: SeatTier? = nil,
                price: Decimal? = nil,
                floor: Int? = nil) {
        self.id = id
        self.isOccupied = occupied
        self.price = price
        self.floor = floor
        if let tier { self.tier = tier }
        else if premium { self.tier = .premium }
        else if exitRow { self.tier = .exit }
        else if extraLegroom { self.tier = .extraLegroom }
        else { self.tier = .standard }
    }
}

/// A cell in a seat row — an explicit, typed unit. Every cell (seat **or** gap)
/// is a first-class element of the row array, so each row can have its own shape.
public enum SeatSlot: Sendable, Hashable {
    /// A seat, carrying its data.
    case seat(Seat)
    /// An empty cell — an aisle, a removed seat, a table. Occupies a gap column.
    case space

    /// Backward-compatible alias for ``space``.
    public static var aisle: SeatSlot { .space }
}

/// A fare tier / cabin class a seat belongs to — drives its colour and legend entry.
public enum SeatTier: String, Sendable, Hashable, Codable, CaseIterable {
    case standard, extraLegroom, exit, premium, business, first
    public var label: String {
        switch self {
        case .standard: return "Standard"
        case .extraLegroom: return "Extra legroom"
        case .exit: return "Exit row"
        case .premium: return "Premium econ."
        case .business: return "Business"
        case .first: return "First"
        }
    }
    /// SF Symbol drawn on an available seat of this tier.
    public var glyph: String {
        switch self {
        case .standard: return "chair"
        case .extraLegroom: return "arrow.up.and.down"
        case .exit: return "door.left.hand.open"
        case .premium: return "star"
        case .business: return "briefcase.fill"
        case .first: return "crown.fill"
        }
    }
    /// Cabin-class ordering (economy → first), for legend/section ordering.
    public var rank: Int {
        switch self {
        case .standard: return 0
        case .extraLegroom: return 1
        case .exit: return 2
        case .premium: return 3
        case .business: return 4
        case .first: return 5
        }
    }
}

/// Maps a ``SeatTier`` to its fill + stroke colours — token-derived by default,
/// fully overridable per tier so a brand can map its own palette.
public struct SeatPalette: Sendable {
    private let overrides: [SeatTier: Color]
    public init(_ overrides: [SeatTier: Color] = [:]) { self.overrides = overrides }
    public static let `default` = SeatPalette()

    /// Fill + stroke for a tier. An overridden tier derives a light fill from its accent.
    public func colors(for tier: SeatTier, theme: Theme) -> (fill: Color, stroke: Color) {
        if let accent = overrides[tier] { return (accent.opacity(0.14), accent) }
        switch tier {
        case .standard: return (theme.background(.bgElevatorPrimary), theme.border(.borderPrimary))
        case .extraLegroom: return (SemanticColor.info.bg, SemanticColor.info.base)
        case .exit: return (SemanticColor.warning.bg, SemanticColor.warning.base)
        case .premium: return (theme.background(.bgTurquoiseLight), theme.background(.bgTurquoise))
        case .business: return (SemanticColor.purple.bg, SemanticColor.purple.base)
        case .first: return (SemanticColor.pink.bg, SemanticColor.pink.base)
        }
    }
}

/// Per-seat data returned by the column-pattern `seat:` provider — the seat's id
/// is derived from the row + column, so you only describe its state.
public struct SeatInfo: Sendable {
    public var isAvailable: Bool
    public var price: Decimal?
    public var tier: SeatTier
    public var floor: Int?

    public init(available: Bool = true, price: Decimal? = nil, tier: SeatTier = .standard, floor: Int? = nil) {
        self.isAvailable = available
        self.price = price
        self.tier = tier
        self.floor = floor
    }
    /// A plain available seat.
    public static let available = SeatInfo()
    /// An occupied / unavailable seat.
    public static let occupied = SeatInfo(available: false)
}

/// A cabin section (Business / Premium Economy / Economy…) with its own rows and
/// an optional header.
public struct SeatSection: Identifiable, Sendable, Hashable {
    public var id: String { title ?? "cabin" }
    public let title: String?
    public let rows: [[SeatSlot]]
    public init(_ title: String? = nil, rows: [[SeatSlot]]) {
        self.title = title
        self.rows = rows
    }
}

/// A traveller a seat can be assigned to (see `SeatMap.passengers`).
public struct Passenger: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let initials: String
    public init(id: String, initials: String) {
        self.id = id
        self.initials = initials
    }
}

/// How a seat's inner content is drawn — pick a built-in mode, or supply a fully
/// custom view with `SeatMap.seatLabel { … }`.
public enum SeatDisplay: Sendable {
    /// State / tier icons — chair · check · ✕ (default).
    case icon
    /// The seat id, e.g. "12A".
    case number
    /// The assigned passenger's initials (falls back to the icon when unassigned).
    case initials
    /// Assigned initials **and** the seat id stacked (e.g. "EA" over "1E") —
    /// falls back to just the seat id when unassigned.
    case initialsAndNumber
}

/// The state handed to a custom `seatLabel { … }` builder so it can render its own UI.
public struct SeatContext: Sendable {
    public let seat: Seat
    public let isSelected: Bool
    public let isOccupied: Bool
    /// Assigned passenger initials, in passenger-assignment mode.
    public let assignedInitials: String?
    public var id: String { seat.id }
    public var tier: SeatTier { seat.tier }
}

// MARK: - Layout builders (column patterns → explicit rows)

/// Parses one row pattern (`"ABC DE"` — letters = seats, space/`.`/`_` = space cell;
/// repeat for a wider gap) into an explicit `[SeatSlot]` (spaces are real `.space` cells).
func buildSeatRow(_ pattern: String, row: Int, seat: (String, Int, String) -> SeatInfo) -> [SeatSlot] {
    pattern.map { ch -> SeatSlot in
        if ch == " " || ch == "." || ch == "_" { return .space }
        let letter = String(ch)
        let id = "\(row)\(letter)"
        let info = seat(id, row, letter)
        return .seat(Seat(id, occupied: !info.isAvailable, tier: info.tier, price: info.price, floor: info.floor))
    }
}

/// One uniform column pattern applied to every row.
func buildSeatRows(columns: String, rows: [Int], seat: (String, Int, String) -> SeatInfo) -> [[SeatSlot]] {
    rows.map { buildSeatRow(columns, row: $0, seat: seat) }
}

/// Per-row patterns — each string defines its own row shape (rows may differ).
func buildSeatRows(rowPatterns: [String], startRow: Int, seat: (String, Int, String) -> SeatInfo) -> [[SeatSlot]] {
    rowPatterns.enumerated().map { i, pattern in buildSeatRow(pattern, row: startRow + i, seat: seat) }
}

public extension SeatSection {
    /// Builds a cabin section from a uniform column pattern + row list.
    init(_ title: String? = nil,
         columns: String,
         rows: [Int],
         seat: (_ id: String, _ row: Int, _ column: String) -> SeatInfo = { _, _, _ in SeatInfo() }) {
        self.init(title, rows: buildSeatRows(columns: columns, rows: rows, seat: seat))
    }

    /// Builds a cabin section from **per-row** patterns (each row may have its own
    /// shape), numbered from `startRow`.
    init(_ title: String? = nil,
         rowPatterns: [String],
         startRow: Int = 1,
         seat: (_ id: String, _ row: Int, _ column: String) -> SeatInfo = { _, _, _ in SeatInfo() }) {
        self.init(title, rows: buildSeatRows(rowPatterns: rowPatterns, startRow: startRow, seat: seat))
    }
}
