//
//  Tag.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. A compact label, optionally removable. Distinct from Badge (status) and
//  Chip (selectable): Tag represents an applied keyword/filter.
//
//  An optional semantic `style` + `variant` colors the tag (Ant Tag colors),
//  reusing Badge's `BadgeStyle` / `FillVariant`. With no `style` it keeps the
//  original neutral keyword look.
//

import SwiftUI

public struct Tag: View {
    private let text: String
    private let leadingSystemImage: String?
    private let style: BadgeStyle?
    private let variant: FillVariant
    private let onRemove: (() -> Void)?

    public init(
        _ text: String,
        leadingSystemImage: String? = nil,
        style: BadgeStyle? = nil,
        variant: FillVariant = .soft,
        onRemove: (() -> Void)? = nil
    ) {
        self.text = text
        self.leadingSystemImage = leadingSystemImage
        self.style = style
        self.variant = variant
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: 12))
            }
            Text(text).textStyle(.labelSm600)
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Remove \(text)"))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(height: 28)
        .background(background, in: Capsule())
        .overlay(Capsule().strokeBorder(border, lineWidth: border == .clear ? 0 : 1))
    }

    private var foreground: Color {
        guard let style else { return Theme.shared.text(.textHero) }
        switch variant {
        case .soft: return style.foreground
        case .solid: return style.semantic.onSolid
        case .outline, .ghost: return style.semantic.accent
        }
    }

    private var background: Color {
        guard let style else { return Theme.shared.background(.bgElevatorTertiary) }
        switch variant {
        case .soft: return style.background
        case .solid: return style.semantic.solid
        case .outline, .ghost: return .clear
        }
    }

    private var border: Color {
        guard let style, variant == .outline else { return .clear }
        return style.semantic.border
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Tag("İstanbul", onRemove: {})
            Tag("Beach", leadingSystemImage: "beach.umbrella")
            Tag("5 stars")
        }
        HStack {
            Tag("Success", style: .success)
            Tag("Warning", style: .warning)
            Tag("Error", style: .error, variant: .solid)
            Tag("Info", style: .info, variant: .outline)
        }
    }
    .padding()
}
