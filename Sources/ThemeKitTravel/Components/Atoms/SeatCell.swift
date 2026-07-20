//
//  SeatCell.swift
//  ThemeKit
//
//  Atom. A single seat button — token-bound fill/border by tier + state, a
//  configurable inner label (icon / number / initials / custom), a swappable
//  silhouette (rounded / circle / seatback) and a recommended star. Composed by
//  ``SeatMap`` but reusable on its own for bespoke seat grids.
//
//  Presentation is style-driven (``SeatCellStyle``, ADR-0004): `.rounded`
//  (default) / `.circle` / `.seatback`, settable once per screen via
//  `.seatCellStyle(_:)`. See `SeatCellStyle.swift` for the full anatomy.
//
//  NOTE: this atom predates the copy-on-write modifier convention — its other
//  knobs (palette, display, size…) are DEFAULTED init params by design. Full
//  COW migration deferred to next major; `SeatCellStyle` is this atom's
//  modernization path for its one look axis, the silhouette.
//

import SwiftUI
import ThemeKit

/// How a selected ``SeatCell`` is emphasized. Both looks resolve their colours
/// from ``SeatPalette/selectedColors(theme:)``, so a palette override drives
/// either treatment.
public enum SeatSelectionEmphasis: Sendable {
    /// The selected fill plus an emphasized 2 pt ring — the shipped default.
    case border
    /// The selected fill alone; the ring is dropped for a flat look.
    case fill
}

public struct SeatCell: View {
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    @Environment(\.componentDensity) private var density
    @Environment(\.seatCellStyle) private var envStyle

    // Content (R1) + state.
    private let seat: Seat
    private let size: CGFloat
    private let isSelected: Bool
    private let isSelectable: Bool
    private let isRecommended: Bool
    private let assignedInitials: String?
    private let display: SeatDisplay
    private let palette: SeatPalette
    private let customContent: ((SeatContext) -> AnyView)?
    private let currencyCode: String?
    private let shape: SeatShape
    private let recommendedSymbol: String
    private let selectionEmphasis: SeatSelectionEmphasis
    private let action: () -> Void

    /// - Parameter shape: **Deprecated** — prefer `.seatCellStyle(_:)`; kept for source
    ///   compatibility. A non-default value (`.circle`/`.seatback`) still wins over an
    ///   ancestor `.seatCellStyle(_:)` (ADR-0004 §5's source-behavior stability); the
    ///   default `.rounded` falls through to the environment style.
    public init(_ seat: Seat,
                size: CGFloat = 44,
                isSelected: Bool = false,
                isSelectable: Bool = true,
                isRecommended: Bool = false,
                assignedInitials: String? = nil,
                display: SeatDisplay = .icon,
                palette: SeatPalette = .default,
                customContent: ((SeatContext) -> AnyView)? = nil,
                currencyCode: String = "USD",
                shape: SeatShape = .rounded,
                recommendedSymbol: String = "star.fill",
                selectionEmphasis: SeatSelectionEmphasis = .border,
                action: @escaping () -> Void = {}) {
        self.seat = seat
        self.size = size
        self.isSelected = isSelected
        self.isSelectable = isSelectable
        self.isRecommended = isRecommended
        self.assignedInitials = assignedInitials
        self.display = display
        self.palette = palette
        self.customContent = customContent
        self.currencyCode = currencyCode
        self.shape = shape
        self.recommendedSymbol = recommendedSymbol
        self.selectionEmphasis = selectionEmphasis
        self.action = action
    }

    /// Omitted-currency form — resolves the code from the environment:
    /// `formatDefaults.currencyCode` → `locale.currency` → `"USD"` (§10).
    /// - Parameter shape: **Deprecated** — prefer `.seatCellStyle(_:)`; see the
    ///   designated init's parameter doc for the explicit/environment precedence rule.
    public init(_ seat: Seat,
                size: CGFloat = 44,
                isSelected: Bool = false,
                isSelectable: Bool = true,
                isRecommended: Bool = false,
                assignedInitials: String? = nil,
                display: SeatDisplay = .icon,
                palette: SeatPalette = .default,
                customContent: ((SeatContext) -> AnyView)? = nil,
                shape: SeatShape = .rounded,
                recommendedSymbol: String = "star.fill",
                selectionEmphasis: SeatSelectionEmphasis = .border,
                action: @escaping () -> Void = {}) {
        self.seat = seat
        self.size = size
        self.isSelected = isSelected
        self.isSelectable = isSelectable
        self.isRecommended = isRecommended
        self.assignedInitials = assignedInitials
        self.display = display
        self.palette = palette
        self.customContent = customContent
        self.currencyCode = nil
        self.shape = shape
        self.recommendedSymbol = recommendedSymbol
        self.selectionEmphasis = selectionEmphasis
        self.action = action
    }

