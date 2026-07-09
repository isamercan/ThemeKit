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

/// Visual style of `SegmentedTabBar` (Ant Tabs `type`; `.pill` = daisyUI `tabs-box`).
public enum SegmentedTabBarStyle { case underline, card, pill }

/// Where a scrollable bar parks the selected tab after a selection change
/// (HeroUI Tabs.ScrollView `scrollAlign`). `.none` disables auto-scrolling.
public enum TabScrollAlignment {
    case start, center, end, none

    /// The `ScrollViewProxy` anchor for this alignment, or `nil` for `.none`.
    /// `UnitPoint` is physical and `scrollTo` doesn't mirror, so start/end
    /// resolve against the layout direction — `.start` always means the
    /// leading edge (the visual right under RTL).
    func anchor(_ direction: LayoutDirection) -> UnitPoint? {
        let rtl = direction == .rightToLeft
        switch self {
        case .start: return UnitPoint(x: rtl ? 1 : 0, y: 0.5)
        case .center: return .center
        case .end: return UnitPoint(x: rtl ? 0 : 1, y: 0.5)
        case .none: return nil
        }
    }
}

/// Tab bar with a selection binding and an animated underline. Tabs can carry an
/// icon, a count badge and a disabled state. (Ant Tabs parity.)
public struct SegmentedTabBar: View {
    @Environment(\.theme) private var theme

    private let items: [TabItem]
    @Binding private var selection: Int
    private let onClose: ((Int) -> Void)?
    private let onAdd: (() -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var scrollable: Bool = false
    private var style: SegmentedTabBarStyle = .underline
    private var scrollAlignment: TabScrollAlignment = .center
    private var showsDividers: Bool = false
    private var accessibilityID: String? = nil

    @Namespace private var underline
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.layoutDirection) private var layoutDirection
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public init(_ items: [TabItem], selection: Binding<Int>,
                onClose: ((Int) -> Void)? = nil, onAdd: (() -> Void)? = nil) {   // R1
        self.items = items
        self._selection = selection
        self.onClose = onClose
        self.onAdd = onAdd
    }

    public init(_ items: [String], selection: Binding<Int>,
                onClose: ((Int) -> Void)? = nil, onAdd: (() -> Void)? = nil) {   // R1
        self.items = items.map { TabItem($0) }
        self._selection = selection
        self.onClose = onClose
        self.onAdd = onAdd
    }

