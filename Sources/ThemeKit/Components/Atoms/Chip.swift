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
    private var leadingSystemImage: String? = nil
    private var rating: Double? = nil
    private var leadingSlot: AnyView? = nil
    private var trailingSlot: AnyView? = nil
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
            resolvedStyle.makeBody(configuration: ChipStyleConfiguration(
                content: AnyView(labelContent),
                isSelected: isSelected,
                isEnabled: isEnabled && isExist,
                size: size))
                .opacity(isExist ? 1 : 0.6)
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(!isEnabled || !isInteractive || !isExist)
        .allowsHitTesting(isInteractive && isExist)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The enum shorthand resolves to the matching built-in `ChipStyle`;
    /// otherwise the environment style applies — built-ins and custom styles
    /// share the same door.
    private var resolvedStyle: AnyChipStyle {
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
                    Image(systemName: leadingSystemImage).font(.system(size: 14))
                }
                if let rating {
                    HStack(spacing: 2) {
                        Image(systemName: "star.fill").font(.system(size: 11))
                            .foregroundStyle(theme.foreground(.systemcolorsFgWarning))
                        Text(String(format: "%.1f", rating)).textStyle(.labelSm700)
                    }
                }
            }
            Text(title).textStyle(.labelBase600)
                .strikethrough(!isExist, color: theme.text(.textTertiary))
            if let trailingSlot {
                trailingSlot
            }
        }
        .frame(maxWidth: expandsHorizontally ? .infinity : nil)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Chip {
    /// Control size: small / large.
    func size(_ s: ChipSize) -> Self { copy { $0.size = s } }
    /// How a selected chip is filled: tonal / solid. A shorthand for the
    /// built-in ``TonalChipStyle`` / ``SolidChipStyle`` — it overrides the
    /// environment's ``ChipStyle`` for this chip only.
    func chipStyle(_ s: ChipSelectionStyle) -> Self { copy { $0.selectionStyle = s } }
    /// A leading SF Symbol before the title.
    func icon(_ systemName: String?) -> Self { copy { $0.leadingSystemImage = systemName } }
    /// A leading star + numeric rating before the title.
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }
    /// A custom leading view before the title; when set, it replaces the
    /// `icon`/`rating` shorthands.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        let view = AnyView(content())
        return copy { $0.leadingSlot = view }
    }
    /// A custom trailing view after the title.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        let view = AnyView(content())
        return copy { $0.trailingSlot = view }
    }
    /// Whether the represented item still exists; `false` strikes through and dims
    /// the chip (e.g. a sold-out filter).
    func exists(_ on: Bool = true) -> Self { copy { $0.isExist = on } }
    /// Whether the chip responds to taps (a read-only display chip passes `false`).
    @available(*, deprecated, message: "Use .disabled(_:) / allowsHitTesting instead.")
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
        // Environment ChipStyle + slots: `.chipStyle(.solid)` on the container
        // resolves to `SolidChipStyle` via the `View` extension, so both chips
        // inherit it without the enum shorthand.
        HStack {
            Chip("Env solid", isSelected: .constant(true))
            Chip("Slots", isSelected: .constant(false))
                .leading { Image(systemName: "leaf.fill").font(.system(size: 12)) }
                .trailing { Image(systemName: "chevron.down").font(.system(size: 10)) }
        }
        .chipStyle(.solid)
    }
    .padding()
}
