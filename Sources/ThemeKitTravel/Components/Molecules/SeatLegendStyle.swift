//
//  SeatLegendStyle.swift
//  ThemeKit
//
//  The styling hook for ``SeatLegend`` — a Class A style protocol of ADR-0004
//  (per-component style protocols): the configuration hands styles the *typed*
//  legend data (resolved tiers, palette, selected/occupied flags, custom
//  entries…), not pre-laid content, so a style owns the entire arrangement.
//  Three built-ins, promoting the former ``SeatLegendOrientation`` enum:
//
//    .rows(perRow:)  wraps entries into rows of `perRow` (floored at 1) —
//                    today's key, verbatim. `.rows(perRow: 3)` is the default.
//    .vertical       one entry per line.
//    .inline         a single unwrapped row.
//
//      SeatLegend(tiers: [.standard, .exit])
//          .seatLegendStyle(.vertical)
//
//  Tier *and* selected/occupied colours always come from the configuration's
//  ``SeatLegendConfiguration/palette`` (a ``SeatPalette``) — never the style —
//  so a legend always matches whatever ``SeatMap`` (or a brand override) uses.
//  The component style only arranges the resolved swatches; the token theme
//  colors everything.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// A caller-supplied legend key (``SeatLegend/entry(_:color:)``), e.g. "Bassinet".
/// The swatch fills with the token's soft background and strokes with its base
/// shade, matching how tier overrides resolve.
public struct SeatLegendCustomEntry: Sendable {
    public let label: String
    public let color: SemanticColor

    public init(label: String, color: SemanticColor) {
        self.label = label
        self.color = color
    }
}

/// One resolved legend key — a swatch fill/border pair plus its label. Returned
/// by ``SeatLegendConfiguration/entries(theme:)`` for a style to draw; a custom
/// style never derives colours itself, it only lays these out.
public struct SeatLegendEntry: Identifiable, Sendable {
    public let fill: Color
    public let border: Color
    public let label: String
    public var id: String { label }
}

/// The typed inputs a ``SeatLegendStyle`` lays out. Fields a given style doesn't
/// use are simply ignored — every built-in degrades gracefully when optional
/// data is absent (no custom entries → no extra keys, no premium tier → no
/// premium key).
public struct SeatLegendConfiguration {
    /// The fare tiers to key, in display order.
    public let tiers: [SeatTier]
    /// The palette every swatch resolves its colours from — tier fills/strokes
    /// and the synthetic Selected/Occupied entries all route through it, so the
    /// legend always matches whatever the map (or a brand override) uses.
    public let palette: SeatPalette
    /// Whether the synthetic "Selected" entry is appended (default `true`).
    public let showsSelected: Bool
    /// Whether the synthetic "Occupied" entry is appended (default `true`).
    public let showsOccupied: Bool
    /// Caller-supplied extra keys (``SeatLegend/entry(_:color:)``), appended
    /// after the tier entries and before Selected/Occupied.
    public let customEntries: [SeatLegendCustomEntry]
    /// The swatch silhouette — matches whatever ``SeatMap``/``SeatCell`` draws.
    public let swatchShape: SeatShape
    /// The swatch size ramp (``SeatLegend/swatchSize(_:)``); resolves to
    /// ``swatchSide`` in points.
    public let swatchSize: SeatSizeRamp
    /// The environment's component density, captured by the component — scale
    /// chrome gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component, for parity with the
    /// rest of the suite (no date/number formatting needed by the built-ins
    /// today, but a custom style may localize its own labels with it).
    public let locale: Locale

    /// Density-scaled spacing — use for chrome gaps so `.componentDensity`
    /// compacts or airs out the legend.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The swatch square's side, in points, stepped by ``swatchSize``. Legend
    /// swatches are keys, not touch targets — the ramp maps to a scaled-down
    /// side so `.swatchSize(.large)` tracks a larger map without dwarfing the
    /// labels.
    public var swatchSide: CGFloat {
        switch swatchSize {
        case .compact: return 12
        case .regular: return 14
        case .large: return 17
        case .xl: return 20
        }
    }

