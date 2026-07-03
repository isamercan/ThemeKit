//
//  SeatMap.swift
//  ThemeKit
//
//  A cabin seat picker — a grid of seats with aisles, occupied/premium states and a
//  multi-select binding. Token-bound: available / selected / occupied / premium all
//  resolve from the theme. Suits flight & event seat selection.
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
/// SeatMap(rows: layout, selection: $picked).maxSelection(2)
/// ```
public struct SeatMap: View {
    @Environment(\.theme) private var theme

    private let rows: [[SeatSlot]]
    @Binding private var selection: Set<String>
    // Appearance/state — mutated only through the modifiers below (R2).
    private var maxSelection: Int = .max
    private var seatSize: CGFloat = 34

    public init(rows: [[SeatSlot]], selection: Binding<Set<String>>) {
        self.rows = rows
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.xs.value) {
            ForEach(Array(rows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                        switch slot {
                        case .aisle: Color.clear.frame(width: seatSize * 0.6, height: seatSize)
                        case .seat(let seat): seatView(seat)
                        }
                    }
                }
            }
        }
    }

    private func seatView(_ seat: Seat) -> some View {
        let selected = selection.contains(seat.id)
        return Button { toggle(seat) } label: {
            RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                .fill(fill(seat, selected: selected))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .stroke(stroke(seat, selected: selected), lineWidth: 1)
                )
                .overlay(
                    Image(systemName: selected ? "checkmark" : (seat.isOccupied ? "xmark" : "chair"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(content(seat, selected: selected))
                )
                .frame(width: seatSize, height: seatSize)
        }
        .buttonStyle(.plain)
        .disabled(seat.isOccupied)
        .accessibilityLabel("Seat \(seat.id)\(seat.isOccupied ? ", occupied" : selected ? ", selected" : "")")
    }

    private func toggle(_ seat: Seat) {
        guard !seat.isOccupied else { return }
        if selection.contains(seat.id) {
            selection.remove(seat.id)
        } else if selection.count < maxSelection {
            selection.insert(seat.id)
        }
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
    /// Seat square size in points (default 34).
    func seatSize(_ size: CGFloat) -> Self { copy { $0.seatSize = size } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
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
            SeatMap(rows: rows, selection: $picked).maxSelection(3).padding()
        }
    }
    return Demo()
}
