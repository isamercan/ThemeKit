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
public struct GuestSelection: Equatable, Sendable, Codable {
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

    /// Total guests (adults + children + infants), used for cabin-capacity caps.
    public var guestCount: Int { adults + children + infants }

    /// A compact readout for a trigger field, e.g. `"1 room · 2 adults · 1 child"`.
    public var summary: String {
        func part(_ n: Int, _ singular: String, _ plural: String) -> String? {
            n > 0 ? "\(n) \(n == 1 ? singular : plural)" : nil
        }
        return [
            part(rooms, String(themeKit: "room"), String(themeKit: "rooms")),
            part(adults, String(themeKit: "adult"), String(themeKit: "adults")),
            part(children, String(themeKit: "child"), String(themeKit: "children")),
            part(infants, String(themeKit: "infant"), String(themeKit: "infants")),
        ].compactMap { $0 }.joined(separator: " · ")
    }
}

private struct GuestRow: Identifiable {
    let id: String                         // stable key (no per-access UUID churn)
    let title: String                      // resolved via String(themeKit:) — Bundle.module lookup
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
    @Environment(\.componentDensity) private var density
    @Binding private var selection: GuestSelection

    // Appearance/state — mutated only through the modifiers below (R2).
    private var showsRooms: Bool = true
    private var showsInfants: Bool = true
    private var adultRange: ClosedRange<Int> = 1...16
    private var childRange: ClosedRange<Int> = 0...10
    private var infantRange: ClosedRange<Int> = 0...6
    private var roomRange: ClosedRange<Int> = 1...8
    private var maxTotal: Int?
    private var onChangeHandler: ((GuestSelection) -> Void)?

    public init(selection: Binding<GuestSelection>) {   // R1 — binding
        self._selection = selection
    }

    private var rows: [GuestRow] {
        [
            GuestRow(id: "rooms", title: String(themeKit: "Rooms"), subtitle: nil, keyPath: \.rooms, range: roomRange, visible: showsRooms),
            GuestRow(id: "adults", title: String(themeKit: "Adults"), subtitle: String(themeKit: "Age 13+"), keyPath: \.adults, range: adultRange, visible: true),
            GuestRow(id: "children", title: String(themeKit: "Children"), subtitle: String(themeKit: "Age 2–12"), keyPath: \.children, range: childRange, visible: true),
            GuestRow(id: "infants", title: String(themeKit: "Infants"), subtitle: String(themeKit: "Under 2"), keyPath: \.infants, range: infantRange, visible: showsInfants),
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
                    QuantityStepper(value: binding(for: row.keyPath), range: effectiveRange(row))
                }
                .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
                // Group the row so VoiceOver announces the stepper's +/- buttons
                // in the context of "Adults" / "Children" / etc.
                .accessibilityElement(children: .contain)
                .accessibilityLabel(row.title)
            }
        }
        .onChangeCompat(of: selection) { _, new in onChangeHandler?(new) }
    }

    private func binding(for keyPath: WritableKeyPath<GuestSelection, Int>) -> Binding<Int> {
        Binding(get: { selection[keyPath: keyPath] }, set: { selection[keyPath: keyPath] = $0 })
    }

    /// Caps the guest rows so their combined count never exceeds `maxTotal`
    /// (rooms are unaffected). The upper bound shrinks as other rows fill up.
    private func effectiveRange(_ row: GuestRow) -> ClosedRange<Int> {
        guard let maxTotal, row.keyPath != \GuestSelection.rooms else { return row.range }
        let remaining = max(0, maxTotal - selection.guestCount)
        let current = selection[keyPath: row.keyPath]
        return row.range.lowerBound...Self.cappedUpperBound(range: row.range, current: current, remaining: remaining)
    }

    /// The effective upper bound for a guest row given the remaining cabin capacity
    /// (pure; unit-tested).
    static func cappedUpperBound(range: ClosedRange<Int>, current: Int, remaining: Int) -> Int {
        max(range.lowerBound, min(range.upperBound, current + remaining))
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
    /// Caps the combined guest count (adults + children + infants) — e.g. a cabin capacity.
    func maxTotal(_ count: Int) -> Self { copy { $0.maxTotal = count } }
    /// Called whenever the selection changes.
    func onChange(_ handler: @escaping (GuestSelection) -> Void) -> Self { copy { $0.onChangeHandler = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var guests = GuestSelection(rooms: 1, adults: 2, children: 1)
        @State var passengers = GuestSelection(adults: 1)
        var body: some View {
            PreviewMatrix("GuestSelector") {
                PreviewCase("Rooms + guests · live summary") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(guests.summary).textStyle(.bodyBase400)
                        GuestSelector(selection: $guests)
                    }
                }
                PreviewCase("Passengers (no rooms · max 4 guests)") {
                    GuestSelector(selection: $passengers).showsRooms(false).maxTotal(4)
                }
            }
        }
    }
    return Demo()
}
