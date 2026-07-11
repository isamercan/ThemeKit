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
/// original neutral keyword look. `.size(.small/.large)` shares Chip's ramp,
/// and `.leading { } / .trailing { }` inject custom content around the text
/// (HeroUI Chip start/end slots).
public struct Tag: View {
    private let text: String
    private let onRemove: (() -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var leadingSystemImage: String?
    private var style: BadgeStyle?
    private var semantic: SemanticColor?   // .color(_) — the broader Ant palette
    private var variant: FillVariant = .soft
    private var bordered = false
    private var size: ChipSize = .small
    private var leadingSlot: AnyView?
    private var trailingSlot: AnyView?
    private var onClose: (() -> Void)?

    @Environment(\.theme) private var theme

    public init(_ text: String, onRemove: (() -> Void)? = nil) {   // R1
        self.text = text
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSlot {
                leadingSlot
            } else if let leadingSystemImage {
                Image(systemName: leadingSystemImage).font(.system(size: iconGlyphSize))
            }
            Text(text).textStyle(labelStyle)
            if let trailingSlot {
                trailingSlot
            }
            if let onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark").font(.system(size: removeGlyphSize, weight: .semibold))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Remove \(text)"))
            }
            if let onClose {
                // The kit CloseButton atom (Ant Tag `closable` + `onClose`).
                // Its 44pt hit slop is bigger than the tag: the fixed frame
                // clamps the *visual* footprint to the mini/small circle while
                // the hit target overflows the capsule (nothing clips it).
                CloseButton(action: onClose)
                    .plain()
                    .controlSize(size == .small ? .mini : .small)
                    .frame(width: closeButtonSide, height: closeButtonSide)
                    .accessibilityLabel(String(themeKit: "Remove \(text)"))
            }
        }
        .foregroundStyle(foreground)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, verticalPadding)
        .background(background, in: Capsule())
        .overlay(Capsule().strokeBorder(border, lineWidth: border == .clear ? 0 : 1))
    }

    // MARK: Size ramp — reuses Chip's `ChipSize`. Paddings derive from spacing
    // tokens (no fixed height), so Dynamic Type grows the capsule instead of
    // clipping the label.

    private var labelStyle: TextStyle {
        size == .small ? .labelSm600 : .labelBase600
    }
    private var horizontalPadding: CGFloat {
        size == .small ? Theme.SpacingKey.sm.value : Theme.SpacingKey.md.value
    }
    private var verticalPadding: CGFloat {
        size == .small ? Theme.SpacingKey.xs.value : Theme.SpacingKey.sm.value
    }
    // Fixed glyph constants for the icon/remove shorthands (no semantic token).
    private var iconGlyphSize: CGFloat { size == .small ? 12 : 14 }
    private var removeGlyphSize: CGFloat { size == .small ? 10 : 12 }
    /// Visual side of the composed `CloseButton` — matches its mini/small
    /// circle diameters so the capsule stays tag-sized.
    private var closeButtonSide: CGFloat { size == .small ? 24 : 28 }

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
    /// Control size: small / large (shares Chip's ``ChipSize`` ramp) — drives
    /// the text style and token-derived paddings.
    func size(_ s: ChipSize) -> Self { copy { $0.size = s } }

    /// Leading SF Symbol.
    func icon(_ systemImage: String?) -> Self { copy { $0.leadingSystemImage = systemImage } }

    /// A custom leading view before the text; when set, it replaces the
    /// `icon` shorthand.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        let view = AnyView(content())
        return copy { $0.leadingSlot = view }
    }

    /// A custom trailing view after the text, before the built-in remove button.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        let view = AnyView(content())
        return copy { $0.trailingSlot = view }
    }

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

    /// Make the tag removable, appending the kit ``CloseButton`` after the
    /// text/trailing slot (Ant Tag `closable` + `onClose`) — the modifier twin
    /// of the `onRemove:` init argument, rendering the standard dismiss atom
    /// (muted glyph + full hit slop) instead of the bare glyph. Pairs best
    /// with the soft / outline variants, where the muted glyph stays legible.
    func closable(_ onClose: @escaping () -> Void) -> Self { copy { $0.onClose = onClose } }

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
            .padding(.vertical, Theme.SpacingKey.xs.value)   // padding-derived height — Dynamic Type never clips
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
        // Size ramp (shares Chip's ChipSize).
        HStack {
            Tag("Small").icon("tag")
            Tag("Large").icon("tag").size(.large)
            Tag("Large removable", onRemove: {}).size(.large).tagStyle(.success)
        }
        // Slots: leading replaces the icon shorthand; trailing renders before
        // the remove button.
        HStack {
            Tag("Online").leading { StatusDot(.online) }
            Tag("Boosted").leading { Image(systemName: "sparkles").font(.system(size: 12)) }
            Tag("Deploys", onRemove: {}).trailing { Text("12").textStyle(.labelSm700) }
        }
        // Closable: the kit CloseButton atom (vs the bare onRemove glyph).
        HStack {
            Tag("Filter").closable {}
            Tag("Nonstop").tagStyle(.info).closable {}
            Tag("Large").size(.large).closable {}
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
        PreviewCase("Large")     { Tag("Filter", onRemove: {}).size(.large) }
        PreviewCase("Leading slot")  { Tag("Online").leading { StatusDot(.online) } }
        PreviewCase("Trailing slot") { Tag("Deploys", onRemove: {}).trailing { Text("12").textStyle(.labelSm700) } }
        PreviewCase("Closable (CloseButton)") { Tag("Filter").closable {} }
        PreviewCase("Long text") { Tag("a-very-long-keyword-value-here") }
    }
}
