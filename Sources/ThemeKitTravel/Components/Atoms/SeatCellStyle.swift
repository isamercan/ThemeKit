//
//  SeatCellStyle.swift
//  ThemeKit
//
//  The styling hook for ``SeatCell`` (ADR-0004, Wave 5). An atom has no layout
//  anatomy to swap — these three presets promote ``SeatShape``, the one knob
//  that *is* the look, so the seat-map family answers to the same
//  `.xStyle(_:)` mental model as the rest of the suite, settable once per
//  screen via the environment. Every other knob (``SeatSelectionEmphasis``,
//  size, palette, display content) stays a *configuration* field — it
//  composes with any preset, including custom ones. Selected/occupied chroma
//  is always **palette**-driven; no style may invent its own free accent.
//
//    .rounded   continuous-corner rounded square — today's cell. Default.
//    .circle    a circle.
//    .seatback  a squircle with a concave backrest notch.
//
//      SeatCell(Seat("12A"), isSelected: true)
//          .seatCellStyle(.circle)
//
//  Doubles as this pre-COW atom's modernization path (`SeatCell.swift:10–12`):
//  the deprecated `shape:` init param still selects one of these three presets
//  directly when set to a non-default silhouette (explicit wins over an
//  ancestor `.seatCellStyle(_:)` — ADR-0004 §5's source-behavior stability); a
//  `SeatCell(...)` that never touches `shape:` picks up the environment style
//  like any other ThemeKit component. No major/COW migration needed.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``SeatCellStyle`` renders. Fields a given style doesn't
/// use are simply ignored — the built-ins degrade gracefully when optional
/// data is absent (no ``customContent`` → the built-in ``display`` mode, no
/// ``assignedInitials`` → the tier/state glyph).
public struct SeatCellConfiguration {
    /// The seat and its fare tier — drives the tier fill/stroke and glyph.
    public let seat: Seat
    /// Selected state.
    public let isSelected: Bool
    /// Whether the seat can be tapped (occupied/blocked seats stay tappable
    /// while already selected, so they can be deselected).
    public let isSelectable: Bool
    /// Recommended flag; resolve via ``showsStar``.
    public let isRecommended: Bool
    /// SF Symbol for the recommended star.
    public let recommendedSymbol: String
    /// Assigned passenger initials, in passenger-assignment mode.
    public let assignedInitials: String?
    /// How the built-in inner content is drawn — icon / number / initials / both.
    public let display: SeatDisplay
    /// Fully custom inner content, replacing ``display`` entirely when set.
    public let customContent: ((SeatContext) -> AnyView)?
    /// Tier/selected/occupied colour mapping — resolve via
    /// ``fillColor(theme:)`` / ``strokeColor(theme:)`` / ``contentColor(theme:)``.
    /// Selected and occupied chroma are always **palette**-driven; a style
    /// must never invent its own accent for either state.
    public let palette: SeatPalette
    /// How a selected seat is emphasized — a ring (default) or fill alone.
    public let selectionEmphasis: SeatSelectionEmphasis
    /// The silhouette this cell was constructed to draw. Informational: the
    /// three built-ins each draw their own named shape regardless of this
    /// field (so an ancestor `.seatCellStyle(_:)` reliably wins for the
    /// common default-shape call site — see the file header); a custom style
    /// may honour it to reproduce the caller-requested silhouette instead.
    public let shape: SeatShape
    /// The cell's side, in points.
    public let size: CGFloat
    /// Already-resolved currency code (the component's FormatDefaults chain),
    /// used for the a11y price value.
    public let currencyCode: String
    /// The environment's component density, captured by the component — scale
    /// any chrome a custom style adds with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component.
    public let locale: Locale
    /// The tap action.
    public let action: () -> Void

