//
//  Chip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ChipSize {
    case small, medium, large

    var verticalPadding: CGFloat {
        switch self {
        case .small: return Theme.SpacingKey.sm.value   // 8
        case .medium: return 10                          // ramp midpoint (no token between sm and 12)
        case .large: return 12
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 14                          // ramp midpoint
        case .large: return Theme.SpacingKey.md.value   // 16
        }
    }
    /// Enforced capsule min-height per tier (HeroUI Chip `sm/md/lg` fixed
    /// heights) so mixed-content chips align on a row; `.large` reaches the
    /// 44pt hit target. Applied via `scaledControlHeight`, so Dynamic Type
    /// still grows the capsule instead of clipping.
    var minHeight: CGFloat {
        switch self {
        case .small: return 36
        case .medium: return 40
        case .large: return 44
        }
    }
}

/// How a selected chip is filled.
public enum ChipSelectionStyle {
    case tonal   // light surface + hero text
    case solid   // hero fill + white text
}

/// The chip's semantic hue — the HeroUI V3 Chip **Type** axis. Maps onto the
/// kit's ``SemanticColor`` so an injected `.theme(_:)` re-skins it. Set with
/// ``Chip/type(_:)``; pair with ``ChipVariant`` for the emphasis level. When
/// unset the chip keeps its selection-based tonal/solid look.
public enum ChipType: Sendable {
    case accent    // HeroUI "accent"  → SemanticColor.primary (brand hero)
    case neutral   // HeroUI "default" → SemanticColor.neutral
    case success   // → .success
    case warning   // → .warning
    case danger    // HeroUI "danger"  → SemanticColor.error

    /// The kit ``SemanticColor`` this type resolves through.
    var semantic: SemanticColor {
        switch self {
        case .accent: return .primary
        case .neutral: return .neutral
        case .success: return .success
        case .warning: return .warning
        case .danger: return .error
        }
    }
}

/// The emphasis level of a semantic chip — the HeroUI V3 Chip **Variant** axis.
/// Only takes effect once a ``ChipType`` is set (see ``Chip/type(_:)``).
public enum ChipVariant: Sendable {
    case primary     // high emphasis: solid type fill + contrasting text
    case secondary   // medium: neutral surface + type-accent text
    case tertiary    // low: transparent + type-accent text
    case soft        // subtle: type-tinted surface + type-accent text
}

/// Improved, token-bound rewrite of the reference BasicChip — a single clear
/// selection API (tonal / solid) instead of the reference's nested
/// status × mode × fullSelect × isExist matrix.
///
/// Chroma is drawn by the active ``ChipStyle``: the environment style set with
/// `.chipStyle(_:)` on any ancestor, or — when the enum shorthand
/// `.chipStyle(.tonal / .solid)` is used on the chip itself — the matching
/// built-in ``TonalChipStyle`` / ``SolidChipStyle``. Both paths go through the
/// same `ChipStyle.makeBody` gate.
public struct Chip: View {
    @Environment(\.theme) private var theme
    @Environment(\.chipStyle) private var environmentChipStyle

    @Binding private var isSelected: Bool
    private let title: String
    @Environment(\.isEnabled) private var isEnabled
    // Appearance/config — set via chainable modifiers (R2), keeping the common
    // call site to `Chip("x", isSelected: $on)`.
    private var size: ChipSize = .small
    private var selectionStyle: ChipSelectionStyle? = nil   // nil → environment style
    private var chipType: ChipType? = nil                   // set → HeroUI semantic chroma
    private var chipVariant: ChipVariant = .primary
    private var leadingSystemImage: String? = nil
    private var rating: Double? = nil
    private var leadingSlot: SlotContent? = nil
    private var trailingSlot: SlotContent? = nil
    private var onClose: (() -> Void)? = nil
    private var isExist: Bool = true
    private var isInteractive: Bool = true
    private var expandsHorizontally: Bool = false
    /// `true` for the selectable filter pill (`init(_:isSelected:)`); `false`
    /// for the static status/label chip (`init(_:)`), which drops the toggle
    /// button so a `.onClose` affordance stays independently tappable.
    private var isSelectable: Bool = true

    public init(_ title: String, isSelected: Binding<Bool>) {   // R1
        self.title = title
        self._isSelected = isSelected
    }

    /// A static status/label chip (HeroUI V3 badge-style) — no selection state.
    /// Pair with ``type(_:)`` / ``variant(_:)`` for semantic chroma and
    /// ``onClose(_:)`` for a trailing dismiss.
    public init(_ title: String) {   // R1 — status chip, no binding
        self.title = title
        self._isSelected = .constant(false)
        self.isSelectable = false
    }

