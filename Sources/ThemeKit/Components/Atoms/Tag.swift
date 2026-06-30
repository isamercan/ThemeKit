//
//  Tag.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A compact label, optionally removable. Distinct from Badge (status) and
/// Chip (selectable): Tag represents an applied keyword/filter.
/// An optional semantic `.tagStyle` + `.variant` colors the tag (Ant Tag colors),
/// reusing Badge's `BadgeStyle` / `FillVariant`. With no style it keeps the
/// original neutral keyword look.
public struct Tag: View {
    private let text: String
    private let onRemove: (() -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var leadingSystemImage: String?
    private var style: BadgeStyle?
    private var variant: FillVariant = .soft

    @Environment(\.theme) private var theme

    public init(_ text: String, onRemove: (() -> Void)? = nil) {   // R1
        self.text = text
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
        guard let style else { return theme.text(.textHero) }
        switch variant {
        case .soft: return style.foreground(theme)
        case .solid: return style.semantic.onSolid
        case .outline, .ghost: return style.semantic.accent
        }
    }

    private var background: Color {
        guard let style else { return theme.background(.bgElevatorTertiary) }
        switch variant {
        case .soft: return style.background(theme)
        case .solid: return style.semantic.solid
        case .outline, .ghost: return .clear
        }
    }

    private var border: Color {
        guard let style, variant == .outline else { return .clear }
        return style.semantic.border
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Tag {
    /// Leading SF Symbol.
    func icon(_ systemImage: String?) -> Self { copy { $0.leadingSystemImage = systemImage } }

    /// Semantic color treatment (Ant Tag colors). `nil` keeps the neutral keyword look.
    func tagStyle(_ s: BadgeStyle?) -> Self { copy { $0.style = s } }

    /// Fill variant: soft / solid / outline / ghost.
    func variant(_ v: FillVariant) -> Self { copy { $0.variant = v } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        HStack {
            Tag("Istanbul", onRemove: {})
            Tag("Beach").icon("beach.umbrella")
            Tag("5 stars")
        }
        HStack {
            Tag("Success").tagStyle(.success)
            Tag("Warning").tagStyle(.warning)
            Tag("Error").tagStyle(.error).variant(.solid)
            Tag("Info").tagStyle(.info).variant(.outline)
        }
    }
    .padding()
}

#Preview("States") {
    PreviewMatrix("Tag", dynamicType: true) {
        PreviewCase("Default")   { Tag("React") }
        PreviewCase("Removable") { Tag("Filter", onRemove: {}) }
        PreviewCase("With icon") { Tag("Beach").icon("beach.umbrella") }
        PreviewCase("Semantic")  { Tag("Error").tagStyle(.error).variant(.solid) }
        PreviewCase("Long text") { Tag("a-very-long-keyword-value-here") }
    }
}