    /// Convenience read-out of ``Seat/isOccupied``.
    public var isOccupied: Bool { seat.isOccupied }
    /// Whether the recommended star should be drawn — hidden once selected or
    /// unselectable, so it never competes with the checkmark/✕ glyph.
    public var showsStar: Bool { isRecommended && isSelectable && !isSelected }

    /// The cell's fill, resolved through ``palette`` for the current state.
    public func fillColor(theme: Theme) -> Color {
        if isSelected { return palette.selectedColors(theme: theme).fill }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).fill }
        return palette.colors(for: seat.tier, theme: theme).fill
    }
    /// The cell's stroke, resolved through ``palette`` — `.fill` emphasis
    /// drops the selected ring (`.clear`).
    public func strokeColor(theme: Theme) -> Color {
        if isSelected {
            return selectionEmphasis == .border ? palette.selectedColors(theme: theme).stroke : .clear
        }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).stroke }
        return palette.colors(for: seat.tier, theme: theme).stroke
    }
    /// The stroke width — 2 pt selected ring (`.border` emphasis), 0 pt for
    /// `.fill` emphasis, 1 pt hairline otherwise.
    public var strokeWidth: CGFloat {
        guard isSelected else { return 1 }
        return selectionEmphasis == .border ? 2 : 0
    }
    /// The inner content's colour, resolved through ``palette``.
    public func contentColor(theme: Theme) -> Color {
        if isSelected { return palette.selectedColors(theme: theme).content }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).content }
        return theme.text(.textSecondary)
    }

    /// Density-scaled spacing, for any chrome a custom style adds around the cell.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// "Seat 12A" / "Seat 12A, Business" — the accessibility label every
    /// built-in shares.
    public var accessibilityLabel: String {
        var s = String(themeKit: "Seat \(seat.id)")
        if seat.tier != .standard { s += ", \(seat.tier.label)" }   // tier.label is already bridge-localized
        return s
    }
    /// "Occupied" / "Unavailable" / "Selected" / "Available, $129" / "Available".
    public var accessibilityValue: String {
        if seat.isOccupied { return String(themeKit: "Occupied") }
        if !isSelectable { return String(themeKit: "Unavailable") }
        if isSelected { return String(themeKit: "Selected") }
        if let price = seat.price {
            return String(themeKit: "Available, \(price.formatted(.currency(code: currencyCode).precision(.fractionLength(0))))")
        }
        return String(themeKit: "Available")
    }
    /// The select/deselect hint, or empty when the seat can't be tapped.
    public var accessibilityHint: String {
        isSelectable ? "Double-tap to \(isSelected ? "deselect" : "select")" : ""
    }
}

// MARK: - Protocol

/// Defines a `SeatCell`'s entire presentation. Implement `makeBody` to draw
/// the configuration's seat. Set one with `.seatCellStyle(_:)`; the default
/// is ``RoundedSeatCellStyle``.
public protocol SeatCellStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: SeatCellConfiguration) -> Body
}

// MARK: - Shared chrome (private to the built-ins)

/// The button/overlay stack every built-in shares — only the silhouette
/// (`shape`) differs between `.rounded` / `.circle` / `.seatback`; every other
/// pixel (fill, stroke, glyph, star, a11y) is identical, so the three presets
/// are thin wrappers over this one chrome, each pinning its own shape.
private struct SeatCellChrome: View {
    @Environment(\.theme) private var theme
    let configuration: SeatCellConfiguration
    let shape: SeatShape

