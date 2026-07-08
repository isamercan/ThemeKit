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
    private var semantic: SemanticColor?   // .color(_) — the broader Ant palette
    private var variant: FillVariant = .soft
    private var bordered = false

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
        if let semantic {
            switch variant {
            case .soft, .outline, .ghost: return semantic.accent
            case .solid: return semantic.onSolid
            }
        }
        guard let style else { return theme.text(.textHero) }
        switch variant {
        case .soft: return style.foreground(theme)
        case .solid: return style.semantic.onSolid
        case .outline, .ghost: return style.semantic.accent
        }
    }

    private var background: Color {
        if let semantic {
            switch variant {
            case .soft: return semantic.soft
            case .solid: return semantic.solid
            case .outline, .ghost: return .clear
            }
        }
        guard let style else { return theme.background(.bgElevatorTertiary) }
        switch variant {
        case .soft: return style.background(theme)
        case .solid: return style.semantic.solid
        case .outline, .ghost: return .clear
        }
    }

    /// Outline is always bordered; `.bordered()` opts soft/solid tags into a hairline too (Ant `bordered`).
    private var border: Color {
        let hue = semantic ?? style?.semantic
        guard let hue else { return bordered ? theme.border(.borderPrimary) : .clear }
        if variant == .outline { return hue.border }
        return bordered ? hue.border : .clear
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

    /// Color the tag from the full semantic palette (Ant Tag `color`) — reaches hues
    /// beyond ``tagStyle(_:)``'s status set (e.g. `.turquoise`, `.purple`, `.pink`).
    /// Takes precedence over ``tagStyle(_:)``.
    func color(_ color: SemanticColor) -> Self { copy { $0.semantic = color } }

    /// Add a hairline border to a soft/solid tag (Ant `bordered`). Outline is always bordered.
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Ant's **CheckableTag** — a tag that toggles a bound boolean, like a lightweight
/// selectable filter. Unchecked is a neutral pill; checked fills with `.color` (hero
/// by default). For rich multi-select filters prefer `Chip`; this mirrors Ant 1:1.
public struct CheckableTag: View {
    @Environment(\.theme) private var theme

    private let text: String
    @Binding private var isChecked: Bool
    // Appearance — mutated only through the modifiers below (R2).
    private var leadingSystemImage: String?
    private var color: SemanticColor = .primary

    public init(_ text: String, isChecked: Binding<Bool>) {   // R1
        self.text = text
        self._isChecked = isChecked
    }

    public var body: some View {
        Button { isChecked.toggle() } label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage).font(.system(size: 12))
                }
                Text(text).textStyle(.labelSm600)
            }
            .foregroundStyle(isChecked ? color.onSolid : theme.text(.textSecondary))
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .frame(height: 28)
            .background(isChecked ? color.solid : theme.background(.bgElevatorTertiary), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isChecked ? .isSelected : [])
    }
}

public extension CheckableTag {
    /// Leading SF Symbol.
    func icon(_ systemImage: String?) -> Self { copy { $0.leadingSystemImage = systemImage } }
    /// Fill color when checked (Ant CheckableTag stays hero; override per brand).
    func color(_ color: SemanticColor) -> Self { copy { $0.color = color } }

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
        HStack {
            Tag("Turquoise").color(.turquoise)
            Tag("Purple").color(.purple).bordered()
            Tag("Pink").color(.pink).variant(.solid)
        }
        CheckableTagRow()
    }
    .padding()
}

private struct CheckableTagRow: View {
    @State private var a = true
    @State private var b = false
    var body: some View {
        HStack {
            CheckableTag("Nonstop", isChecked: $a)
            CheckableTag("Morning", isChecked: $b).icon("sunrise")
        }
    }
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
