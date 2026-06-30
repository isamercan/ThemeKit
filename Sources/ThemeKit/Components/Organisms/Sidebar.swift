//
//  Sidebar.swift
//  ThemeKit
//  Created by İsa Mercan on 30.06.2026.
//

import SwiftUI

/// Organism. A token-bound vertical navigation sidebar — the companion to the
/// bottom `NavigationBar`, for the wider layouts ThemeKit also targets (macOS /
/// iPad / regular width). Items are grouped into optional titled sections; the
/// selected item is tinted with the theme's accent. Selection is owned by the
/// caller via a `String` tag.
///
///     Sidebar(sections: [
///         .init(items: [.init(tag: "home", "Home", systemImage: "house")]),
///         .init("Library", items: [
///             .init(tag: "fav", "Favorites", systemImage: "heart", badge: 3),
///             .init(tag: "down", "Downloads", systemImage: "arrow.down.circle"),
///         ]),
///     ], selection: $tab)
///     .header { BrandMark() }
///     .width(260)
public struct Sidebar: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    /// A single selectable navigation row.
    public struct Item: Identifiable {
        public let id = UUID()
        let tag: String
        let label: String
        let systemImage: String?
        let badge: Int?
        public init(tag: String, _ label: String, systemImage: String? = nil, badge: Int? = nil) {
            self.tag = tag
            self.label = label
            self.systemImage = systemImage
            self.badge = badge
        }
    }

    /// A group of items with an optional overline title.
    public struct Section: Identifiable {
        public let id = UUID()
        let title: String?
        let items: [Item]
        public init(_ title: String? = nil, items: [Item]) {
            self.title = title
            self.items = items
        }
    }

    private let sections: [Section]
    @Binding private var selection: String?

    // Appearance — mutated only through the modifiers below (R2).
    private var header: AnyView?
    private var footer: AnyView?
    private var explicitWidth: CGFloat?
    private var accessibilityID: String?

    public init(sections: [Section], selection: Binding<String?>) {   // R1
        self.sections = sections
        self._selection = selection
    }

    /// Convenience: a single untitled section.
    public init(items: [Item], selection: Binding<String?>) {
        self.init(sections: [Section(items: items)], selection: selection)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            if let header {
                header.padding(.horizontal, Theme.SpacingKey.sm.value)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
                    ForEach(sections, id: \.id) { section in sectionView(section) }
                }
            }
            if let footer {
                Spacer(minLength: 0)
                footer.padding(.horizontal, Theme.SpacingKey.sm.value)
            }
        }
        .padding(Theme.SpacingKey.sm.value)
        .frame(width: explicitWidth, alignment: .leading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(theme.background(.bgWhite))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(accessibilityID ?? "")
    }

    @ViewBuilder
    private func sectionView(_ section: Section) -> some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
            if let title = section.title {
                Text(title)
                    .textStyle(.overline500)
                    .foregroundStyle(theme.text(.textTertiary))
                    .padding(.horizontal, Theme.SpacingKey.sm.value)
                    .padding(.top, Theme.SpacingKey.xs.value)
            }
            ForEach(section.items, id: \.id) { item in row(item) }
        }
    }

    @ViewBuilder
    private func row(_ item: Item) -> some View {
        let isActive = item.tag == selection
        Button {
            withAnimation(motion) { selection = item.tag }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let systemImage = item.systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 16, weight: isActive ? .semibold : .regular))
                        .foregroundStyle(isActive ? theme.foreground(.fgHero) : theme.text(.textSecondary))
                        .frame(width: 22)
                }
                Text(item.label)
                    .textStyle(isActive ? .labelMd700 : .bodyBase400)
                    .foregroundStyle(isActive ? theme.text(.textHero) : theme.text(.textPrimary))
                Spacer(minLength: 0)
                if let badge = item.badge, badge > 0 {
                    Text("\(badge)")
                        .textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textHero))
                        .padding(.horizontal, Theme.SpacingKey.xs.value)
                        .padding(.vertical, 1)
                        .background(theme.background(.bgSecondaryLight), in: Capsule())
                }
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .scaledControlHeight(40)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                    .fill(isActive ? theme.background(.bgSecondaryLight) : .clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.label)
        .accessibilityAddTraits(isActive ? [.isButton, .isSelected] : .isButton)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Sidebar {
    /// A custom view pinned above the navigation list (brand mark, profile…).
    func header(@ViewBuilder _ content: () -> some View) -> Self {
        let v = AnyView(content())
        return copy { $0.header = v }
    }

    /// A custom view pinned to the bottom of the sidebar (settings, sign-out…).
    func footer(@ViewBuilder _ content: () -> some View) -> Self {
        let v = AnyView(content())
        return copy { $0.footer = v }
    }

    /// Fixed sidebar width (defaults to flexible / parent-driven).
    func width(_ width: CGFloat?) -> Self { copy { $0.explicitWidth = width } }

    /// Stable accessibility identifier for the sidebar container.
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var tab: String? = "home"
        var body: some View {
            Sidebar(sections: [
                .init(items: [
                    .init(tag: "home", "Home", systemImage: "house"),
                    .init(tag: "search", "Search", systemImage: "magnifyingglass"),
                ]),
                .init("Library", items: [
                    .init(tag: "fav", "Favorites", systemImage: "heart", badge: 3),
                    .init(tag: "down", "Downloads", systemImage: "arrow.down.circle"),
                ]),
            ], selection: $tab)
            .width(260)
            .frame(height: 480)
        }
    }
    return Demo()
}
