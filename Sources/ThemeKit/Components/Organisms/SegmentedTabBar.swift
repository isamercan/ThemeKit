//
//  SegmentedTabBar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public struct TabItem {
    let title: String
    let caption: String?
    let systemImage: String?
    let trailingSystemImage: String?
    let badge: String?
    let isEnabled: Bool
    public init(_ title: String, caption: String? = nil, systemImage: String? = nil,
                trailingSystemImage: String? = nil, badge: String? = nil, isEnabled: Bool = true) {
        self.title = title; self.caption = caption; self.systemImage = systemImage
        self.trailingSystemImage = trailingSystemImage; self.badge = badge; self.isEnabled = isEnabled
    }
}

/// Visual style of `SegmentedTabBar` (Ant Tabs `type`).
public enum SegmentedTabBarStyle { case underline, card }

/// Tab bar with a selection binding and an animated underline. Tabs can carry an
/// icon, a count badge and a disabled state. (Ant Tabs parity.)
public struct SegmentedTabBar: View {
    @Environment(\.theme) private var theme

    private let items: [TabItem]
    @Binding private var selection: Int
    private let scrollable: Bool
    private let style: SegmentedTabBarStyle
    private let onClose: ((Int) -> Void)?
    private let onAdd: (() -> Void)?
    private var accessibilityID: String? = nil

    @Namespace private var underline
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ items: [TabItem], selection: Binding<Int>, scrollable: Bool = false,
                style: SegmentedTabBarStyle = .underline,
                onClose: ((Int) -> Void)? = nil, onAdd: (() -> Void)? = nil) {
        self.items = items
        self._selection = selection
        self.scrollable = scrollable
        self.style = style
        self.onClose = onClose
        self.onAdd = onAdd
    }

    public init(_ items: [String], selection: Binding<Int>, scrollable: Bool = false,
                style: SegmentedTabBarStyle = .underline,
                onClose: ((Int) -> Void)? = nil, onAdd: (() -> Void)? = nil) {
        self.items = items.map { TabItem($0) }
        self._selection = selection
        self.scrollable = scrollable
        self.style = style
        self.onClose = onClose
        self.onAdd = onAdd
    }

    public var body: some View {
        if scrollable || style == .card {
            ScrollView(.horizontal, showsIndicators: false) { bar }
        } else {
            bar
        }
    }

    private var bar: some View {
        HStack(spacing: style == .card ? Theme.SpacingKey.sm.value : (scrollable ? Theme.SpacingKey.lg.value : 0)) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Group {
                    if style == .card {
                        cardTab(index: index, item: item)
                    } else {
                        tab(index: index, item: item)
                            .frame(maxWidth: scrollable ? nil : .infinity)
                    }
                }
            }
            if style == .card, let onAdd {
                Button(action: onAdd) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(theme.text(.textSecondary))
                        .frame(width: 36, height: 36)
                        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(items.indices.contains(selection) ? items[selection].title : "")
    }

    private func cardTab(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return HStack(spacing: Theme.SpacingKey.xs.value) {
            Button {
                withAnimation(motion) { selection = index }
            } label: {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    if let icon = item.systemImage {
                        Image(systemName: icon).font(.system(size: 13, weight: .semibold))
                    }
                    Text(item.title).textStyle(isActive ? .labelBase700 : .labelBase600)
                    if let badge = item.badge {
                        Text(badge).textStyle(.overline400).foregroundStyle(theme.foreground(.fgSecondary))
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(theme.background(.systemcolorsBgError), in: Capsule())
                    }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            if let onClose {
                Button { onClose(index) } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                        .foregroundStyle(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(
            (isActive ? theme.background(.bgWhite) : theme.background(.bgElevatorTertiary)),
            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(isActive ? theme.border(.borderHero) : theme.border(.borderPrimary), lineWidth: isActive ? 1.5 : 1)
        )
        .disabled(!item.isEnabled)
    }

    private func tab(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return Button {
            withAnimation(motion) { selection = index }
        } label: {
            VStack(spacing: Theme.SpacingKey.sm.value) {
                VStack(spacing: 1) {
                    HStack(spacing: Theme.SpacingKey.xs.value) {
                        if let icon = item.systemImage {
                            Image(systemName: icon).font(.system(size: 14, weight: .semibold))
                        }
                        Text(item.title).textStyle(isActive ? .labelBase700 : .labelBase600)
                        if let trailing = item.trailingSystemImage {
                            Image(systemName: trailing).font(.system(size: 13, weight: .semibold))
                        }
                        if let badge = item.badge {
                            Text(badge)
                                .textStyle(.overline400)
                                .foregroundStyle(theme.foreground(.fgSecondary))
                                .padding(.horizontal, 5).padding(.vertical, 1)
                                .background(theme.background(.systemcolorsBgError), in: Capsule())
                        }
                    }
                    if let caption = item.caption {
                        Text(caption).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))

                ZStack {
                    Capsule().fill(Color.clear).frame(height: 2)
                    if isActive {
                        Capsule()
                            .fill(theme.border(.borderHero))
                            .frame(height: 2)
                            .matchedGeometryEffect(id: "underline", in: underline)
                    }
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textPrimary) : theme.text(.textSecondary)
    }
}

#Preview {
    struct Demo: View {
        @State var sel = 0
        var body: some View {
            VStack(spacing: 24) {
                SegmentedTabBar([TabItem("Overview", systemImage: "square.grid.2x2"),
                                 TabItem("Reviews", badge: "12"),
                                 TabItem("Archived", isEnabled: false)], selection: $sel)
                SegmentedTabBar(["All", "Flights", "Hotels", "Cars", "Tours"], selection: $sel, scrollable: true)
            }
            .padding()
        }
    }
    return Demo()
}

public extension SegmentedTabBar {
    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`). Replaces the `accessibilityID:` init param.
    func a11yID(_ id: String?) -> Self { var copy = self; copy.accessibilityID = id; return copy }
}
