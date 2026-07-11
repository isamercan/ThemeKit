//
//  SeatMap.swift
//  ThemeKit
//
//  Organism. A generic, token-bound cabin seat picker. Composes the ``SeatCell``
//  atom (each seat) and the ``SeatLegend`` molecule, plus a passenger rail, a deck
//  selector and a seat-summary bar. Fully data-driven — no domain/DTO coupling.
//
//  Layout: declare a cabin by a column pattern (uniform) or per-row patterns
//  (staggered), or hand-build rows / multi-cabin sections. Every cell — seat or
//  `.space` gap — is an explicit unit; gaps are seat-width by default so columns
//  stay aligned. Note: with per-row-varying aisle positions, columns align by cell
//  position, not by letter (that ambiguity is inherent). Use `.aisleWidth` for a
//  tighter gap.
//

import SwiftUI
import ThemeKit

/// Where a ``SeatMap`` renders its legend relative to the cabin.
public enum LegendPlacement: Sendable {
    /// Above the cabin (below the passenger rail / deck selector).
    case top
    /// Below the cabin — the default.
    case bottom
    /// Never — suppresses a `legend()` set further up a modifier chain.
    case hidden
}

/// A generic, token-bound seat map.
///
/// ```swift
/// SeatMap(columns: "ABC DEF", rows: Array(1...30), selection: $picked) { id, row, col in
///     SeatInfo(available: !sold.contains(id),
///              price: row <= 3 ? 600 : 80,
///              tier: row == 14 ? .exit : row == 11 ? .extraLegroom : .standard)
/// }
/// .showsLabels().legend().showsSeatInfo().recommended(["11C"])
/// ```
public struct SeatMap: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let sections: [SeatSection]
    private let index: SeatIndex
    @Binding private var selection: Set<String>
    @State private var activePassenger: String?
    @State private var zoom: CGFloat = 1
    @State private var focusedSeat: String?
    @State private var activeFloor: Int?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var maxSelection: Int = .max
    private var seatSize: CGFloat = 44        // HIG minimum touch target
    private var showsLabels = false
    private var showsLegend = false
    private var showsFuselage = false
    private var showsInfo = false
    private var recommended: Set<String> = []
    private var currencyCode: String?
    private var seatEnabled: ((Seat) -> Bool)?
    private var passengers: [Passenger] = []
    private var assignment: Binding<[String: String]>?
    private var zoomable = false
    private var seatDisplay: SeatDisplay = .icon
    private var customContent: ((SeatContext) -> AnyView)?
    private var aisleWidthOverride: CGFloat?
    private var tierOverrides: [SeatTier: Color] = [:]
    private var accentOverride: SemanticColor?
    private var seatShape: SeatShape = .rounded
    private var legendPlacement: LegendPlacement = .bottom
    private var fuselageSurfaceKey: Theme.BackgroundColorKey = .bgSecondaryLight
    private var deckLabelProvider: ((Int) -> String)?
    private var zoomBinding: Binding<CGFloat>?
    private var sectionHeaderSlot: ((String) -> AnyView)?
    private var summarySlot: ((SeatSummary) -> AnyView)?

    private let gutter: CGFloat = 22
    private var passengerMode: Bool { !passengers.isEmpty && assignment != nil }
    private var gapWidth: CGFloat { aisleWidthOverride ?? seatSize }
    private var palette: SeatPalette { SeatPalette(tierOverrides) }
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    // MARK: Init (all delegate to `sections:` so the index is built once)

    /// Multi-cabin layout: each ``SeatSection`` gets a header and its own rows.
    public init(sections: [SeatSection], selection: Binding<Set<String>>) {
        self.sections = sections
        self.index = SeatIndex(sections)
        self._selection = selection
    }
    public init(rows: [[SeatSlot]], selection: Binding<Set<String>>) {
        self.init(sections: [SeatSection(nil, rows: rows)], selection: selection)
    }
    /// Declarative uniform layout: a column pattern applied across `rows`.
    public init(columns: String, rows: [Int], selection: Binding<Set<String>>,
                seat: (_ id: String, _ row: Int, _ column: String) -> SeatInfo = { _, _, _ in SeatInfo() }) {
        self.init(sections: [SeatSection(nil, rows: buildSeatRows(columns: columns, rows: rows, seat: seat))], selection: selection)
    }
    /// **Per-row** layout: each string in `rowPatterns` describes its own row shape.
    public init(rowPatterns: [String], startRow: Int = 1, selection: Binding<Set<String>>,
                seat: (_ id: String, _ row: Int, _ column: String) -> SeatInfo = { _, _, _ in SeatInfo() }) {
        self.init(sections: [SeatSection(nil, rows: buildSeatRows(rowPatterns: rowPatterns, startRow: startRow, seat: seat))], selection: selection)
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
            if passengerMode {
                PassengerRail(passengers: passengers, assignment: assignment ?? .constant([:]), active: $activePassenger, accent: accentOverride)
            }
            if index.floors.count > 1 {
                DeckSelector(floors: index.floors, active: $activeFloor, accent: accentOverride,
                             label: deckLabelProvider ?? { (floor: Int) in String(themeKit: "Deck \(floor)") })
            }
            if legendVisible, legendPlacement == .top { legendView }
            cabin.modifier(PinchZoom(enabled: zoomable, zoom: zoomBinding ?? $zoom))
            if legendVisible, legendPlacement == .bottom { legendView }
            if showsInfo || summarySlot != nil { summaryView }
        }
    }

    private var legendVisible: Bool { showsLegend && legendPlacement != .hidden }

    /// The legend inherits the map's palette and seat shape so the key matches.
    private var legendView: some View {
        SeatLegend(tiers: index.tiers, palette: palette).swatchShape(seatShape)
    }

    /// The `summaryBar { … }` slot when provided, else the built-in bar.
    @ViewBuilder private var summaryView: some View {
        let focused = focusedSeat.flatMap { index.byId[$0] }
        let position = focusedSeat.flatMap { index.positions[$0] }
        if let summarySlot {
            summarySlot(SeatSummary(focusedSeat: focused,
                                    isWindow: position?.window, isAisle: position?.aisle,
                                    selectedCount: selection.count, totalPrice: totalPrice,
                                    hasPrices: index.hasPrices, currencyCode: resolvedCurrency))
        } else {
            SeatSummaryBar(seat: focused, position: position,
                           palette: palette, selectedCount: selection.count,
                           totalPrice: totalPrice, hasPrices: index.hasPrices, currencyCode: resolvedCurrency)
        }
    }

    // MARK: Cabin (sections + rows, optional fuselage)

    private var cabin: some View {
        // Leading-aligned so every row's number gutter and column A share an x —
        // rows of different widths (per-row layouts) stay aligned, not centered.
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if showsLabels { columnHeader }
            ForEach(Array(visibleSections.enumerated()), id: \.offset) { _, section in
                if let title = section.title {
                    if let sectionHeaderSlot { sectionHeaderSlot(title) } else { defaultSectionHeader(title) }
                }
                sectionRows(section)
            }
        }
        .dynamicTypeClamp()
        .padding(showsFuselage ? EdgeInsets(top: 46, leading: 18, bottom: 26, trailing: 18) : EdgeInsets())
        .background { if showsFuselage { FuselageView(surfaceKey: fuselageSurfaceKey) } }
    }

    private func defaultSectionHeader(_ title: String) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            Text(title.uppercased()).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
        }
        .padding(.top, Theme.SpacingKey.xs.value)
    }

    private func sectionRows(_ section: SeatSection) -> some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.xs.value)) {
            ForEach(Array(section.rows.enumerated()), id: \.offset) { i, row in
                if isExitRow(row), i == 0 || !isExitRow(section.rows[i - 1]) { ExitBand() }
                rowView(row)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if showsLabels { Color.clear.frame(width: gutter) }
            ForEach(Array(index.templateRow.enumerated()), id: \.offset) { _, slot in
                switch slot {
                case .space: Color.clear.frame(width: gapWidth)
                case .seat(let seat):
                    Text(columnLetter(seat.id)).textStyle(.overline500)
                        .foregroundStyle(theme.text(.textTertiary)).frame(width: seatSize)
                }
            }
        }
    }

    private func rowView(_ row: [SeatSlot]) -> some View {
        HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if showsLabels {
                Text(rowNumber(row)).textStyle(.overline500)
                    .foregroundStyle(theme.text(.textTertiary)).frame(width: gutter)
            }
            ForEach(Array(row.enumerated()), id: \.offset) { _, slot in
                switch slot {
                case .space: Color.clear.frame(width: gapWidth, height: seatSize)
                case .seat(let seat): seatCell(seat)
                }
            }
        }
    }

    private func seatCell(_ seat: Seat) -> some View {
        let assigned = passengerMode ? assignedInitials(seat.id) : nil
        let selected = passengerMode ? (assigned != nil) : selection.contains(seat.id)
        return SeatCell(seat, size: seatSize, isSelected: selected, isSelectable: isSelectable(seat),
                        isRecommended: recommended.contains(seat.id), assignedInitials: assigned,
                        display: seatDisplay, palette: palette, customContent: customContent,
                        currencyCode: resolvedCurrency, shape: seatShape, action: {
            focusedSeat = seat.id
            withAnimation(Animation.snappy.ifMotionAllowed(reduceMotion)) {
                if passengerMode { assignSeat(seat) } else { toggle(seat) }
            }
        })
    }

    // MARK: Selection

    private func toggle(_ seat: Seat) {
        guard isSelectable(seat) else { return }
        if selection.contains(seat.id) {
            selection.remove(seat.id)
        } else if selection.count < maxSelection {
            selection.insert(seat.id)
        }
    }

    private func isSelectable(_ seat: Seat) -> Bool { !seat.isOccupied && (seatEnabled?(seat) ?? true) }

    private func assignedInitials(_ seatId: String) -> String? {
        guard let assignment else { return nil }
        for passenger in passengers where assignment.wrappedValue[passenger.id] == seatId { return passenger.initials }
        return nil
    }

    private func assignSeat(_ seat: Seat) {
        guard isSelectable(seat), let assignment else { return }
        let active = activePassenger ?? passengers.first?.id
        guard let active else { return }
        var map = assignment.wrappedValue
        if map[active] == seat.id {
            map[active] = nil
        } else {
            for (person, seatId) in map where seatId == seat.id { map[person] = nil }
            map[active] = seat.id
        }
        assignment.wrappedValue = map
        selection = Set(map.values)
        if let next = passengers.first(where: { map[$0.id] == nil }) { activePassenger = next.id }
    }

    // MARK: Decks + derived helpers

    private func rowFloor(_ row: [SeatSlot]) -> Int? {
        for slot in row { if case .seat(let s) = slot, let f = s.floor { return f } }
        return nil
    }
    private var visibleSections: [SeatSection] {
        guard index.floors.count > 1 else { return sections }
        let active = activeFloor ?? index.floors.first
        return sections.map { section in
            SeatSection(section.title, rows: section.rows.filter { rowFloor($0) == nil || rowFloor($0) == active })
        }
    }
    private var totalPrice: Decimal {
        selection.reduce(Decimal(0)) { $0 + (index.byId[$1]?.price ?? 0) }
    }
    private func isExitRow(_ row: [SeatSlot]) -> Bool {
        row.contains { if case .seat(let s) = $0 { return s.isExitRow }; return false }
    }
    private func columnLetter(_ id: String) -> String { String(id.drop { $0.isNumber }) }
    private func rowNumber(_ row: [SeatSlot]) -> String {
        for slot in row { if case .seat(let s) = slot { return String(s.id.prefix { $0.isNumber }) } }
        return ""
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
    /// Appends a fare-tier legend (only the tiers actually present are shown).
    func legend(_ on: Bool = true) -> Self { copy { $0.showsLegend = on } }
    /// Frames the cabin in an aircraft fuselage (nose, tapered body, exit-door bands).
    func fuselage(_ on: Bool = true) -> Self { copy { $0.showsFuselage = on } }
    /// Shows a live detail + running-total bar for the last-tapped seat.
    func showsSeatInfo(_ on: Bool = true) -> Self { copy { $0.showsInfo = on } }
    /// Highlights recommended seats with a star.
    func recommended(_ ids: Set<String>) -> Self { copy { $0.recommended = ids } }
    /// Currency code for per-seat and total pricing. When unset it resolves from
    /// the environment: `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// A custom availability predicate — return false to block a seat (e.g. exit rows
    /// for a passenger with an infant). Blocked seats render dimmed and untappable.
    func seatEnabled(_ predicate: ((Seat) -> Bool)?) -> Self { copy { $0.seatEnabled = predicate } }
    /// Assigns seats to specific travellers: tapping a seat gives it to the active
    /// passenger (shown by their initials) and advances to the next unassigned one.
    func passengers(_ people: [Passenger], assignment: Binding<[String: String]>) -> Self {
        copy { $0.passengers = people; $0.assignment = assignment }
    }
    /// Enables pinch-to-zoom (1×–2.5×) on the seat grid.
    func zoomable(_ on: Bool = true) -> Self { copy { $0.zoomable = on } }
    /// How seats are labelled: `.icon` · `.number` · `.initials` · `.initialsAndNumber`.
    func seatDisplay(_ mode: SeatDisplay) -> Self { copy { $0.seatDisplay = mode } }
    /// Fully custom seat content — render your own view per seat via ``SeatContext``.
    /// The tier/state fill still applies underneath; you draw what goes on top.
    func seatLabel<V: View>(@ViewBuilder _ content: @escaping (SeatContext) -> V) -> Self {
        copy { $0.customContent = { AnyView(content($0)) } }
    }
    /// Width of a `.space` (gap) cell. By default a gap is as wide as a seat so every
    /// column stays aligned; pass a smaller value for a tighter aisle look.
    func aisleWidth(_ width: CGFloat) -> Self { copy { $0.aisleWidthOverride = max(0, width) } }
    /// Override fare-tier accent colours with semantic tokens — brand the tiers
    /// with your own palette. Each tier uses the token's base shade, matching
    /// the palette's own tier defaults.
    func tierColors(_ overrides: [SeatTier: SemanticColor]) -> Self {
        copy { $0.tierOverrides = overrides.mapValues(\.base) }
    }
    /// Accent for the passenger rail's and deck selector's **active** pill — the
    /// token's `.solid` shade fills the pill and `.onSolid` colours its text.
    /// Pass `nil` to restore the theme's hero default.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentOverride = color } }
    /// Raw-color tier overrides (back-compat); prefer the token-bound overload.
    /// Disfavored so member-shorthand literals like `[.extraLegroom: .purple]` —
    /// valid as both `Color` and `SemanticColor` values — resolve to the token
    /// overload instead of being ambiguous.
    @_disfavoredOverload
    @available(*, deprecated, message: "Use tierColors(_: [SeatTier: SemanticColor]) — the token-bound overload.")
    func tierColors(_ overrides: [SeatTier: Color]) -> Self { copy { $0.tierOverrides = overrides } }

    /// Token-stepped seat size (compact 36 · regular 44 · large 52 · xl 60).
    /// Unlike the raw overload, `.compact` deliberately drops below the 44 pt
    /// touch minimum — reserve it for read-only overview grids.
    func seatSize(_ ramp: SeatSizeRamp) -> Self { copy { $0.seatSize = ramp.points } }
    /// Token-fed aisle width — the gap cells take the spacing token's value.
    func aisleWidth(_ key: Theme.SpacingKey) -> Self { copy { $0.aisleWidthOverride = key.value } }
    /// The silhouette every seat is drawn with (`.rounded` default · `.circle` ·
    /// `.seatback`). Forwarded to the legend so its swatches match.
    func seatShape(_ shape: SeatShape) -> Self { copy { $0.seatShape = shape } }
    /// Replaces the built-in cabin-section header — receives the section title.
    func sectionHeader(@ViewBuilder _ content: @escaping (String) -> some View) -> Self {
        copy { $0.sectionHeaderSlot = { AnyView(content($0)) } }
    }
    /// Replaces the built-in seat-summary bar — receives a live ``SeatSummary``
    /// (focused seat, selection count, running total). Providing the slot shows
    /// the bar even without `showsSeatInfo()`.
    func summaryBar(@ViewBuilder _ content: @escaping (SeatSummary) -> some View) -> Self {
        copy { $0.summarySlot = { AnyView(content($0)) } }
    }
    /// Where the legend renders relative to the cabin: `.top` · `.bottom`
    /// (default) · `.hidden` (suppresses a `legend()` set upstream).
    func legendPlacement(_ placement: LegendPlacement) -> Self { copy { $0.legendPlacement = placement } }
    /// Surface fill of the fuselage frame (default `.bgSecondaryLight`).
    func fuselageSurface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.fuselageSurfaceKey = key } }
    /// Custom deck-pill titles for multi-deck cabins, e.g. `{ $0 == 1 ? "Main" : "Upper" }`.
    func deckLabel(_ label: @escaping (Int) -> String) -> Self { copy { $0.deckLabelProvider = label } }
    /// Pinch-to-zoom with the zoom scale exposed through the caller's binding —
    /// drive it from zoom buttons, or persist it. Pass `nil` to keep the
    /// internal state (same as ``zoomable(_:)``).
    func zoomable(_ on: Bool = true, zoom: Binding<CGFloat>?) -> Self {
        copy { $0.zoomable = on; $0.zoomBinding = zoom }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - Precomputed index (built once per data set, O(1) lookups at render)

/// One-pass digest of a cabin's seats — ids, tiers, floors, window/aisle positions
/// and the widest row — so the organism never re-scans on every render.
struct SeatIndex {
    let byId: [String: Seat]
    let tiers: [SeatTier]
    let floors: [Int]
    let positions: [String: (window: Bool, aisle: Bool)]
    let hasPrices: Bool
    let templateRow: [SeatSlot]

    init(_ sections: [SeatSection]) {
        var byId: [String: Seat] = [:]
        var positions: [String: (window: Bool, aisle: Bool)] = [:]
        var floorSet = Set<Int>()
        var tierSet = Set<SeatTier>([.standard])
        var prices = false
        var template: [SeatSlot] = []
        for section in sections {
            for row in section.rows {
                if row.count > template.count { template = row }
                let seatIdx = row.indices.filter { if case .seat = row[$0] { return true }; return false }
                for (i, slot) in row.enumerated() {
                    guard case .seat(let s) = slot else { continue }
                    byId[s.id] = s
                    tierSet.insert(s.tier)
                    if let f = s.floor { floorSet.insert(f) }
                    if s.price != nil { prices = true }
                    let isWindow = i == seatIdx.first || i == seatIdx.last
                    let leftAisle = i > 0 && row[i - 1] == .space
                    let rightAisle = i < row.count - 1 && row[i + 1] == .space
                    positions[s.id] = (isWindow, leftAisle || rightAisle)
                }
            }
        }
        self.byId = byId
        self.positions = positions
        self.floors = floorSet.sorted()
        self.tiers = SeatTier.allCases.filter(tierSet.contains).sorted { $0.rank < $1.rank }
        self.hasPrices = prices
        self.templateRow = template
    }
}

// MARK: - Composed molecules (passenger rail · deck selector · summary bar · exit band)

private struct PassengerRail: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    let passengers: [Passenger]
    let assignment: Binding<[String: String]>
    @Binding var active: String?
    let accent: SemanticColor?

    private var activeFill: Color { accent?.solid ?? theme.foreground(.fgHero) }
    private var activeContent: Color { accent?.onSolid ?? theme.text(.textSecondaryInverse) }

    var body: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            ForEach(passengers) { p in
                let isActive = (active ?? passengers.first?.id) == p.id
                Button { active = p.id } label: {
                    VStack(spacing: 2) {
                        Text(p.initials).textStyle(.labelSm600)
                        Text(assignment.wrappedValue[p.id] ?? "—").textStyle(.overline400)
                    }
                    .foregroundStyle(isActive ? activeContent : theme.text(.textPrimary))
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(isActive ? activeFill : theme.background(.bgSecondaryLight), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Passenger \(p.initials), seat \(assignment.wrappedValue[p.id] ?? String(themeKit: "unassigned"))"))
            }
        }
    }
}

