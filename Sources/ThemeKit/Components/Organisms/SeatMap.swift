//
//  SeatMap.swift
//  ThemeKit
//
//  A cabin seat picker — a grid of seats with aisles, occupied/premium states and a
//  multi-select binding. Token-bound: available / selected / occupied / premium all
//  resolve from the theme. Suits flight & event seat selection.
//
//  Flexible: 44pt seats (HIG minimum) that clamp Dynamic Type, optional column/row
//  rulers, a standalone SeatLegend, spring selection (reduce-motion aware) and a
//  VoiceOver seat-state label + hint.
//

import SwiftUI

/// A single seat.
public struct Seat: Identifiable, Sendable, Hashable {
    public let id: String        // e.g. "12A"
    public var isOccupied: Bool
    public var isPremium: Bool

    public init(_ id: String, occupied: Bool = false, premium: Bool = false) {
        self.id = id
        self.isOccupied = occupied
        self.isPremium = premium
    }
}

/// A cell in a seat row — a seat or an aisle gap.
public enum SeatSlot: Sendable, Hashable { case seat(Seat), aisle }

/// A token-bound seat map.
///
/// ```swift
/// SeatMap(rows: layout, selection: $picked).maxSelection(2).showsLabels().legend()
/// ```
public struct SeatMap: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let rows: [[SeatSlot]]
    @Binding private var selection: Set<String>
    // Appearance/state — mutated only through the modifiers below (R2).
    private var maxSelection: Int = .max
    private var seatSize: CGFloat = 44        // HIG minimum touch target
    private var showsLabels: Bool = false
    private var showsLegend: Bool = false

    private let gutter: CGFloat = 22

    public init(rows: [[SeatSlot]], selection: Binding<Set<String>>) {
        self.rows = rows
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            VStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
                if showsLabels { columnHeader }
                ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
                        if showsLabels {
                            Text(rowNumber(row)).textStyle(.overline500)
                                .foregroundStyle(theme.text(.textTertiary)).frame(width: gutter)
                        }
                        ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                            switch slot {
                            case .aisle: Color.clear.frame(width: seatSize * 0.6, height: seatSize)
                            case .seat(let seat): seatView(seat)
                            }
                        }
                    }
                }
            }
            .dynamicTypeClamp()
            if showsLegend { SeatLegend().showsPremium(hasPremium) }
        }
    }

    private var hasPremium: Bool {
        rows.contains { row in
            row.contains { slot in
                if case .seat(let s) = slot { return s.isPremium }
                return false
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if showsLabels { Color.clear.frame(width: gutter) }
            ForEach(Array(templateRow.enumerated()), id: \.offset) { _, slot in
                switch slot {
                case .aisle: Color.clear.frame(width: seatSize * 0.6)
                case .seat(let seat):
                    Text(columnLetter(seat.id)).textStyle(.overline500)
                        .foregroundStyle(theme.text(.textTertiary)).frame(width: seatSize)
                }
            }
        }
    }

    private func seatView(_ seat: Seat) -> some View {
        let selected = selection.contains(seat.id)
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { toggle(seat) }
        } label: {
            RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                .fill(fill(seat, selected: selected))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .stroke(stroke(seat, selected: selected), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: selected ? "checkmark" : (seat.isOccupied ? "xmark" : "chair"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(content(seat, selected: selected))
                )
                .frame(width: seatSize, height: seatSize)
        }
        .buttonStyle(.plain)
        .disabled(seat.isOccupied)
        .accessibilityLabel("Seat \(seat.id)\(seat.isPremium ? ", premium" : "")")
        .accessibilityValue(seat.isOccupied ? "Occupied" : selected ? "Selected" : "Available")
        .accessibilityHint(seat.isOccupied ? "" : "Double-tap to \(selected ? "deselect" : "select")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func toggle(_ seat: Seat) {
        guard !seat.isOccupied else { return }
        if selection.contains(seat.id) {
            selection.remove(seat.id)
        } else if selection.count < maxSelection {
            selection.insert(seat.id)
        }
    }

    private var templateRow: [SeatSlot] { rows.max(by: { $0.count < $1.count }) ?? [] }
    private func columnLetter(_ id: String) -> String { String(id.drop { $0.isNumber }) }
    private func rowNumber(_ row: [SeatSlot]) -> String {
        for slot in row { if case .seat(let s) = slot { return String(s.id.prefix { $0.isNumber }) } }
        return ""
    }

    private func fill(_ seat: Seat, selected: Bool) -> Color {
        if selected { return theme.foreground(.fgHero) }
        if seat.isOccupied { return theme.background(.bgSecondary) }
        if seat.isPremium { return theme.background(.bgTurquoiseLight) }
        return theme.background(.bgElevatorPrimary)
    }
    private func stroke(_ seat: Seat, selected: Bool) -> Color {
        if selected { return theme.foreground(.fgHero) }
        if seat.isPremium { return theme.background(.bgTurquoise) }
        return theme.border(.borderPrimary)
    }
    private func content(_ seat: Seat, selected: Bool) -> Color {
        if selected { return theme.text(.textSecondaryInverse) }
        if seat.isOccupied { return theme.text(.textTertiary) }
        return theme.text(.textSecondary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SeatMap {
    /// Max seats a user can pick at once (default unlimited).
    func maxSelection(_ count: Int) -> Self { copy { $0.maxSelection = max(1, count) } }
    /// Seat square size in points (default 44 — the HIG minimum touch target).
    func seatSize(_ size: CGFloat) -> Self { copy { $0.seatSize = max(44, size) } }
    /// Shows a column-letter header and a row-number gutter derived from the seat ids.
    func showsLabels(_ on: Bool = true) -> Self { copy { $0.showsLabels = on } }
    /// Appends a ``SeatLegend`` (Available / Selected / Occupied [/ Premium]).
    func legend(_ on: Bool = true) -> Self { copy { $0.showsLegend = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// A key for a ``SeatMap`` — Available / Selected / Occupied (and optionally Premium).
public struct SeatLegend: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    private var showsPremium: Bool = false

    public init() {}

    public var body: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            item(fill: theme.background(.bgElevatorPrimary), border: theme.border(.borderPrimary), "Available")
            item(fill: theme.foreground(.fgHero), border: theme.foreground(.fgHero), "Selected")
            item(fill: theme.background(.bgSecondary), border: theme.border(.borderPrimary), "Occupied")
            if showsPremium { item(fill: theme.background(.bgTurquoiseLight), border: theme.background(.bgTurquoise), "Premium") }
        }
    }

    private func item(fill: Color, border: Color, _ label: String) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(fill)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(border, lineWidth: 1))
                .frame(width: 14, height: 14)
            Text(label).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
        }
        .accessibilityElement(children: .combine)
    }

    /// Adds a "Premium" key.
    public func showsPremium(_ on: Bool = true) -> Self {
        var c = self; c.showsPremium = on; return c
    }
}

#Preview {
    struct Demo: View {
        @State private var picked: Set<String> = ["12C"]
        var rows: [[SeatSlot]] {
            (10...14).map { r in
                [.seat(Seat("\(r)A", premium: r == 10)), .seat(Seat("\(r)B")), .seat(Seat("\(r)C", occupied: r == 12)),
                 .aisle,
                 .seat(Seat("\(r)D")), .seat(Seat("\(r)E", occupied: r == 13)), .seat(Seat("\(r)F"))]
            }
        }
        var body: some View {
            SeatMap(rows: rows, selection: $picked).maxSelection(3).showsLabels().legend().padding()
        }
    }
    return Demo()
}
