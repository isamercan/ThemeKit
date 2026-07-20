//
//  SeatMapModels.swift
//  ThemeKit
//
//  Value types shared by the seat-map family (``SeatCell`` atom, ``SeatLegend``
//  molecule, ``SeatMap`` organism). Fully generic — no product/domain coupling.
//

import SwiftUI
import ThemeKit

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
        case .standard: return String(themeKit: "Standard")
        case .extraLegroom: return String(themeKit: "Extra legroom")
        case .exit: return String(themeKit: "Exit row")
        case .premium: return String(themeKit: "Premium econ.")
        case .business: return String(themeKit: "Business")
        case .first: return String(themeKit: "First")
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
/// fully overridable per tier so a brand can map its own palette. The **selected**
/// and **occupied** states are palette entries too (``selected(_:)`` /
/// ``occupied(_:)``), so ``SeatCell`` and ``SeatLegend`` always agree.
public struct SeatPalette: Sendable {
    private var overrides: [SeatTier: Color]
    private var selectedAccent: SemanticColor?
    private var selectedRaw: Color?
    private var occupiedAccent: SemanticColor?
    private var occupiedRaw: Color?

    public init(_ overrides: [SeatTier: Color] = [:]) { self.overrides = overrides }
    public static let `default` = SeatPalette()

    /// Fill + stroke for a tier. An overridden tier derives a light fill from its accent.
    ///
    /// ADR-0006 (Class P — the split-brain witness): every branch now resolves
    /// through the passed `theme`, so the accent tiers honor a `.theme(_:)`
    /// subtree the same way the `.standard`/`.premium` branches already did.
    public func colors(for tier: SeatTier, theme: Theme) -> (fill: Color, stroke: Color) {
        if let accent = overrides[tier] { return (accent.opacity(0.14), accent) }
        switch tier {
        case .standard: return (theme.background(.bgBase), theme.border(.borderPrimary))
        case .extraLegroom: return (theme.resolve(.info).bg, theme.resolve(.info).base)
        case .exit: return (theme.resolve(.warning).bg, theme.resolve(.warning).base)
        case .premium: return (theme.background(.bgTurquoiseLight), theme.background(.bgTurquoise))
        case .business: return (theme.resolve(.purple).bg, theme.resolve(.purple).base)
        case .first: return (theme.resolve(.pink).bg, theme.resolve(.pink).base)
        }
    }

    /// Fill + stroke + content colour of a **selected** seat. Defaults to the
    /// theme's hero foreground; an accent override uses its `.solid` / `.onSolid` pair.
    public func selectedColors(theme: Theme) -> (fill: Color, stroke: Color, content: Color) {
        if let accent = selectedAccent {
            let resolved = theme.resolve(accent)
            return (resolved.solid, resolved.solid, resolved.onSolid)
        }
        if let raw = selectedRaw { return (raw, raw, theme.text(.textSecondaryInverse)) }
        return (theme.foreground(.fgHero), theme.foreground(.fgHero), theme.text(.textSecondaryInverse))
    }

    /// Fill + stroke + content colour of an **occupied** seat. Defaults to the
    /// theme's muted secondary surface; an accent override uses its `.soft` /
    /// `.border` / `.base` shades.
    public func occupiedColors(theme: Theme) -> (fill: Color, stroke: Color, content: Color) {
        if let accent = occupiedAccent {
            let resolved = theme.resolve(accent)
            return (resolved.soft, resolved.border, resolved.base)
        }
        if let raw = occupiedRaw { return (raw.opacity(0.14), raw, theme.text(.textTertiary)) }
        return (theme.background(.bgSecondary), theme.border(.borderPrimary), theme.text(.textTertiary))
    }
}

public extension SeatPalette {
    /// Accent for the **selected** state — fill/stroke use the token's `.solid`
    /// shade and content its `.onSolid`. Pass `nil` to restore the hero default.
    func selected(_ color: SemanticColor?) -> Self {
        copy { $0.selectedAccent = color; $0.selectedRaw = nil }
    }
    /// Accent for the **occupied** state — surface uses the token's `.soft` /
    /// `.border` shades. Pass `nil` to restore the muted default.
    func occupied(_ color: SemanticColor?) -> Self {
        copy { $0.occupiedAccent = color; $0.occupiedRaw = nil }
    }

