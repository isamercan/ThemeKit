//
//  ThemePicker.swift
//  ThemeKit
//  Created by İsa Mercan on 29.06.2026.
//
//  A theme-preset gallery: a grid of self-contained preview cards (each
//  painted in its OWN theme's colors), tap to switch the live theme. Reusable — drop it into any screen.
//

import SwiftUI

/// A grid of `ThemePreset` preview cards. Tapping a card calls `onSelect` (which
/// applies the theme by default) and marks it active.
///
/// ```swift
/// @State var active: String? = "dracula"
/// ThemePicker(selection: $active)            // applies to Theme.shared on tap
/// ```
public struct ThemePicker: View {
    @Environment(\.theme) private var theme

    @Binding private var selection: String?
    private let themes: [ThemePreset]
    private let onSelect: (ThemePreset) -> Void

    /// - Parameters:
    ///   - selection: the active theme `id`; updated on tap.
    ///   - themes: the catalog to show (defaults to all presets).
    ///   - onSelect: tap handler. Defaults to applying the theme to `Theme.shared`.
    public init(
        selection: Binding<String?>,
        themes: [ThemePreset] = ThemePreset.all,
        onSelect: ((ThemePreset) -> Void)? = nil
    ) {
        self._selection = selection
        self.themes = themes
        self.onSelect = onSelect ?? { $0.apply() }
    }

    private let columns = [GridItem(.adaptive(minimum: 160, maximum: 240), spacing: 12)]

    public var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(themes) { item in
                Button {
                    selection = item.id
                    onSelect(item)
                } label: {
                    ThemeCard(theme: item, isActive: selection == item.id)
                }
                .buttonStyle(PressFeedbackStyle())
                .a11y(A11yElement.Action.button, in: "theme.\(item.id)")
                .accessibilityLabel(item.name)
                .accessibilityAddTraits(selection == item.id ? [.isSelected, .isButton] : .isButton)
            }
        }
    }
}

/// One theme tile — painted entirely in its OWN theme's colors (a faithful preview), independent of the currently active theme.
private struct ThemeCard: View {
    let theme: ThemePreset
    let isActive: Bool

    /// Readable foreground on the theme's base surface.
    private var content: Color { theme.isDark ? .white : .black }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(theme.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(content)
                Spacer(minLength: 4)
                if isActive {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: theme.base))
                        .frame(width: 20, height: 20)
                        .background(theme.primaryColor, in: Circle())
                }
            }

            // Swatch row — primary / secondary / accent / neutral chips.
            HStack(spacing: 6) {
                ForEach(Array(theme.swatches.prefix(3).enumerated()), id: \.offset) { _, c in
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(c)
                        .frame(height: 28)
                        .frame(maxWidth: .infinity)
                }
            }

            // A mini button + text sample, like a theme-gallery card.
            HStack(spacing: 6) {
                Text("Aa")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(content.opacity(0.7))
                Spacer(minLength: 0)
                Text(theme.isDark ? "dark" : "light")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.isDark ? .black : .white)
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(theme.primaryColor, in: Capsule())
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: theme.base), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isActive ? theme.primaryColor : content.opacity(0.12),
                              lineWidth: isActive ? 2.5 : 1)
        )
        .animation(Motion.fast.animation, value: isActive)
    }
}

#Preview {
    struct Demo: View {
        @State var active: String? = "dracula"
        var body: some View {
            ScrollView {
                ThemePicker(selection: $active, onSelect: { active = $0.id })
                    .padding()
            }
        }
    }
    return Demo()
}
