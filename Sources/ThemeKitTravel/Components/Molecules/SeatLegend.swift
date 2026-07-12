//
//  SeatLegend.swift
//  ThemeKit
//
//  Molecule. A key for a ``SeatMap`` — the fare tiers present, plus Selected and
//  Occupied — wrapping to rows. Tier *and* selected/occupied colours come from a
//  ``SeatPalette`` so it matches whatever the map (or a brand override) uses.
//
//  The *arrangement* is owned by the active ``SeatLegendStyle`` from the
//  environment (ADR-0004): the component gathers its typed data into a
//  `SeatLegendConfiguration` and hands it to the style — `.rows(perRow: 3)`
//  (default) is today's wrapping grid verbatim, `.vertical` stacks one entry
//  per line, `.inline` draws a single unwrapped row, and apps can implement
//  their own. The deprecated `.orientation(_:)` / `.perRow(_:)` modifiers
//  forward to the matching preset and, when called, win over an ancestor's
//  environment style. Configuration flows through chainable copy-on-write
//  modifiers (R2); the original init parameters remain for source
//  compatibility.
//

import SwiftUI
import ThemeKit

/// How a ``SeatLegend`` lays out its entries.
///
/// Superseded by ``SeatLegendStyle`` (each case maps 1:1 to a preset —
/// `.rows` → ``RowsSeatLegendStyle``, `.vertical` → ``VerticalSeatLegendStyle``,
/// `.inline` → ``InlineSeatLegendStyle``); kept for source compatibility until
/// the next major, together with the deprecated ``SeatLegend/orientation(_:)``
/// modifier.
public enum SeatLegendOrientation: Sendable {
    /// Wraps into rows of `perRow(_:)` entries — the default.
    case rows
    /// One entry per line.
    case vertical
    /// A single unwrapped row.
    case inline
}

public struct SeatLegend: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.locale) private var locale
    @Environment(\.seatLegendStyle) private var envStyle

    // Appearance/state — mutated only through the modifiers below (R2). The
    // init params are kept as a convenience/back-compat surface.
    private var tiers: [SeatTier]
    private var palette: SeatPalette
    private var perRow: Int
    private var showsSelected = true
    private var showsOccupied = true
    private var extraEntries: [SeatLegendCustomEntry] = []
    private var swatchShape: SeatShape = .rounded
    private var swatchRamp: SeatSizeRamp?
    /// Bookkeeping for the deprecated `.orientation(_:)` modifier — an
    /// explicitly chosen per-instance orientation wins over an ancestor's
    /// `.seatLegendStyle(_:)` (source-behavior stability during the enum's
    /// deprecation window). `nil` → environment style.
    private var explicitOrientation: SeatLegendOrientation?

    public init(tiers: [SeatTier] = [.standard], palette: SeatPalette = .default, perRow: Int = 3) {
        self.tiers = tiers
        self.palette = palette
        self.perRow = max(1, perRow)
    }

    /// The style the deprecated `.orientation(_:)` / `.perRow(_:)` modifiers
    /// mapped to, or `nil` when neither was called (the normal path — the
    /// environment style renders). `perRow` diverging from the shipped default
    /// (3) is treated as an explicit signal too, since the pre-ADR `perRow:`
    /// init parameter fed the exact same knob directly.
    private var explicitStyle: AnySeatLegendStyle? {
        switch explicitOrientation {
        case .vertical: return AnySeatLegendStyle(VerticalSeatLegendStyle())
        case .inline: return AnySeatLegendStyle(InlineSeatLegendStyle())
        case .rows: return AnySeatLegendStyle(RowsSeatLegendStyle(perRow: perRow))
        case nil: return perRow == 3 ? nil : AnySeatLegendStyle(RowsSeatLegendStyle(perRow: perRow))
        }
    }

    public var body: some View {
        let configuration = SeatLegendConfiguration(
            tiers: tiers,
            palette: palette,
            showsSelected: showsSelected,
            showsOccupied: showsOccupied,
            customEntries: extraEntries,
            swatchShape: swatchShape,
            swatchSize: swatchRamp ?? .regular,
            density: density,
            locale: locale)
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
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
    /// Entries per row in the `.rows` style — superseded by the style axis:
    /// prefer `.seatLegendStyle(.rows(perRow:))`, settable once per screen via
    /// the environment. This modifier keeps working and, when called, wins
    /// over an ancestor's environment style.
    @available(*, deprecated, message: "Use .seatLegendStyle(.rows(perRow:)) instead")
    func perRow(_ count: Int) -> Self { copy { $0.perRow = max(1, count) } }
    /// Whether the synthetic "Selected" entry is appended (default `true`).
    func showsSelected(_ on: Bool = true) -> Self { copy { $0.showsSelected = on } }
    /// Whether the synthetic "Occupied" entry is appended (default `true`).
    func showsOccupied(_ on: Bool = true) -> Self { copy { $0.showsOccupied = on } }
    /// Appends a custom key (e.g. "Bassinet") — the swatch fills with the
    /// token's soft background and strokes with its base shade, matching how
    /// tier overrides resolve.
    func entry(_ label: String, color: SemanticColor) -> Self {
        copy { $0.extraEntries.append(SeatLegendCustomEntry(label: label, color: color)) }
    }
    /// The swatch silhouette — pass the map's ``SeatShape`` so the key matches
    /// the seats (``SeatMap`` forwards its own automatically).
    func swatchShape(_ shape: SeatShape) -> Self { copy { $0.swatchShape = shape } }
    /// Steps the swatch size alongside a map using the same ``SeatSizeRamp``.
    func swatchSize(_ ramp: SeatSizeRamp) -> Self { copy { $0.swatchRamp = ramp } }
    /// Layout direction of the entries — superseded by the style axis: prefer
    /// `.seatLegendStyle(.rows(perRow:))` / `.seatLegendStyle(.vertical)` /
    /// `.seatLegendStyle(.inline)`, settable once per screen via the
    /// environment. This modifier keeps working and, when called, wins over an
    /// ancestor's environment style.
    @available(*, deprecated, message: "Use .seatLegendStyle(.rows(perRow:)/.vertical/.inline) instead")
    func orientation(_ orientation: SeatLegendOrientation) -> Self { copy { $0.explicitOrientation = orientation } }

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
            SeatLegend().tiers([.standard, .business])
                .palette(SeatPalette().selected(.purple))
                .seatLegendStyle(.rows(perRow: 2))
        }
        PreviewCase("Custom entry, tiers only") {
            SeatLegend(tiers: [.standard, .extraLegroom])
                .entry(String(themeKit: "Bassinet"), color: .info)
                .showsSelected(false).showsOccupied(false)
        }
        PreviewCase("Seatback swatches, large") {
            SeatLegend(tiers: [.standard, .exit]).swatchShape(.seatback).swatchSize(.large)
        }
        PreviewCase("Vertical (env style)") {
            SeatLegend(tiers: [.standard, .exit]).seatLegendStyle(.vertical)
        }
        PreviewCase("Inline, circle") {
            SeatLegend(tiers: [.standard]).swatchShape(.circle).seatLegendStyle(.inline)
        }
    }
}
