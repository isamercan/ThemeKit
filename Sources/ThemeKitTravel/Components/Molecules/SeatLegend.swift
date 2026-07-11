//
//  SeatLegend.swift
//  ThemeKit
//
//  Molecule. A key for a ``SeatMap`` — the fare tiers present, plus Selected and
//  Occupied — wrapping to rows. Tier *and* selected/occupied colours come from a
//  ``SeatPalette`` so it matches whatever the map (or a brand override) uses.
//  Configuration flows through chainable copy-on-write modifiers (R2); the
//  original init parameters remain for source compatibility.
//

import SwiftUI
import ThemeKit

/// How a ``SeatLegend`` lays out its entries.
public enum SeatLegendOrientation: Sendable {
    /// Wraps into rows of `perRow(_:)` entries — the default.
    case rows
    /// One entry per line.
    case vertical
    /// A single unwrapped row.
    case inline
}

public struct SeatLegend: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    // Appearance/state — mutated only through the modifiers below (R2). The
    // init params are kept as a convenience/back-compat surface.
    private var tiers: [SeatTier]
    private var palette: SeatPalette
    private var perRow: Int
    private var showsSelected = true
    private var showsOccupied = true
    private var extraEntries: [(label: String, color: SemanticColor)] = []
    private var swatchShape: SeatShape = .rounded
    private var swatchRamp: SeatSizeRamp?
    private var orientation: SeatLegendOrientation = .rows

    public init(tiers: [SeatTier] = [.standard], palette: SeatPalette = .default, perRow: Int = 3) {
        self.tiers = tiers
        self.palette = palette
        self.perRow = max(1, perRow)
    }

    private struct Entry: Identifiable { let fill: Color; let border: Color; let label: String; var id: String { label } }

    private var entries: [Entry] {
        var e = tiers.map { tier -> Entry in
            let c = palette.colors(for: tier, theme: theme)
            return Entry(fill: c.fill, border: c.stroke, label: tier.label)
        }
        e += extraEntries.map { Entry(fill: $0.color.bg, border: $0.color.base, label: $0.label) }
        if showsSelected {
            let selected = palette.selectedColors(theme: theme)
            e.append(Entry(fill: selected.fill, border: selected.stroke, label: String(themeKit: "Selected")))
        }
        if showsOccupied {
            let occupied = palette.occupiedColors(theme: theme)
            e.append(Entry(fill: occupied.fill, border: occupied.stroke, label: String(themeKit: "Occupied")))
        }
        return e
    }

    public var body: some View {
        let items = entries
        switch orientation {
        case .rows:
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                ForEach(Array(stride(from: 0, to: items.count, by: perRow)), id: \.self) { start in
                    HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                        ForEach(items[start..<min(start + perRow, items.count)]) { swatch($0) }
                        Spacer(minLength: 0)
                    }
                }
            }
        case .vertical:
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                ForEach(items) { swatch($0) }
            }
        case .inline:
            HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                ForEach(items) { swatch($0) }
            }
        }
    }

    // Legend swatches are keys, not touch targets — the ramp maps to a scaled-
    // down side so `.swatchSize(.large)` tracks a larger map without dwarfing
    // the labels.
    private var swatchSide: CGFloat {
        switch swatchRamp {
        case nil, .regular: return 14
        case .compact: return 12
        case .large: return 17
        case .xl: return 20
        }
    }

    private func swatch(_ entry: Entry) -> some View {
        let shape = swatchShape.anyShape(cornerRadius: 4)
        return HStack(spacing: Theme.SpacingKey.xs.value) {
            shape.fill(entry.fill)
                .overlay(shape.stroke(entry.border, lineWidth: 1))
                .frame(width: swatchSide, height: swatchSide)
            Text(entry.label).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .combine)
    }

    /// Backward-compatible: adds a "Premium econ." key to the default legend.
    public func showsPremium(_ on: Bool = true) -> Self {
        var c = self
        if on, !c.tiers.contains(.premium) { c.tiers.append(.premium) }
        return c
    }
}

// MARK: - Modifiers (R2 — copy-on-write)

public extension SeatLegend {
    /// The fare tiers to key (replaces the current set).
    func tiers(_ tiers: [SeatTier]) -> Self { copy { $0.tiers = tiers } }
    /// The palette the swatches resolve their colours from — pass the same one
    /// the map uses so the key always matches.
    func palette(_ palette: SeatPalette) -> Self { copy { $0.palette = palette } }
    /// Entries per row in the default `.rows` orientation.
    func perRow(_ count: Int) -> Self { copy { $0.perRow = max(1, count) } }
    /// Whether the synthetic "Selected" entry is appended (default `true`).
    func showsSelected(_ on: Bool = true) -> Self { copy { $0.showsSelected = on } }
    /// Whether the synthetic "Occupied" entry is appended (default `true`).
    func showsOccupied(_ on: Bool = true) -> Self { copy { $0.showsOccupied = on } }
    /// Appends a custom key (e.g. "Bassinet") — the swatch fills with the
    /// token's soft background and strokes with its base shade, matching how
    /// tier overrides resolve.
    func entry(_ label: String, color: SemanticColor) -> Self {
        copy { $0.extraEntries.append((label: label, color: color)) }
    }
    /// The swatch silhouette — pass the map's ``SeatShape`` so the key matches
    /// the seats (``SeatMap`` forwards its own automatically).
    func swatchShape(_ shape: SeatShape) -> Self { copy { $0.swatchShape = shape } }
    /// Steps the swatch size alongside a map using the same ``SeatSizeRamp``.
    func swatchSize(_ ramp: SeatSizeRamp) -> Self { copy { $0.swatchRamp = ramp } }
    /// Layout direction of the entries: `.rows` (wrap, default) · `.vertical` · `.inline`.
    func orientation(_ orientation: SeatLegendOrientation) -> Self { copy { $0.orientation = orientation } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("SeatLegend") {
        PreviewCase("Economy tiers") { SeatLegend(tiers: [.standard, .extraLegroom, .exit]) }
        PreviewCase("All cabins") { SeatLegend(tiers: [.standard, .premium, .business, .first]) }
        PreviewCase("Default + premium") { SeatLegend().showsPremium() }
        PreviewCase("Accent selected/occupied") {
            SeatLegend(tiers: [.standard, .exit],
                       palette: SeatPalette().selected(.accent).occupied(.warning))
        }
        PreviewCase("Chained config (R2)") {
            SeatLegend().tiers([.standard, .business]).perRow(2)
                .palette(SeatPalette().selected(.purple))
        }
        PreviewCase("Custom entry, tiers only") {
            SeatLegend(tiers: [.standard, .extraLegroom])
                .entry(String(themeKit: "Bassinet"), color: .info)
                .showsSelected(false).showsOccupied(false)
        }
        PreviewCase("Seatback swatches, large") {
            SeatLegend(tiers: [.standard, .exit]).swatchShape(.seatback).swatchSize(.large)
        }
        PreviewCase("Vertical") { SeatLegend(tiers: [.standard, .exit]).orientation(.vertical) }
        PreviewCase("Inline, circle") {
            SeatLegend(tiers: [.standard]).orientation(.inline).swatchShape(.circle)
        }
    }
}