    /// Token-stepped size overload — `size:` takes a ``SeatSizeRamp`` instead of
    /// raw points (compact 36 · regular 44 · large 52 · xl 60). A `nil`
    /// `currencyCode` resolves from the environment like the omitted-currency init.
    /// - Parameter shape: **Deprecated** — prefer `.seatCellStyle(_:)`; see the
    ///   designated init's parameter doc for the explicit/environment precedence rule.
    public init(_ seat: Seat,
                size ramp: SeatSizeRamp,
                isSelected: Bool = false,
                isSelectable: Bool = true,
                isRecommended: Bool = false,
                assignedInitials: String? = nil,
                display: SeatDisplay = .icon,
                palette: SeatPalette = .default,
                customContent: ((SeatContext) -> AnyView)? = nil,
                currencyCode: String? = nil,
                shape: SeatShape = .rounded,
                recommendedSymbol: String = "star.fill",
                selectionEmphasis: SeatSelectionEmphasis = .border,
                action: @escaping () -> Void = {}) {
        if let currencyCode {
            self.init(seat, size: ramp.points, isSelected: isSelected, isSelectable: isSelectable,
                      isRecommended: isRecommended, assignedInitials: assignedInitials,
                      display: display, palette: palette, customContent: customContent,
                      currencyCode: currencyCode, shape: shape, recommendedSymbol: recommendedSymbol,
                      selectionEmphasis: selectionEmphasis, action: action)
        } else {
            self.init(seat, size: ramp.points, isSelected: isSelected, isSelectable: isSelectable,
                      isRecommended: isRecommended, assignedInitials: assignedInitials,
                      display: display, palette: palette, customContent: customContent,
                      shape: shape, recommendedSymbol: recommendedSymbol,
                      selectionEmphasis: selectionEmphasis, action: action)
        }
    }

    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    /// The deprecated `shape:` init param's own preset, when it requested a
    /// non-default silhouette. `.rounded` is indistinguishable from "not set"
    /// — it's the shared default of both the parameter and
    /// ``RoundedSeatCellStyle`` — so it falls through to the environment
    /// style, letting an ancestor `.seatCellStyle(_:)` take effect for the
    /// common (default-shape) call site. An explicit `.circle`/`.seatback`
    /// still wins over the environment (ADR-0004 §5's source-behavior
    /// stability) — pre-existing call sites (e.g. ``SeatMap``, which forwards
    /// its own `.seatShape(_:)` knob here) keep rendering exactly what they
    /// render today.
    private var explicitStyle: AnySeatCellStyle? {
        switch shape {
        case .rounded: return nil
        case .circle: return AnySeatCellStyle(CircleSeatCellStyle())
        case .seatback: return AnySeatCellStyle(SeatbackSeatCellStyle())
        }
    }

    public var body: some View {
        let configuration = SeatCellConfiguration(
            seat: seat,
            isSelected: isSelected,
            isSelectable: isSelectable,
            isRecommended: isRecommended,
            recommendedSymbol: recommendedSymbol,
            assignedInitials: assignedInitials,
            display: display,
            customContent: customContent,
            palette: palette,
            selectionEmphasis: selectionEmphasis,
            shape: shape,
            size: size,
            currencyCode: resolvedCurrency,
            density: density,
            locale: locale,
            action: action)
        (explicitStyle ?? envStyle).makeBody(configuration: configuration)
    }
}

#Preview {
    struct Demo: View {
        @State var picked = false
        var body: some View {
            PreviewMatrix("SeatCell") {
                PreviewCase("Selectable (tap)") { SeatCell(Seat("1A"), isSelected: picked, action: { picked.toggle() }) }
                PreviewCase("Selected") { SeatCell(Seat("1B"), isSelected: true) }
                PreviewCase("Business") { SeatCell(Seat("1C", tier: .business)) }
                PreviewCase("Exit row") { SeatCell(Seat("1D", tier: .exit)) }
                PreviewCase("Occupied") { SeatCell(Seat("1E", occupied: true)) }
                PreviewCase("Recommended") { SeatCell(Seat("1F"), isRecommended: true) }
                PreviewCase("Number display") { SeatCell(Seat("1G"), display: .number) }
                PreviewCase("Accent selected") { SeatCell(Seat("2A"), isSelected: true, palette: SeatPalette().selected(.accent)) }
                PreviewCase("Accent occupied") { SeatCell(Seat("2B", occupied: true), palette: SeatPalette().occupied(.warning)) }
                PreviewCase("Circle shape") { SeatCell(Seat("3A"), shape: .circle) }
                PreviewCase("Seatback shape") { SeatCell(Seat("3B"), shape: .seatback) }
                PreviewCase("Seatback selected") { SeatCell(Seat("3C"), isSelected: true, shape: .seatback) }
                PreviewCase("Ramp sizes") {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        SeatCell(Seat("4A"), size: .compact)
                        SeatCell(Seat("4B"), size: .regular)
                        SeatCell(Seat("4C"), size: .large)
                        SeatCell(Seat("4D"), size: .xl)
                    }
                }
                PreviewCase("Fill emphasis") { SeatCell(Seat("5A"), isSelected: true, selectionEmphasis: .fill) }
                PreviewCase("Custom star") { SeatCell(Seat("5B"), isRecommended: true, recommendedSymbol: "sparkles") }
            }
        }
    }
    return Demo()
}