    /// The resolved legend keys, in draw order: tiers, then ``customEntries``,
    /// then the synthetic Selected/Occupied entries. Every colour comes from
    /// ``palette`` (or a custom entry's own semantic color) — styles only lay
    /// these out.
    public func entries(theme: Theme) -> [SeatLegendEntry] {
        var e = tiers.map { tier -> SeatLegendEntry in
            let c = palette.colors(for: tier, theme: theme)
            return SeatLegendEntry(fill: c.fill, border: c.stroke, label: tier.label)
        }
        e += customEntries.map { SeatLegendEntry(fill: theme.resolve($0.color).bg, border: theme.resolve($0.color).base, label: $0.label) }
        if showsSelected {
            let selected = palette.selectedColors(theme: theme)
            e.append(SeatLegendEntry(fill: selected.fill, border: selected.stroke, label: String(themeKit: "Selected")))
        }
        if showsOccupied {
            let occupied = palette.occupiedColors(theme: theme)
            e.append(SeatLegendEntry(fill: occupied.fill, border: occupied.stroke, label: String(themeKit: "Occupied")))
        }
        return e
    }
}

// MARK: - Protocol

/// Defines a `SeatLegend`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's resolved keys. Set one with `.seatLegendStyle(_:)`;
/// the default is ``RowsSeatLegendStyle`` with 3 entries per row.
public protocol SeatLegendStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SeatLegendConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// One legend key: silhouette swatch + label — shared by all three built-ins,
/// extracted verbatim from the pre-style component.
private struct SeatLegendSwatch: View {
    @Environment(\.theme) private var theme
    let configuration: SeatLegendConfiguration
    let entry: SeatLegendEntry

    var body: some View {
        // Legend swatches are keys, not touch targets — the corner radius stays
        // a fixed constant (a genuine dimension with no semantic token).
        let shape = configuration.swatchShape.anyShape(cornerRadius: 4)
        HStack(spacing: Theme.SpacingKey.xs.value) {
            shape.fill(entry.fill)
                .overlay(shape.stroke(entry.border, lineWidth: 1))
                .frame(width: configuration.swatchSide, height: configuration.swatchSide)
            Text(entry.label).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                .fixedSize(horizontal: true, vertical: false)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - .rows(perRow:)

/// Today's ``SeatLegend`` look, extracted verbatim: entries wrap into rows of
/// `perRow` (floored at 1). `.rows(perRow: 3)` is the default.
public struct RowsSeatLegendStyle: SeatLegendStyle {
    /// Entries per row (floored at 1).
    public let perRow: Int

    public init(perRow: Int = 3) { self.perRow = max(1, perRow) }

    public func makeBody(configuration: SeatLegendConfiguration) -> some View {
        RowsSeatLegendChrome(configuration: configuration, perRow: perRow)
    }
}

private struct RowsSeatLegendChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SeatLegendConfiguration
    let perRow: Int

    var body: some View {
        let items = configuration.entries(theme: theme)
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ForEach(Array(stride(from: 0, to: items.count, by: perRow)), id: \.self) { start in
                HStack(spacing: configuration.spacing(.md)) {
                    ForEach(items[start..<min(start + perRow, items.count)]) {
                        SeatLegendSwatch(configuration: configuration, entry: $0)
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }
}

// MARK: - .vertical

/// One entry per line.
public struct VerticalSeatLegendStyle: SeatLegendStyle {
    public init() {}
    public func makeBody(configuration: SeatLegendConfiguration) -> some View {
        VerticalSeatLegendChrome(configuration: configuration)
    }
}

private struct VerticalSeatLegendChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SeatLegendConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            ForEach(configuration.entries(theme: theme)) {
                SeatLegendSwatch(configuration: configuration, entry: $0)
            }
        }
    }
}

// MARK: - .inline

/// A single unwrapped row.
public struct InlineSeatLegendStyle: SeatLegendStyle {
    public init() {}
    public func makeBody(configuration: SeatLegendConfiguration) -> some View {
        InlineSeatLegendChrome(configuration: configuration)
    }
}

private struct InlineSeatLegendChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SeatLegendConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing(.md)) {
            ForEach(configuration.entries(theme: theme)) {
                SeatLegendSwatch(configuration: configuration, entry: $0)
            }
        }
    }
}

