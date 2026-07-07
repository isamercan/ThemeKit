//
//  SeatLegend.swift
//  ThemeKit
//
//  Molecule. A key for a ``SeatMap`` — the fare tiers present, plus Selected and
//  Occupied — wrapping to rows. Tier colours come from a ``SeatPalette`` so it
//  matches whatever the map (or a brand override) uses.
//

import SwiftUI

public struct SeatLegend: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private var tiers: [SeatTier]
    private let palette: SeatPalette
    private let perRow: Int

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
        e.append(Entry(fill: theme.foreground(.fgHero), border: theme.foreground(.fgHero), label: "Selected"))
        e.append(Entry(fill: theme.background(.bgSecondary), border: theme.border(.borderPrimary), label: "Occupied"))
        return e
    }

    public var body: some View {
        let items = entries
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(stride(from: 0, to: items.count, by: perRow)), id: \.self) { start in
                HStack(spacing: density.scale(Theme.SpacingKey.md.value)) {
                    ForEach(items[start..<min(start + perRow, items.count)]) { swatch($0) }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func swatch(_ entry: Entry) -> some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(entry.fill)
                .overlay(RoundedRectangle(cornerRadius: 4, style: .continuous).stroke(entry.border, lineWidth: 1))
                .frame(width: 14, height: 14)
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

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        SeatLegend(tiers: [.standard, .extraLegroom, .exit])
        SeatLegend(tiers: [.standard, .premium, .business, .first])
    }
    .padding()
}
