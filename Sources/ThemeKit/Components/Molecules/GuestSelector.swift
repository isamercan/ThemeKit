//
//  GuestSelector.swift
//  ThemeKit
//
//  Rooms & guests picker (adults / children / infants) composed from QuantityStepper.
//  Token-bound; a single `GuestSelection` binding carries the counts and a summary
//  string for the trigger field. Default labels are English — override per modifier.
//

import SwiftUI

/// The value a ``GuestSelector`` edits.
public struct GuestSelection: Equatable, Sendable {
    public var rooms: Int
    public var adults: Int
    public var children: Int
    public var infants: Int

    public init(rooms: Int = 1, adults: Int = 2, children: Int = 0, infants: Int = 0) {
        self.rooms = rooms
        self.adults = adults
        self.children = children
        self.infants = infants
    }

    /// A compact readout for a trigger field, e.g. `"1 room · 2 adults · 1 child"`.
    public var summary: String {
        func part(_ n: Int, _ singular: String, _ plural: String) -> String? {
            n > 0 ? "\(n) \(n == 1 ? singular : plural)" : nil
        }
        return [
            part(rooms, "room", "rooms"),
            part(adults, "adult", "adults"),
            part(children, "child", "children"),
            part(infants, "infant", "infants"),
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct GuestRow: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let keyPath: WritableKeyPath<GuestSelection, Int>
    let range: ClosedRange<Int>
    let visible: Bool
}

/// A token-bound rooms & guests picker.
///
/// ```swift
/// GuestSelector(selection: $guests).showsRooms(false)   // e.g. a flight passenger picker
/// ```
public struct GuestSelector: View {
    @Environment(\.theme) private var theme
    @Binding private var selection: GuestSelection

    // Appearance/state — mutated only through the modifiers below (R2).
    private var showsRooms: Bool = true
    private var showsInfants: Bool = true
    private var adultRange: ClosedRange<Int> = 1...16
    private var childRange: ClosedRange<Int> = 0...10
    private var infantRange: ClosedRange<Int> = 0...6
    private var roomRange: ClosedRange<Int> = 1...8

    public init(selection: Binding<GuestSelection>) {   // R1 — binding
        self._selection = selection
    }

    private var rows: [GuestRow] {
        [
            GuestRow(title: "Rooms", subtitle: nil, keyPath: \.rooms, range: roomRange, visible: showsRooms),
            GuestRow(title: "Adults", subtitle: "Age 13+", keyPath: \.adults, range: adultRange, visible: true),
            GuestRow(title: "Children", subtitle: "Age 2–12", keyPath: \.children, range: childRange, visible: true),
            GuestRow(title: "Infants", subtitle: "Under 2", keyPath: \.infants, range: infantRange, visible: showsInfants),
        ].filter(\.visible)
    }

    public var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                if index > 0 { Divider().overlay(theme.border(.borderPrimary)) }
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(row.title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                        if let subtitle = row.subtitle {
                            Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                        }
                    }
                    Spacer()
                    QuantityStepper(value: binding(for: row.keyPath), range: row.range)
                }
                .padding(.vertical, Theme.SpacingKey.sm.value)
            }
        }
    }

    private func binding(for keyPath: WritableKeyPath<GuestSelection, Int>) -> Binding<Int> {
        Binding(get: { selection[keyPath: keyPath] }, set: { selection[keyPath: keyPath] = $0 })
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension GuestSelector {
    /// Shows the Rooms row (default true — hide it for flight passenger pickers).
    func showsRooms(_ on: Bool) -> Self { copy { $0.showsRooms = on } }
    /// Shows the Infants row (default true).
    func showsInfants(_ on: Bool) -> Self { copy { $0.showsInfants = on } }
    /// Allowed adult count.
    func adultRange(_ range: ClosedRange<Int>) -> Self { copy { $0.adultRange = range } }
    /// Allowed children count.
    func childRange(_ range: ClosedRange<Int>) -> Self { copy { $0.childRange = range } }
    /// Allowed infant count.
    func infantRange(_ range: ClosedRange<Int>) -> Self { copy { $0.infantRange = range } }
    /// Allowed room count.
    func roomRange(_ range: ClosedRange<Int>) -> Self { copy { $0.roomRange = range } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var guests = GuestSelection(rooms: 1, adults: 2, children: 1)
        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(guests.summary).textStyle(.bodyBase400)
                GuestSelector(selection: $guests)
            }
            .padding()
        }
    }
    return Demo()
}
