//
//  NavigationBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. Floating bottom tab bar. Active item uses a filled glyph + hero
/// underline. Selection owned by the caller.
///
/// Chrome is style-driven: set a ``BarStyle`` with `.barStyle(_:)` and the bar
/// hands its item row to the style as a `.bottom`-edge
/// ``BarStyleConfiguration``. With no style set, the original capsule surface +
/// tab-bar shadow render pixel-identically (that chrome cannot be produced by
/// the stock `DefaultBarStyle`, so the untouched default keeps the legacy
/// capsule). Per-item rendering can be replaced with ``item(_:)``.
public struct NavigationBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.barStyle) private var barStyle

    public struct Item: Identifiable {
        public let id = UUID()
        public let systemImage: String
        public let activeSystemImage: String?
        public let label: String?
        public init(systemImage: String, activeSystemImage: String? = nil, label: String? = nil) {
            self.systemImage = systemImage
            self.activeSystemImage = activeSystemImage
            self.label = label
        }
        /// VoiceOver fallback when no explicit label — the symbol's base name ("house.fill" → "house").
        var accessibilityText: String { label ?? systemImage.split(separator: ".").first.map(String.init) ?? systemImage }
    }

    private let items: [Item]
    @Binding private var selection: Int
    // Appearance — mutated only through the modifiers below (R2).
    private var itemContent: ((Item, Bool) -> AnyView)?

    public init(items: [Item], selection: Binding<Int>) {
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        if barStyle.isDefault {
            // No `.barStyle(_:)` set — the original capsule + tab-bar shadow.
            itemsRow
                .background(theme.background(.bgWhite), in: Capsule())
                .themeShadow(.tabBar)
        } else {
            barStyle.makeBody(configuration: BarStyleConfiguration(leading: nil,
                                                                   content: AnyView(itemsRow),
                                                                   trailing: nil,
                                                                   edge: .bottom))
        }
    }

    private var itemsRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                let isActive = index == selection
                Button {
                    withAnimation(Motion.fast.animation) { selection = index }
                } label: {
                    itemLabel(item, isActive: isActive)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(item.accessibilityText)
                .accessibilityAddTraits(isActive ? .isSelected : [])
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
    }

    /// The custom per-item slot if set, else the stock glyph + hero underline.
    @ViewBuilder
    private func itemLabel(_ item: Item, isActive: Bool) -> some View {
        if let itemContent {
            itemContent(item, isActive)
        } else {
            VStack(spacing: 6) {
                Image(systemName: isActive ? (item.activeSystemImage ?? item.systemImage + ".fill") : item.systemImage)
                    .font(.system(size: 20))
                    .foregroundStyle(isActive ? theme.foreground(.fgHero) : theme.text(.textTertiary))
                Capsule()
                    .fill(isActive ? theme.background(.bgHero) : .clear)
                    .frame(width: 20, height: 3)
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension NavigationBar {
    /// Replace each item's rendering with custom content. The builder receives
    /// the ``Item`` and whether it is the active tab; tap handling, hit area
    /// and accessibility labels/traits stay with the bar.
    func item<V: View>(@ViewBuilder _ content: @escaping (NavigationBar.Item, Bool) -> V) -> Self {
        copy { bar in bar.itemContent = { item, isActive in AnyView(content(item, isActive)) } }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var sel = 1
        let items: [NavigationBar.Item] = [
            .init(systemImage: "house", label: "Home"),
            .init(systemImage: "heart", label: "Saved"),
            .init(systemImage: "bag", label: "Trips"),
            .init(systemImage: "person", label: "Profile"),
        ]
        var body: some View {
            PreviewMatrix("NavigationBar") {
                PreviewCase("Default capsule chrome") {
                    NavigationBar(items: items, selection: $sel)
                }
                PreviewCase("Custom item slot") {
                    NavigationBar(items: items, selection: $sel)
                        .item { item, isActive in
                            VStack(spacing: 4) {
                                Image(systemName: item.systemImage)
                                    .font(.system(size: 18, weight: isActive ? .semibold : .regular))
                                if let label = item.label {
                                    Text(label).textStyle(.overline500)
                                }
                            }
                            .opacity(isActive ? 1 : 0.5)
                        }
                }
                PreviewCase("Floating bar style") {
                    NavigationBar(items: items, selection: $sel)
                        .barStyle(.floating)
                }
            }
        }
    }
    return Demo()
}