    var body: some View {
        let cellShape = shape.anyShape(cornerRadius: Theme.RadiusRole.selector.value)
        Button(action: configuration.action) {
            cellShape
                .fill(configuration.fillColor(theme: theme))
                .overlay(cellShape.stroke(configuration.strokeColor(theme: theme), lineWidth: configuration.strokeWidth))
                .overlay(glyph)
                .overlay(alignment: .topTrailing) { if configuration.showsStar { recommendedStar } }
                .frame(width: configuration.size, height: configuration.size)
                .opacity(configuration.isSelectable || configuration.isSelected ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!configuration.isSelectable && !configuration.isSelected)
        .accessibilityLabel(configuration.accessibilityLabel)
        .accessibilityValue(configuration.accessibilityValue)
        .accessibilityHint(configuration.accessibilityHint)
        .accessibilityAddTraits(configuration.isSelected ? .isSelected : [])
    }

    // MARK: Content

    @ViewBuilder private var glyph: some View {
        if let customContent = configuration.customContent {
            customContent(SeatContext(
                seat: configuration.seat, isSelected: configuration.isSelected,
                isOccupied: configuration.seat.isOccupied, assignedInitials: configuration.assignedInitials))
        } else {
            defaultContent
        }
    }

    @ViewBuilder private var defaultContent: some View {
        switch configuration.display {
        case .number:
            Text(configuration.seat.id).textStyle(.overline500).foregroundStyle(contentColor)
                .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, 2)
        case .initials where configuration.assignedInitials != nil:
            Text(configuration.assignedInitials ?? "").textStyle(.labelSm600).foregroundStyle(contentColor)
        case .initialsAndNumber:
            VStack(spacing: 0) {
                if let assignedInitials = configuration.assignedInitials {
                    Text(assignedInitials).textStyle(.labelSm600).foregroundStyle(contentColor)
                }
                Text(configuration.seat.id).textStyle(.overline400).foregroundStyle(contentColor.opacity(0.75))
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(.horizontal, 2)
        case .icon, .initials:
            iconGlyph
        }
    }

    /// The inner content's colour, resolved through the configuration's palette.
    private var contentColor: Color { configuration.contentColor(theme: theme) }

    // Glyphs step through the type ramp (Dynamic Type for free) instead of
    // hardcoded point sizes.
    @ViewBuilder private var iconGlyph: some View {
        if let assignedInitials = configuration.assignedInitials {
            Text(assignedInitials).textStyle(.labelSm600).foregroundStyle(contentColor)
        } else if configuration.isSelected {
            Image(systemName: "checkmark").textStyle(.labelSm700).foregroundStyle(contentColor)
        } else if configuration.seat.isOccupied {
            Image(systemName: "xmark").textStyle(.labelSm600).foregroundStyle(contentColor)
        } else {
            Image(systemName: configuration.seat.tier.glyph).textStyle(.labelSm600).foregroundStyle(contentColor)
        }
    }

    private var recommendedStar: some View {
        Image(systemName: configuration.recommendedSymbol)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
            .padding(2)   // intentional: 2pt, no token — tiny 8pt-glyph recommended-star badge inset
            .background(theme.background(.bgBase), in: Circle())
            .offset(x: 3, y: -3)
    }
}

// MARK: - .rounded

/// A continuous-corner rounded square — today's cell, extracted verbatim. Default.
public struct RoundedSeatCellStyle: SeatCellStyle {
    public init() {}
    public func makeBody(configuration: SeatCellConfiguration) -> some View {
        SeatCellChrome(configuration: configuration, shape: .rounded)
    }
}

// MARK: - .circle

/// A circular cell — the shared chrome, a round silhouette.
public struct CircleSeatCellStyle: SeatCellStyle {
    public init() {}
    public func makeBody(configuration: SeatCellConfiguration) -> some View {
        SeatCellChrome(configuration: configuration, shape: .circle)
    }
}

// MARK: - .seatback

/// A squircle with a concave backrest notch cut into its top edge — the
/// seat-back silhouette.
public struct SeatbackSeatCellStyle: SeatCellStyle {
    public init() {}
    public func makeBody(configuration: SeatCellConfiguration) -> some View {
        SeatCellChrome(configuration: configuration, shape: .seatback)
    }
}

// MARK: - Static accessors

public extension SeatCellStyle where Self == RoundedSeatCellStyle {
    /// Continuous-corner rounded square — today's cell. The default.
    static var rounded: RoundedSeatCellStyle { RoundedSeatCellStyle() }
}
public extension SeatCellStyle where Self == CircleSeatCellStyle {
    /// A circle.
    static var circle: CircleSeatCellStyle { CircleSeatCellStyle() }
}
public extension SeatCellStyle where Self == SeatbackSeatCellStyle {
    /// A squircle with a concave backrest notch — the seat-back silhouette.
    static var seatback: SeatbackSeatCellStyle { SeatbackSeatCellStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnySeatCellStyle: SeatCellStyle {
    private let _makeBody: @MainActor (SeatCellConfiguration) -> AnyView
    init<S: SeatCellStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: SeatCellConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct SeatCellStyleKey: EnvironmentKey {
    static let defaultValue = AnySeatCellStyle(RoundedSeatCellStyle())
}

extension EnvironmentValues {
    var seatCellStyle: AnySeatCellStyle {
        get { self[SeatCellStyleKey.self] }
        set { self[SeatCellStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``SeatCellStyle`` for `SeatCell`s in this view and its
    /// descendants — a seat map sets it once for the whole cabin.
    func seatCellStyle<S: SeatCellStyle>(_ style: sending S) -> some View {
        environment(\.seatCellStyle, AnySeatCellStyle(style))
    }
}

// MARK: - Preview

/// A custom style built purely on the public API — what an app target would
/// write: a flat swatch with no ring/star chrome, proving the configuration
/// alone is enough to draw a legitimate seat cell from outside the module.
private struct FlatSwatchSeatCellStyle: SeatCellStyle {
    func makeBody(configuration: SeatCellConfiguration) -> some View {
        FlatSwatchChrome(configuration: configuration)
    }

    private struct FlatSwatchChrome: View {
        @Environment(\.theme) private var theme
        let configuration: SeatCellConfiguration

        var body: some View {
            Button(action: configuration.action) {
                RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                    .fill(configuration.fillColor(theme: theme))
                    .overlay(
                        Text(configuration.seat.id).textStyle(.overline500)
                            .foregroundStyle(configuration.contentColor(theme: theme)))
                    .frame(width: configuration.size, height: configuration.size)
                    .opacity(configuration.isSelectable || configuration.isSelected ? 1 : 0.55)
            }
            .buttonStyle(.plain)
            .disabled(!configuration.isSelectable && !configuration.isSelected)
            .accessibilityLabel(configuration.accessibilityLabel)
            .accessibilityValue(configuration.accessibilityValue)
        }
    }
}

// `.seatCellStyle(_:)` is applied once to the row, not per cell — exactly
// how a real cabin screen would set it (see the file header).
@MainActor private func seatCellStatesRow(_ style: some SeatCellStyle) -> some View {
    HStack(spacing: Theme.SpacingKey.sm.value) {
        SeatCell(Seat("1A"), isSelected: true, action: {})
        SeatCell(Seat("1B", tier: .business), action: {})
        SeatCell(Seat("1C", occupied: true), action: {})
        SeatCell(Seat("1D"), isRecommended: true, action: {})
        SeatCell(Seat("1E"), isSelectable: false, action: {})
    }
    .seatCellStyle(style)
}

#Preview("SeatCellStyle — presets × states × light/dark") {
    PreviewMatrix("SeatCellStyle") {
        PreviewCase("Rounded (default)") { seatCellStatesRow(.rounded) }
        PreviewCase("Circle") { seatCellStatesRow(.circle) }
        PreviewCase("Seatback") { seatCellStatesRow(.seatback) }
        PreviewCase("Seatback · fill emphasis, accent palette") {
            SeatCell(Seat("2A"), isSelected: true, palette: SeatPalette().selected(.accent), selectionEmphasis: .fill, action: {})
                .seatCellStyle(.seatback)
        }
        PreviewCase("Custom (in-preview, flat swatch)") { seatCellStatesRow(FlatSwatchSeatCellStyle()) }
    }
}