    public var body: some View {
        if scrollable || style == .card {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { bar }
                    .onAppear { scrollToSelection(proxy, animated: false) }
                    .onChange(of: selection) { _, _ in scrollToSelection(proxy) }
            }
        } else {
            bar
        }
    }

    /// Brings the selected tab into view at `scrollAlignment` (HeroUI Tabs
    /// `scrollAlign`). No motion when micro-animations are off or Reduce Motion is on.
    private func scrollToSelection(_ proxy: ScrollViewProxy, animated: Bool = true) {
        guard let anchor = scrollAlignment.anchor(layoutDirection), items.indices.contains(selection) else { return }
        if animated, let motion {
            withAnimation(motion) { proxy.scrollTo(selection, anchor: anchor) }
        } else {
            proxy.scrollTo(selection, anchor: anchor)
        }
    }

    private var bar: some View {
        HStack(spacing: barSpacing) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Group {
                    switch style {
                    case .card:
                        cardTab(index: index, item: item)
                    case .pill:
                        pillTab(index: index, item: item)
                            .frame(maxWidth: scrollable ? nil : .infinity)
                    case .underline:
                        tab(index: index, item: item)
                            .frame(maxWidth: scrollable ? nil : .infinity)
                    }
                }
                .id(index)   // ScrollViewReader target for auto-scroll
                if showsDividers && index < items.count - 1 {
                    divider(after: index)
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
        .padding(style == .pill ? Theme.SpacingKey.xs.value : 0)
        .background {
            if style == .pill {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .fill(theme.background(.bgElevatorTertiary))
            }
        }
        // With dividers the hairline `Rectangle`s must span the row, not stretch
        // the bar to an unbounded proposal — size the row to its ideal height.
        .fixedSize(horizontal: false, vertical: showsDividers)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(items.indices.contains(selection) ? items[selection].title : "")
    }

    private var barSpacing: CGFloat {
        switch style {
        case .card: return Theme.SpacingKey.sm.value
        case .pill: return Theme.SpacingKey.xs.value
        case .underline: return scrollable ? Theme.SpacingKey.lg.value : 0
        }
    }

    /// daisyUI `tabs-box`: the active tab is a filled pill sliding inside a boxed track.
    private func pillTab(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return Button {
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
            .foregroundStyle(item.isEnabled
                             ? (isActive ? theme.foreground(.fgSecondary) : theme.text(.textSecondary))
                             : theme.text(.textDisabled))
            .padding(.horizontal, Theme.SpacingKey.md.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .frame(maxWidth: scrollable ? nil : .infinity)
            .background {
                if isActive {
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                        .fill(theme.background(.bgHero))
                        .matchedGeometryEffect(id: "pill", in: underline)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!item.isEnabled)
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

    /// A hairline between adjacent tabs (HeroUI Tabs.Separator). Fades out when
    /// either neighbor is the selected tab, honoring the micro-motion gates.
    private func divider(after index: Int) -> some View {
        let touchesSelection = index == selection || index + 1 == selection
        return Rectangle()
            .fill(theme.border(.borderPrimary))
            .frame(width: 1)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .opacity(touchesSelection ? 0 : 1)
            .animation(motion, value: selection)
            .accessibilityHidden(true)
    }
}

#Preview {
    struct Demo: View {
        @State var sel = 0
        @State var scrollSel = 6
        @State var paneSel = 0
        var body: some View {
            ScrollView {
                VStack(spacing: 24) {
                    SegmentedTabBar([TabItem("Overview", systemImage: "square.grid.2x2"),
                                     TabItem("Reviews", badge: "12"),
                                     TabItem("Archived", isEnabled: false)], selection: $sel)
                    SegmentedTabBar(["All", "Flights", "Hotels", "Cars", "Tours"], selection: $sel).scrollable()
                    SegmentedTabBar(["Flights", "Hotels", "Cars"], selection: $sel).tabStyle(.pill)

                    // Inter-tab dividers — hairlines fade out next to the selection.
                    SegmentedTabBar(["Day", "Week", "Month", "Year"], selection: $sel).dividers()

                    // Scrollable auto-scroll: the selected tab is kept centered.
                    SegmentedTabBar((1...12).map { "Month \($0)" }, selection: $scrollSel)
                        .scrollable()
                        .scrollAlign(.center)

                    // Content panes — cross-fade below the bar on selection change.
                    SegmentedTabBar(["Details", "Reviews", "FAQ"], selection: $paneSel)
                        .tabStyle(.pill)
                        .content { index in
                            Text("Pane \(index + 1)")
                                .textStyle(.bodyBase400)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                }
                .padding()
            }
        }
    }
    return Demo()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SegmentedTabBar {
    /// Let the bar scroll horizontally instead of distributing tabs evenly.
    func scrollable(_ on: Bool = true) -> Self { copy { $0.scrollable = on } }

    /// Visual treatment: underline / card / pill (boxed track, filled active tab).
    func tabStyle(_ s: SegmentedTabBarStyle) -> Self { copy { $0.style = s } }

    /// Where a scrollable bar parks the selected tab on selection change
    /// (HeroUI Tabs `scrollAlign`; default `.center`). `.none` turns auto-scroll
    /// off. Only applies when the bar scrolls (`.scrollable()` / `.tabStyle(.card)`).
    func scrollAlign(_ a: TabScrollAlignment) -> Self { copy { $0.scrollAlignment = a } }

    /// Draw a hairline in the border token between adjacent tabs (HeroUI
    /// Tabs.Separator). Dividers touching the selected tab fade out.
    func dividers(_ on: Bool = true) -> Self { copy { $0.showsDividers = on } }

    /// Pair the bar with switching content panes: `pane(selection)` renders below
    /// the bar and cross-fades on selection change (HeroUI Tabs.Content), honoring
    /// the micro-motion gates. Terminal — place it last in the modifier chain.
    ///
    ///     SegmentedTabBar(["A", "B"], selection: $sel).tabStyle(.pill)
    ///         .content { index in Text("Pane \(index)") }
    func content<Content: View>(@ViewBuilder _ pane: @escaping (Int) -> Content) -> some View {
        SegmentedTabView(bar: self, selection: _selection, pane: pane)
    }

    /// Sets the accessibility-identifier namespace for this component (its
    /// sub-elements get `"<id>.<element>"`).
    func a11yID(_ id: String?) -> Self { copy { $0.accessibilityID = id } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// The bar + switching panes (HeroUI Tabs root + Tabs.Content). Built by
/// ``SegmentedTabBar/content(_:)`` — the pane for the selected index renders
/// below the bar and cross-fades on selection change under the motion gates.
private struct SegmentedTabView<Content: View>: View {
    let bar: SegmentedTabBar
    @Binding var selection: Int
    let pane: (Int) -> Content

    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    init(bar: SegmentedTabBar, selection: Binding<Int>, pane: @escaping (Int) -> Content) {
        self.bar = bar
        self._selection = selection
        self.pane = pane
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            bar
            pane(selection)
                .id(selection)                 // new identity per tab → transition runs
                .transition(.opacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .animation(motion, value: selection)   // nil (no motion) when gated off
    }
}