private struct DeckSelector: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    let floors: [Int]
    @Binding var active: Int?
    let accent: SemanticColor?
    /// Pill title per floor — `SeatMap.deckLabel(_:)` or the localized default.
    let label: (Int) -> String

    private var activeFill: Color { accent?.solid ?? theme.foreground(.fgHero) }
    private var activeContent: Color { accent?.onSolid ?? theme.text(.textSecondaryInverse) }

    var body: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            ForEach(floors, id: \.self) { floor in
                let isActive = (active ?? floors.first) == floor
                Button { active = floor } label: {
                    Text(label(floor)).textStyle(.labelSm600)
                        .foregroundStyle(isActive ? activeContent : theme.text(.textPrimary))
                        .padding(.horizontal, 14).padding(.vertical, 6)
                        .background(isActive ? activeFill : theme.background(.bgSecondaryLight), in: Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(label(floor))
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
    }
}

private struct SeatSummaryBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    let seat: Seat?
    let position: (window: Bool, aisle: Bool)?
    let palette: SeatPalette
    let selectedCount: Int
    let totalPrice: Decimal
    let hasPrices: Bool
    let currencyCode: String

    var body: some View {
        HStack(alignment: .center) {
            if let seat {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        Text(String(themeKit: "Seat \(seat.id)")).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
                        tierChip(seat.tier)
                    }
                    Text(featureText(seat)).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
            } else {
                Text(String(themeKit: "Select a seat to see its details")).textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            VStack(alignment: .trailing, spacing: 2) {
                if hasPrices {
                    Text(totalPrice.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale)))
                        .textStyle(.labelBase700).foregroundStyle(theme.foreground(.fgHero))
                }
                Text(selectedCount == 1 ? String(themeKit: "1 seat") : String(themeKit: "\(selectedCount) seats")).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
            }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
        .background(theme.background(.bgBase), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    private func tierChip(_ tier: SeatTier) -> some View {
        let c = palette.colors(for: tier, theme: theme)
        return Text(tier.label).textStyle(.overline500)
            .foregroundStyle(tier == .standard ? theme.text(.textSecondary) : c.stroke)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(c.fill, in: Capsule())
    }

    private func featureText(_ seat: Seat) -> String {
        var parts: [String] = []
        if let pos = position { parts.append(pos.window ? String(themeKit: "Window") : pos.aisle ? String(themeKit: "Aisle") : String(themeKit: "Middle")) }
        if seat.isExtraLegroom { parts.append(String(themeKit: "Extra legroom")) }
        if seat.isExitRow { parts.append(String(themeKit: "Exit row")) }
        if let floor = seat.floor { parts.append(String(themeKit: "Deck \(floor)")) }
        if let price = seat.price { parts.append(price.formatted(.currency(code: currencyCode).precision(.fractionLength(0)).locale(locale))) }
        return parts.joined(separator: " · ")
    }
}

private struct ExitBand: View {
    @Environment(\.theme) private var theme
    var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            door; line
            Text(String(themeKit: "EXIT")).textStyle(.overline500).foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
            line; door
        }
        .padding(.vertical, 2)
    }
    private var door: some View {
        Image(systemName: "figure.walk.departure").font(.system(size: 11, weight: .semibold))
            .foregroundStyle(theme.foreground(.systemcolorsFgSuccess))
    }
    private var line: some View {
        Rectangle().fill(theme.foreground(.systemcolorsFgSuccess).opacity(0.4)).frame(height: 1)
    }
}