    /// Raw-color selected override (back-compat); prefer the token-bound overload.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use selected(_: SemanticColor?) — the token-bound overload.")
    func selected(_ color: Color?) -> Self {
        copy { $0.selectedRaw = color; $0.selectedAccent = nil }
    }
    /// Raw-color occupied override (back-compat); prefer the token-bound overload.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use occupied(_: SemanticColor?) — the token-bound overload.")
    func occupied(_ color: Color?) -> Self {
        copy { $0.occupiedRaw = color; $0.occupiedAccent = nil }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
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

/// The silhouette a seat cell — and its matching legend swatch — is drawn with.
/// Shared by ``SeatCell``, ``SeatLegend`` and ``SeatMap`` so the key always
/// matches the map (`SeatMap.seatShape(_:)` forwards it to both).
public enum SeatShape: Sendable, Hashable, CaseIterable {
    /// A continuous-corner rounded square (the default).
    case rounded
    /// A circle.
    case circle
    /// A squircle with a concave backrest notch cut into its top edge — the
    /// seat-back silhouette.
    case seatback

    /// The concrete shape, type-erased. `.rounded` takes the caller's corner
    /// radius (``SeatCell`` passes the selector role's value; ``SeatLegend``
    /// its smaller swatch radius); the other silhouettes ignore it.
    func anyShape(cornerRadius: CGFloat) -> ThemeAnyShape {
        switch self {
        case .rounded: return ThemeAnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        case .circle: return ThemeAnyShape(Circle())
        case .seatback: return ThemeAnyShape(SeatbackShape())
        }
    }
}

/// A squircle with a shallow concave notch cut out of its top edge — the
/// backrest between two "shoulders". Cut by path subtraction (like the ticket
/// notches), so fill *and* stroke both follow the notch. Symmetric, so it needs
/// no RTL handling.
private struct SeatbackShape: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width, rect.height) * 0.28
        let body = RoundedRectangle(cornerRadius: radius, style: .continuous).path(in: rect)
        // `Path.subtracting` is iOS 17-only. Below, the named legacy unit keeps
        // the plain rounded seatback (no backrest notch) — a decorative
        // degrade per ADR-0007 §D2 rule 2; Phase 3e restores it with real arc
        // geometry.
        if #available(iOS 17.0, *) {
            let notchWidth = rect.width * 0.52
            let notchHeight = rect.height * 0.24
            var notch = Path()
            notch.addEllipse(in: CGRect(x: rect.midX - notchWidth / 2, y: rect.minY - notchHeight / 2,
                                        width: notchWidth, height: notchHeight))
            return body.subtracting(notch)
        } else {
            return legacyNotchlessPath(body)
        }
    }

    /// Named legacy unit (ADR-0007 §D2 rule 3): the un-notched seatback outline.
    func legacyNotchlessPath(_ base: Path) -> Path { base }
}

/// Token-stepped seat sizes — the ramp alternative to a raw point size, shared
/// by `SeatMap.seatSize(_:)`, `SeatCell(_, size:)` and `SeatLegend.swatchSize(_:)`.
public enum SeatSizeRamp: Sendable, Hashable, CaseIterable {
    /// 36 pt — dense overview / mini-map grids. Below the 44 pt HIG touch
    /// minimum, so reserve it for read-only contexts.
    case compact
    /// 44 pt — the HIG minimum touch target (the default seat size).
    case regular
    /// 52 pt.
    case large
    /// 60 pt — hero pickers and large-canvas layouts.
    case xl

    /// The seat square's side, in points. Internal — the public surface stays
    /// token-typed; only the family's own views resolve the ramp.
    var points: CGFloat {
        switch self {
        case .compact: return 36
        case .regular: return 44
        case .large: return 52
        case .xl: return 60
        }
    }
}

/// A snapshot of a ``SeatMap``'s selection state, handed to a custom
/// `summaryBar { summary in … }` slot so brands can render their own footer
/// without re-deriving totals.
public struct SeatSummary: Sendable {
    /// The last-tapped seat, if any.
    public let focusedSeat: Seat?
    /// Whether the focused seat is a window seat (`nil` when nothing is focused).
    public let isWindow: Bool?
    /// Whether the focused seat is on an aisle (`nil` when nothing is focused).
    public let isAisle: Bool?
    /// How many seats are currently selected (or assigned, in passenger mode).
    public let selectedCount: Int
    /// The running total of the selected seats' prices.
    public let totalPrice: Decimal
    /// Whether any seat in the cabin carries a price.
    public let hasPrices: Bool
    /// The resolved currency code the map is formatting with.
    public let currencyCode: String

    public init(focusedSeat: Seat? = nil, isWindow: Bool? = nil, isAisle: Bool? = nil,
                selectedCount: Int = 0, totalPrice: Decimal = 0,
                hasPrices: Bool = false, currencyCode: String = "USD") {
        self.focusedSeat = focusedSeat
        self.isWindow = isWindow
        self.isAisle = isAisle
        self.selectedCount = selectedCount
        self.totalPrice = totalPrice
        self.hasPrices = hasPrices
        self.currencyCode = currencyCode
    }
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
