//
//  SeatCell.swift
//  ThemeKit
//
//  Atom. A single seat button — token-bound fill/border by tier + state, a
//  configurable inner label (icon / number / initials / custom) and a recommended
//  star. Composed by ``SeatMap`` but reusable on its own for bespoke seat grids.
//

import SwiftUI

public struct SeatCell: View {
    @Environment(\.theme) private var theme

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
    private let currencyCode: String
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
                currencyCode: String = "TRY",
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
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                .fill(fillColor)
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
                        .stroke(strokeColor, lineWidth: isSelected ? 2 : 1)
                )
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

    @ViewBuilder private var iconGlyph: some View {
        if let assignedInitials {
            Text(assignedInitials).textStyle(.labelSm600).foregroundStyle(contentColor)
        } else if isSelected {
            Image(systemName: "checkmark").font(.system(size: 13, weight: .bold)).foregroundStyle(contentColor)
        } else if seat.isOccupied {
            Image(systemName: "xmark").font(.system(size: 12, weight: .semibold)).foregroundStyle(contentColor)
        } else {
            Image(systemName: seat.tier.glyph).font(.system(size: 13, weight: .semibold)).foregroundStyle(contentColor)
        }
    }

    private var recommendedStar: some View {
        Image(systemName: "star.fill")
            .font(.system(size: 8, weight: .bold))
            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
            .padding(2)
            .background(theme.background(.bgElevatorPrimary), in: Circle())
            .offset(x: 3, y: -3)
    }

    // MARK: Colours

    private var fillColor: Color {
        if isSelected { return theme.foreground(.fgHero) }
        if seat.isOccupied { return theme.background(.bgSecondary) }
        return palette.colors(for: seat.tier, theme: theme).fill
    }
    private var strokeColor: Color {
        if isSelected { return theme.foreground(.fgHero) }
        if seat.isOccupied { return theme.border(.borderPrimary) }
        return palette.colors(for: seat.tier, theme: theme).stroke
    }
    private var contentColor: Color {
        if isSelected { return theme.text(.textSecondaryInverse) }
        if seat.isOccupied { return theme.text(.textTertiary) }
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
        if let price = seat.price { return "Available, \(price.formatted(.currency(code: currencyCode).precision(.fractionLength(0))))" }
        return "Available"
    }
}

#Preview {
    @Previewable @State var picked = false
    HStack(spacing: 8) {
        SeatCell(Seat("1A"), isSelected: picked, action: { picked.toggle() })
        SeatCell(Seat("1B", tier: .business))
        SeatCell(Seat("1C", tier: .exit))
        SeatCell(Seat("1D", occupied: true))
        SeatCell(Seat("1E"), isRecommended: true)
        SeatCell(Seat("1F"), display: .number)
    }
    .padding()
}