/// The aircraft body used by `SeatMap.fuselage()` — a tapered nose + cockpit hint.
/// `surfaceKey` comes from `SeatMap.fuselageSurface(_:)` (default `.bgSecondaryLight`).
private struct FuselageView: View {
    @Environment(\.theme) private var theme
    var surfaceKey: Theme.BackgroundColorKey = .bgSecondaryLight
    var body: some View {
        FuselageShape()
            .fill(theme.background(surfaceKey))
            .overlay(FuselageShape().stroke(theme.border(.borderPrimary), lineWidth: 1.5))
            .overlay(alignment: .top) {
                Capsule().fill(theme.border(.borderPrimary)).frame(width: 34, height: 4).padding(.top, 14)
            }
    }
}

private struct FuselageShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let nose = min(rect.width * 0.5, 54)
        let r: CGFloat = 22
        p.move(to: CGPoint(x: rect.minX, y: rect.maxY - r))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + nose))
        p.addQuadCurve(to: CGPoint(x: rect.midX, y: rect.minY), control: CGPoint(x: rect.minX, y: rect.minY))
        p.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.minY + nose), control: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - r))
        p.addArc(center: CGPoint(x: rect.maxX - r, y: rect.maxY - r), radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + r, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + r, y: rect.maxY - r), radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
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
        @State private var accentPicked: Set<String> = []
        @State private var shapePicked: Set<String> = ["10C"]
        @State private var zoomLevel: CGFloat = 1
        @State private var assignment: [String: String] = [:]
        private let sold: Set<String> = ["12B", "13E", "16A"]
        var body: some View {
            ScrollView {
                SeatMap(columns: "ABC DEF", rows: Array(11...18), selection: $picked) { id, row, _ in
                    SeatInfo(available: !sold.contains(id),
                             price: row == 14 ? 220 : row == 11 ? 150 : 80,
                             tier: row == 14 ? .exit : row == 11 ? .extraLegroom : .standard)
                }
                .showsLabels().legend().showsSeatInfo()
                .recommended(["11C"]).maxSelection(3).currency("USD")
                .tierColors([.extraLegroom: .purple]).padding()

                // Accent override — passenger rail + deck selector pick up the token.
                // Custom deck-pill titles via `.deckLabel`.
                SeatMap(columns: "AB CD", rows: Array(1...3), selection: $accentPicked) { _, row, _ in
                    SeatInfo(floor: row <= 2 ? 1 : 2)
                }
                .passengers([Passenger(id: "p1", initials: "AB"), Passenger(id: "p2", initials: "CD")],
                            assignment: $assignment)
                .accent(.accent)
                .deckLabel { $0 == 1 ? String(themeKit: "Main deck") : String(themeKit: "Upper deck") }
                .padding()

                // Full-flex axes: seatback silhouette, large ramp size, tight
                // token aisle, legend on top, custom section header + summary bar.
                SeatMap(sections: [SeatSection("Business", columns: "AB CD", rows: [1, 2]),
                                   SeatSection("Economy", columns: "ABC DEF", rows: Array(10...12))],
                        selection: $shapePicked)
                    .seatShape(.seatback)
                    .seatSize(.large)
                    .aisleWidth(.lg)
                    .legend().legendPlacement(.top)
                    .fuselage().fuselageSurface(.bgBase)
                    .sectionHeader { title in
                        Badge(title).badgeStyle(.info).size(.small)
                    }
                    .summaryBar { summary in
                        HStack {
                            Text(summary.focusedSeat.map { String(themeKit: "Seat \($0.id)") }
                                    ?? String(themeKit: "Pick a seat"))
                                .textStyle(.labelBase700)
                            Spacer()
                            Text(String(themeKit: "\(summary.selectedCount) selected")).textStyle(.bodySm400)
                        }
                        .padding(Theme.SpacingKey.md.value)
                        .background(Theme.shared.background(.bgSecondaryLight),
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
                    }
                    .padding()

                // Controlled zoom binding — the slider drives the same scale as the pinch.
                VStack {
                    Slider(value: $zoomLevel, in: 1...2.5)
                    SeatMap(columns: "AB", rows: Array(1...2), selection: $shapePicked)
                        .seatShape(.circle)
                        .zoomable(true, zoom: $zoomLevel)
                }
                .padding()
            }
        }
    }
    return Demo()
}
