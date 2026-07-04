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
public struct Seat: Identifiable, Sendable, Hashable, Codable {
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

/// A traveller a seat can be assigned to (see `SeatMap.passengers`).
public struct Passenger: Identifiable, Sendable, Hashable, Codable {
    public let id: String
    public let initials: String
    public init(id: String, initials: String) {
        self.id = id
        self.initials = initials
    }
}

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
    @State private var activePassenger: String?
    @State private var zoom: CGFloat = 1
    // Appearance/state — mutated only through the modifiers below (R2).
    private var maxSelection: Int = .max
    private var seatSize: CGFloat = 44        // HIG minimum touch target
    private var showsLabels: Bool = false
    private var showsLegend: Bool = false
    private var passengers: [Passenger] = []
    private var assignment: Binding<[String: String]>?
    private var zoomable: Bool = false

    private let gutter: CGFloat = 22
    private var passengerMode: Bool { !passengers.isEmpty && assignment != nil }

    public init(rows: [[SeatSlot]], selection: Binding<Set<String>>) {
        self.rows = rows
        self._selection = selection
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            if passengerMode { passengerTabs }
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
            .modifier(PinchZoom(enabled: zoomable, zoom: $zoom))
            if showsLegend { SeatLegend().showsPremium(hasPremium) }
        }
    }

    private var passengerTabs: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            ForEach(passengers) { passenger in
                let isActive = (activePassenger ?? passengers.first?.id) == passenger.id
                Button { activePassenger = passenger.id } label: {
                    VStack(spacing: 2) {
                        Text(passenger.initials).textStyle(.labelSm600)
                        Text(assignment?.wrappedValue[passenger.id] ?? "—").textStyle(.overline400)
                    }
                    .foregroundStyle(isActive ? theme.text(.textSecondaryInverse) : theme.text(.textPrimary))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isActive ? theme.foreground(.fgHero) : theme.background(.bgSecondaryLight), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Passenger \(passenger.initials), seat \(assignment?.wrappedValue[passenger.id] ?? "unassigned")")
            }
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
        // In passenger mode `assignment` is the single source of truth; `selection`
        // is a one-way output mirror (written in `assignSeat`, never read here).
        let assigned = passengerMode ? assignedInitials(seat.id) : nil
        let selected = passengerMode ? (assigned != nil) : selection.contains(seat.id)
        return Button {
            withAnimation(Animation.snappy.ifMotionAllowed(reduceMotion)) {
                if passengerMode { assignSeat(seat) } else { toggle(seat) }
            }
        } label: {
            RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                .fill(fill(seat, selected: selected))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .stroke(stroke(seat, selected: selected), lineWidth: 1)
                )
                .overlay(seatGlyph(seat, selected: selected, assigned: assigned))
                .frame(width: seatSize, height: seatSize)
        }
        .buttonStyle(.plain)
        .disabled(seat.isOccupied)
        .accessibilityLabel("Seat \(seat.id)\(seat.isPremium ? ", premium" : "")")
        .accessibilityValue(seat.isOccupied ? "Occupied" : selected ? "Selected" : "Available")
        .accessibilityHint(seat.isOccupied ? "" : "Double-tap to \(selected ? "deselect" : "select")")
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    @ViewBuilder private func seatGlyph(_ seat: Seat, selected: Bool, assigned: String?) -> some View {
        if let assigned {
            Text(assigned).textStyle(.labelSm600).foregroundStyle(content(seat, selected: selected))
        } else {
            Image(systemName: selected ? "checkmark" : (seat.isOccupied ? "xmark" : "chair"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(content(seat, selected: selected))
        }
    }

    private func toggle(_ seat: Seat) {
        guard !seat.isOccupied else { return }
        if selection.contains(seat.id) {
            selection.remove(seat.id)
        } else if selection.count < maxSelection {
            selection.insert(seat.id)
        }
    }

    private func assignedInitials(_ seatId: String) -> String? {
        guard let assignment else { return nil }
        for passenger in passengers where assignment.wrappedValue[passenger.id] == seatId {
            return passenger.initials
        }
        return nil
    }

    private func assignSeat(_ seat: Seat) {
        guard !seat.isOccupied, let assignment else { return }
        let active = activePassenger ?? passengers.first?.id
        guard let active else { return }
        var map = assignment.wrappedValue
        if map[active] == seat.id {
            map[active] = nil                                   // tap own seat → unassign
        } else {
            for (person, seatId) in map where seatId == seat.id { map[person] = nil }  // steal from others
            map[active] = seat.id
        }
        assignment.wrappedValue = map
        selection = Set(map.values)
        if let next = passengers.first(where: { map[$0.id] == nil }) { activePassenger = next.id }
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
    /// Assigns seats to specific travellers: tapping a seat gives it to the active
    /// passenger (shown by their initials) and advances to the next unassigned one.
    /// `assignment` maps passenger id → seat id; `selection` stays in sync.
    func passengers(_ people: [Passenger], assignment: Binding<[String: String]>) -> Self {
        copy { $0.passengers = people; $0.assignment = assignment }
    }
    /// Enables pinch-to-zoom (1×–2.5×) on the seat grid.
    func zoomable(_ on: Bool = true) -> Self { copy { $0.zoomable = on } }

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

/// Pinch-to-zoom (1×–2.5×) for the seat grid, applied only when enabled.
private struct PinchZoom: ViewModifier {
    let enabled: Bool
    @Binding var zoom: CGFloat
    @GestureState private var pinch: CGFloat = 1

    func body(content: Content) -> some View {
        if enabled {
            content
                .scaleEffect(zoom * pinch)
                .gesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in zoom = min(2.5, max(1, zoom * value.magnification)) }
                )
        } else {
            content
        }
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