    public var body: some View {
        if isSelectable {
            Button {
                isSelected.toggle()
            } label: {
                styledContent
            }
            .buttonStyle(PressFeedbackStyle())
            .disabled(!isEnabled || !isInteractive || !isExist)
            .allowsHitTesting(isInteractive && isExist)
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            // Status chip: no toggle wrapper — the `.onClose` button (if any)
            // owns its own hit target inside the capsule.
            styledContent
        }
    }

    /// The chroma-wrapped content, shared by both the selectable and status paths.
    private var styledContent: some View {
        resolvedStyle.makeBody(configuration: ChipStyleConfiguration(
            content: AnyView(labelContent),
            isSelected: isSelected,
            isEnabled: isEnabled && isExist,
            size: size))
            .opacity(isExist ? 1 : 0.6)
    }

    /// A ``ChipType`` routes through the semantic HeroUI chroma; otherwise the
    /// enum shorthand resolves to the matching built-in `ChipStyle`, else the
    /// environment style applies — all built-ins and custom styles share the
    /// same door.
    private var resolvedStyle: AnyChipStyle {
        if let chipType {
            return AnyChipStyle(SemanticChipStyle(type: chipType, variant: chipVariant))
        }
        switch selectionStyle {
        case .tonal: return AnyChipStyle(TonalChipStyle())
        case .solid: return AnyChipStyle(SolidChipStyle())
        case nil: return environmentChipStyle
        }
    }

