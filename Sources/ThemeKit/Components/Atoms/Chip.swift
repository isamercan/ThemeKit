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
    @Binding private var isSelected: Bool
    private let title: String
    private let size: ChipSize
    private let selectionStyle: ChipSelectionStyle
    private let leadingSystemImage: String?
    private let rating: Double?
    private let isExist: Bool
    private let isInteractive: Bool
    private let expandsHorizontally: Bool
    private let isEnabled: Bool

    public init(
        _ title: String,
        isSelected: Binding<Bool>,
        size: ChipSize = .small,
        selectionStyle: ChipSelectionStyle = .tonal,
        leadingSystemImage: String? = nil,
        rating: Double? = nil,
        isExist: Bool = true,
        isInteractive: Bool = true,
        expandsHorizontally: Bool = false,
        isEnabled: Bool = true
    ) {
        self.title = title
        self._isSelected = isSelected
        self.size = size
        self.selectionStyle = selectionStyle
        self.leadingSystemImage = leadingSystemImage
        self.rating = rating
        self.isExist = isExist
        self.isInteractive = isInteractive
        self.expandsHorizontally = expandsHorizontally
        self.isEnabled = isEnabled
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
                            .foregroundStyle(Theme.shared.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                    }
                }
                Text(title).textStyle(.labelBase600)
                    .strikethrough(!isExist, color: Theme.shared.text(.textTertiary))
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
        if !isEnabled || !isExist { return Theme.shared.text(.textDisabled) }
        guard isSelected else { return Theme.shared.text(.textSecondary) }
        switch selectionStyle {
        case .tonal: return Theme.shared.text(.textHero)
        case .solid: return Theme.shared.foreground(.fgSecondary)
        }
    }

    private var background: Color {
        if !isEnabled || !isExist { return Theme.shared.background(.bgSecondaryLight) }
        guard isSelected else { return Theme.shared.background(.bgWhite) }
        switch selectionStyle {
        case .tonal: return Theme.shared.background(.bgElevatorTertiary)
        case .solid: return Theme.shared.background(.bgHero)
        }
    }

    private var border: Color {
        if !isEnabled { return Theme.shared.border(.borderPrimary) }
        guard isSelected else { return Theme.shared.border(.borderPrimary) }
        switch selectionStyle {
        case .tonal: return Theme.shared.border(.borderHero)
        case .solid: return Theme.shared.background(.bgHero)
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack {
            Chip("Default", isSelected: .constant(false))
            Chip("Tonal", isSelected: .constant(true), selectionStyle: .tonal)
            Chip("Solid", isSelected: .constant(true), selectionStyle: .solid)
        }
        HStack {
            Chip("Icon", isSelected: .constant(true), leadingSystemImage: "checkmark")
            Chip("Large", isSelected: .constant(false), size: .large)
            Chip("Disabled", isSelected: .constant(false), isEnabled: false)
        }
    }
    .padding()
}