// MARK: - Static accessors

public extension SeatLegendStyle where Self == RowsSeatLegendStyle {
    /// Wraps entries into rows of `perRow` (floored at 1) — today's key. The
    /// default is `.rows(perRow: 3)`.
    static func rows(perRow: Int = 3) -> RowsSeatLegendStyle { RowsSeatLegendStyle(perRow: perRow) }
}
public extension SeatLegendStyle where Self == VerticalSeatLegendStyle {
    /// One entry per line.
    static var vertical: VerticalSeatLegendStyle { VerticalSeatLegendStyle() }
}
public extension SeatLegendStyle where Self == InlineSeatLegendStyle {
    /// A single unwrapped row.
    static var inline: InlineSeatLegendStyle { InlineSeatLegendStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySeatLegendStyle: SeatLegendStyle {
    private let _makeBody: @MainActor (SeatLegendConfiguration) -> AnyView
    init<S: SeatLegendStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SeatLegendConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SeatLegendStyleKey: EnvironmentKey {
    static let defaultValue = AnySeatLegendStyle(RowsSeatLegendStyle())
}

extension EnvironmentValues {
    var seatLegendStyle: AnySeatLegendStyle {
        get { self[SeatLegendStyleKey.self] }
        set { self[SeatLegendStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SeatLegendStyle`` for `SeatLegend`s in this view and its
    /// descendants — one screen can restyle every legend at once.
    func seatLegendStyle<S: SeatLegendStyle>(_ style: sending S) -> some View {
        environment(\.seatLegendStyle, AnySeatLegendStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a cloud of colored pill badges instead of square swatches. Colours
/// still come entirely from ``SeatLegendConfiguration/entries(theme:)`` — the
/// custom style only lays them out.
private struct PillCloudSeatLegendStyle: SeatLegendStyle {
    func makeBody(configuration: SeatLegendConfiguration) -> some View {
        PillCloudChrome(configuration: configuration)
    }

    private struct PillCloudChrome: View {
        @Environment(\.theme) private var theme
        let configuration: SeatLegendConfiguration

        var body: some View {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(configuration.entries(theme: theme)) { entry in
                    Text(entry.label)
                        .textStyle(.overline500)
                        .foregroundStyle(entry.border)
                        .padding(.horizontal, Theme.SpacingKey.sm.value)
                        .padding(.vertical, Theme.SpacingKey.xs.value)
                        .background(entry.fill, in: Capsule())
                        .overlay(Capsule().stroke(entry.border, lineWidth: 1))
                }
            }
        }
    }
}

#Preview("SeatLegendStyle — presets × light/dark") {
    let tiers: [SeatTier] = [.standard, .extraLegroom, .exit, .business]
    PreviewMatrix("SeatLegendStyle") {
        PreviewCase("Rows (default, 3 per row)") { SeatLegend(tiers: tiers) }
        PreviewCase("Rows · 2 per row") {
            SeatLegend(tiers: tiers).seatLegendStyle(.rows(perRow: 2))
        }
        PreviewCase("Vertical") {
            SeatLegend(tiers: tiers).seatLegendStyle(.vertical)
        }
        PreviewCase("Inline") {
            SeatLegend(tiers: [.standard, .exit]).seatLegendStyle(.inline)
        }
        PreviewCase("Accent palette · vertical") {
            SeatLegend(tiers: [.standard, .exit], palette: SeatPalette().selected(.purple).occupied(.warning))
                .seatLegendStyle(.vertical)
        }
        PreviewCase("Custom (in-preview)") {
            SeatLegend(tiers: tiers).seatLegendStyle(PillCloudSeatLegendStyle())
        }
    }
}