    /// The chip's content (chroma-free): leading slot — or the icon/rating
    /// shorthands — then the title, then the trailing slot.
    private var labelContent: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            if let leadingSlot {
                leadingSlot
            } else {
                if let leadingSystemImage {
                    Image(systemName: leadingSystemImage).font(.system(size: iconGlyphSize))
                }
                if let rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                    }
                }
            }
            Text(title).textStyle(titleTextStyle)
                .strikethrough(!isExist, color: theme.text(.textTertiary))
            if let trailingSlot {
                trailingSlot
            }
            if let onClose {
                // HeroUI suffix dismiss (`×`). A nested plain Button keeps its
                // own hit target even inside the selectable path's toggle button
                // (same nesting `ChipGroup.removable` already ships).
                Button { onClose() } label: {
                    Image(systemName: "xmark").font(.system(size: closeGlyphSize, weight: .semibold))
                }
                .buttonStyle(.plain)
                // Include the chip title so VoiceOver distinguishes each close
                // button when several closable chips share a row (matches Tag /
                // ChipGroup.removable).
                .accessibilityLabel(String(themeKit: "Remove \(title)"))
            }
        }
        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
        // Enforce the tier's min-height from inside the style's padding, so the
        // capsule (content + 2 × verticalPadding) lands on the ChipSize ramp
        // (C3) — for custom `ChipStyle`s the content still carries the floor.
        // The floor is ~20pt across sizes, so `SemanticChipStyle`'s compact
        // outer padding lands the HeroUI 20/24/28pt heights on top of it.
        .scaledControlHeight(size.minHeight - size.verticalPadding * 2)
    }

    /// The title's text style. Semantic (status) chips follow the HeroUI ramp
    /// (12pt on sm/md, 14pt on lg); the selectable filter pill keeps its 14pt
    /// label unchanged.
    private var titleTextStyle: TextStyle {
        guard chipType != nil else { return .labelBase600 }
        switch size {
        case .small, .medium: return .labelSm600
        case .large: return .labelBase600
        }
    }
    /// Leading SF Symbol size — HeroUI icon slots are 12/12/14pt in semantic
    /// mode; the selectable pill keeps its fixed 14pt glyph.
    private var iconGlyphSize: CGFloat {
        guard chipType != nil else { return 14 }
        switch size {
        case .small, .medium: return 12
        case .large: return 14
        }
    }
    /// Trailing dismiss glyph size, scaled to the tier.
    private var closeGlyphSize: CGFloat {
        switch size {
        case .small: return 10
        case .medium: return 11
        case .large: return 12
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Chip {
    /// Control size: small / medium / large — drives paddings and the enforced
    /// min-height ramp (36 / 40 / 44pt at the default text size).
    func size(_ s: ChipSize) -> Self { copy { $0.size = s } }
    /// How a selected chip is filled: tonal / solid. A shorthand for the
    /// built-in ``TonalChipStyle`` / ``SolidChipStyle`` — it overrides the
    /// environment's ``ChipStyle`` for this chip only.
    func chipStyle(_ s: ChipSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// Semantic hue — the HeroUI V3 Chip **Type** (accent / neutral / success /
    /// warning / danger). Setting it switches the chip to the semantic status
    /// chroma (``SemanticChipStyle``) at the current ``variant(_:)``, overriding
    /// the tonal/solid selection look and any environment ``ChipStyle``.
    func type(_ t: ChipType) -> Self { copy { $0.chipType = t } }
    /// Emphasis level of a semantic chip — the HeroUI V3 Chip **Variant**
    /// (primary / secondary / tertiary / soft). No effect until ``type(_:)`` is set.
    func variant(_ v: ChipVariant) -> Self { copy { $0.chipVariant = v } }
    /// A trailing dismiss (`×`) button (HeroUI suffix remove). The callback
    /// fires on tap; `nil` removes it.
    func onClose(_ action: (() -> Void)?) -> Self { copy { $0.onClose = action } }
    /// A leading SF Symbol before the title.
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }
    /// A leading star + numeric rating before the title.
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }
    /// A custom leading view before the title; when set, it replaces the
    /// `icon`/`rating` shorthands.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingSlot = SlotContent(content) }
    }
    /// A custom trailing view after the title.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingSlot = SlotContent(content) }
    }
    /// Whether the represented item still exists; `false` strikes through and dims
    /// the chip (e.g. a sold-out filter).
    func exists(_ on: Bool = true) -> Self { copy { $0.isExist = on } }
    /// Whether the chip responds to taps (a read-only display chip passes `false`).
    @available(*, deprecated, message: "Use .disabled(_:) / allowsHitTesting instead.")
    func interactive(_ on: Bool = true) -> Self { copy { $0.isInteractive = on } }
    /// Stretches the chip to fill the available width (e.g. a full-width filter row).
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.expandsHorizontally = on } }
    /// Stretches the chip to fill the available width (e.g. a full-width filter row).
    @available(*, deprecated, renamed: "fullWidth")
    func expands(_ on: Bool = true) -> Self { fullWidth(on) }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Chip") {
        PreviewCase("Selection styles") {
            HStack {
                Chip("Default", isSelected: .constant(false))
                Chip("Tonal", isSelected: .constant(true)).chipStyle(.tonal)
                Chip("Solid", isSelected: .constant(true)).chipStyle(.solid)
            }
        }
        PreviewCase("Icon / large / disabled") {
            HStack {
                Chip("Icon", isSelected: .constant(true)).icon("checkmark")
                Chip("Large", isSelected: .constant(false)).size(.large)
                Chip("Disabled", isSelected: .constant(false)).disabled(true)
            }
        }
        // C3 — size ramp with enforced min-heights: mixed-content chips align.
        PreviewCase("Size ramp") {
            HStack(alignment: .center) {
                Chip("Small", isSelected: .constant(false)).size(.small)
                Chip("Medium", isSelected: .constant(false)).size(.medium)
                Chip("Medium + icon", isSelected: .constant(true)).size(.medium).icon("star")
                Chip("Large", isSelected: .constant(false)).size(.large)
            }
        }
        // Environment ChipStyle + slots: `.chipStyle(.solid)` on the container
        // resolves to `SolidChipStyle` via the `View` extension, so both chips
        // inherit it without the enum shorthand.
        PreviewCase("Environment style + slots") {
            HStack {
                Chip("Env solid", isSelected: .constant(true))
                Chip("Slots", isSelected: .constant(false))
                    .leading { Image(systemName: "leaf.fill").font(.system(size: 12)) }
                    .trailing { Image(systemName: "chevron.down").font(.system(size: 10)) }
            }
            .chipStyle(.solid)
        }
        PreviewCase("Sold out / long text") {
            HStack {
                Chip("Sold out", isSelected: .constant(false)).exists(false)
                Chip("a-very-long-filter-value-here", isSelected: .constant(false))
            }
        }
        // HeroUI V3 status chips: static `Chip("…")`, no binding. The Type axis.
        PreviewCase("Types (primary)") {
            HStack {
                Chip("Accent").type(.accent)
                Chip("Default").type(.neutral)
                Chip("Success").type(.success)
                Chip("Warning").type(.warning)
                Chip("Danger").type(.danger)
            }
        }
        // The Variant (emphasis) axis, one type across all four levels.
        PreviewCase("Variants (accent)") {
            HStack {
                Chip("Primary").type(.accent).variant(.primary)
                Chip("Secondary").type(.accent).variant(.secondary)
                Chip("Tertiary").type(.accent).variant(.tertiary)
                Chip("Soft").type(.accent).variant(.soft)
            }
        }
        // Compact HeroUI size ramp (20 / 24 / 28pt) + prefix icon + dismiss.
        PreviewCase("Status: sizes / icon / close") {
            HStack {
                Chip("Small").type(.success).variant(.soft).size(.small)
                Chip("Medium").type(.success).variant(.soft).size(.medium)
                Chip("Large").type(.success).variant(.soft).size(.large).icon("checkmark")
                Chip("Dismiss").type(.danger).variant(.soft).onClose {}
            }
        }
    }
}
