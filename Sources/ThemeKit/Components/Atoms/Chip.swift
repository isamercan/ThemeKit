//
//  Chip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ChipSize {
    case small, large

    var verticalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.sm.value   // 8
        case .large: return 12
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .large: return Theme.SpacingKey.md.value   // 16
        }
    }
}

/// How a selected chip is filled.
public enum ChipSelectionStyle {
    case tonal   // light surface + hero text
    case solid   // hero fill + white text
}

/// Improved, token-bound rewrite of the reference BasicChip — a single clear
/// selection API (tonal / solid) instead of the reference's nested
/// status × mode × fullSelect × isExist matrix.
public struct Chip: View {
    @Environment(\.theme) private var theme

    @Binding private var isSelected: Bool
    private let title: String
    @Environment(\.isEnabled) private var isEnabled
    // Appearance/config — set via chainable modifiers (R2), keeping the common
    // call site to `Chip("x", isSelected: $on)`.
    private var size: ChipSize = .small
    private var selectionStyle: ChipSelectionStyle = .tonal
    private var leadingSystemImage: String? = nil
    private var rating: Double? = nil
    private var isExist: Bool = true
    private var isInteractive: Bool = true
    private var expandsHorizontally: Bool = false

    public init(_ title: String, isSelected: Binding<Bool>) {   // R1
        self.title = title
        self._isSelected = isSelected
    }

    public var body: some View {
        Button {
            isSelected.toggle()
        } label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage).font(.system(size: 14))
                }
                if let rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                    }
                }
                Text(title).textStyle(.labelBase600)
                    .strikethrough(!isExist, color: theme.text(.textTertiary))
            }
            .foregroundStyle(foreground)
            .frame(maxWidth: expandsHorizontally ? .infinity : nil)
            .padding(.horizontal, size.horizontalPadding)
            .padding(.vertical, size.verticalPadding)
            .background(background, in: Capsule())
            .overlay(Capsule().strokeBorder(border, lineWidth: isSelected ? 1.5 : 1))
            .opacity(isExist ? 1 : 0.6)
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(!isEnabled || !isInteractive || !isExist)
        .allowsHitTesting(isInteractive && isExist)
    }

    private var foreground: Color {
        if !isEnabled || !isExist { return theme.text(.textDisabled) }
        guard isSelected else { return theme.text(.textSecondary) }
        switch selectionStyle {
        case .tonal: return theme.text(.textHero)
        case .solid: return theme.foreground(.fgSecondary)
        }
    }

    private var background: Color {
        if !isEnabled || !isExist { return theme.background(.bgSecondaryLight) }
        guard isSelected else { return theme.background(.bgWhite) }
        switch selectionStyle {
        case .tonal: return theme.background(.bgElevatorTertiary)
        case .solid: return theme.background(.bgHero)
        }
    }

    private var border: Color {
        if !isEnabled { return theme.border(.borderPrimary) }
        guard isSelected else { return theme.border(.borderPrimary) }
        switch selectionStyle {
        case .tonal: return theme.border(.borderHero)
        case .solid: return theme.background(.bgHero)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Chip {
    /// Control size: small / large.
    func size(_ s: ChipSize) -> Self { copy { $0.size = s } }
    /// How a selected chip is filled: tonal / solid.
    func chipStyle(_ s: ChipSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// A leading SF Symbol before the title.
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }
    /// A leading star + numeric rating before the title.
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }
    /// Whether the represented item still exists; `false` strikes through and dims
    /// the chip (e.g. a sold-out filter).
    func exists(_ on: Bool = true) -> Self { copy { $0.isExist = on } }
    /// Whether the chip responds to taps (a read-only display chip passes `false`).
    func interactive(_ on: Bool = true) -> Self { copy { $0.isInteractive = on } }
    /// Stretches the chip to fill the available width (e.g. a full-width filter row).
    func expands(_ on: Bool = true) -> Self { copy { $0.expandsHorizontally = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Chip("Default", isSelected: .constant(false))
            Chip("Tonal", isSelected: .constant(true)).chipStyle(.tonal)
            Chip("Solid", isSelected: .constant(true)).chipStyle(.solid)
        }
        HStack {
            Chip("Icon", isSelected: .constant(true)).icon("checkmark")
            Chip("Large", isSelected: .constant(false)).size(.large)
            Chip("Disabled", isSelected: .constant(false)).disabled(true)
        }
    }
    .padding()
}
