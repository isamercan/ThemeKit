//
//  SeatCell.swift
//  ThemeKit
//
//  Atom. A single seat button — token-bound fill/border by tier + state, a
//  configurable inner label (icon / number / initials / custom), a swappable
//  silhouette (rounded / circle / seatback) and a recommended star. Composed by
//  ``SeatMap`` but reusable on its own for bespoke seat grids.
//
//  NOTE: this atom predates the copy-on-write modifier convention — its knobs
//  are DEFAULTED init params by design. COW migration deferred to next major.
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
    @Environment(\.theme) private var theme
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

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

    public var body: some View {
        let cellShape = shape.anyShape(cornerRadius: Theme.RadiusRole.selector.value)
        Button(action: action) {
            cellShape
                .fill(fillColor)
                .overlay(cellShape.stroke(strokeColor, lineWidth: strokeWidth))
                .overlay(glyph)
                .overlay(alignment: .topTrailing) { if showsStar { recommendedStar } }
                .frame(width: size, height: size)
                .opacity(isSelectable || isSelected ? 1 : 0.55)
        }
        .buttonStyle(.plain)
        .disabled(!isSelectable && !isSelected)
        .accessibilityLabel(a11yLabel)
        .accessibilityValue(a11yValue)
        .accessibilityHint(isSelectable ? "Double-tap to \(isSelected ? "deselect" : "select")" : "")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var showsStar: Bool { isRecommended && isSelectable && !isSelected }

    // MARK: Content

    @ViewBuilder private var glyph: some View {
        if let customContent {
            customContent(SeatContext(seat: seat, isSelected: isSelected, isOccupied: seat.isOccupied, assignedInitials: assignedInitials))
        } else {
            defaultContent
        }
    }

    @ViewBuilder private var defaultContent: some View {
        switch display {
        case .number:
            Text(seat.id).textStyle(.overline500).foregroundStyle(contentColor)
                .minimumScaleFactor(0.5).lineLimit(1).padding(.horizontal, 2)
        case .initials where assignedInitials != nil:
            Text(assignedInitials ?? "").textStyle(.labelSm600).foregroundStyle(contentColor)
        case .initialsAndNumber:
            VStack(spacing: 0) {
                if let assignedInitials { Text(assignedInitials).textStyle(.labelSm600).foregroundStyle(contentColor) }
                Text(seat.id).textStyle(.overline400).foregroundStyle(contentColor.opacity(0.75))
                    .minimumScaleFactor(0.5).lineLimit(1)
            }
            .padding(.horizontal, 2)
        case .icon, .initials:
            iconGlyph
        }
    }

    // Glyphs step through the type ramp (Dynamic Type for free) instead of
    // hardcoded point sizes.
    @ViewBuilder private var iconGlyph: some View {
        if let assignedInitials {
            Text(assignedInitials).textStyle(.labelSm600).foregroundStyle(contentColor)
        } else if isSelected {
            Image(systemName: "checkmark").textStyle(.labelSm700).foregroundStyle(contentColor)
        } else if seat.isOccupied {
            Image(systemName: "xmark").textStyle(.labelSm600).foregroundStyle(contentColor)
        } else {
            Image(systemName: seat.tier.glyph).textStyle(.labelSm600).foregroundStyle(contentColor)
        }
    }

    private var recommendedStar: some View {
        Image(systemName: recommendedSymbol)
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
            .padding(2)
            .background(theme.background(.bgBase), in: Circle())
            .offset(x: 3, y: -3)
    }

    // MARK: Colours

    private var fillColor: Color {
        if isSelected { return palette.selectedColors(theme: theme).fill }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).fill }
        return palette.colors(for: seat.tier, theme: theme).fill
    }
    private var strokeColor: Color {
        if isSelected {
            return selectionEmphasis == .border ? palette.selectedColors(theme: theme).stroke : .clear
        }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).stroke }
        return palette.colors(for: seat.tier, theme: theme).stroke
    }
    private var strokeWidth: CGFloat {
        guard isSelected else { return 1 }
        return selectionEmphasis == .border ? 2 : 0
    }
    private var contentColor: Color {
        if isSelected { return palette.selectedColors(theme: theme).content }
        if seat.isOccupied { return palette.occupiedColors(theme: theme).content }
        return theme.text(.textSecondary)
    }

    // MARK: Accessibility

    private var a11yLabel: String {
        var s = "Seat \(seat.id)"
        if seat.tier != .standard { s += ", \(seat.tier.label)" }
        return s
    }
    private var a11yValue: String {
        if seat.isOccupied { return "Occupied" }
        if !isSelectable { return "Unavailable" }
        if isSelected { return "Selected" }
        if let price = seat.price { return "Available, \(price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0))))" }
        return "Available"
    }
}

#Preview {
    @Previewable @State var picked = false
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
