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
    /// The ``leading(_:)`` slot; `nil` means "use the `systemImage` shorthand".
    var leadingSlot: SlotContent?

    public init(_ title: String, caption: String? = nil, systemImage: String? = nil,
                trailingSystemImage: String? = nil, badge: String? = nil, isEnabled: Bool = true) {
        self.title = title; self.caption = caption; self.systemImage = systemImage
        self.trailingSystemImage = trailingSystemImage; self.badge = badge; self.isEnabled = isEnabled
    }
}

public extension TabItem {
    /// A custom view before the title (a host glyph, a flag, an avatar); when
    /// set, it replaces the `systemImage` shorthand. It inherits the tab's
    /// foreground colour and the tab's icon font (the shorthand's point size at
    /// the bar's density); a view that sets its own font keeps it.
    ///
    ///     TabItem("Flights").leading { HostGlyph(.plane) }
    @MainActor
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> TabItem {
        var copy = self
        copy.leadingSlot = SlotContent(content)
        return copy
    }
}

/// Visual style of `SegmentedTabBar` (Ant Tabs `type`; `.pill` = daisyUI `tabs-box`).
public enum SegmentedTabBarStyle { case underline, card, pill }

/// Tab-bar density (Ant Tabs `size` small / middle / large) — scales the label
/// type, icon glyph and pill/card padding. `.medium` keeps the original metrics.
public enum SegmentedTabBarSize: Sendable { case small, medium, large }

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
///
/// Each tab's chrome is drawn by the active ``SegmentedTabBarChromeStyle`` when
/// one is set with `.segmentedTabBarChromeStyle(_:)` on the bar or an ancestor;
/// the bar keeps its buttons, selection, accessibility and the chrome around
/// the tabs either way.
public struct SegmentedTabBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.segmentedTabBarChromeStyle) private var chromeStyle
    @Environment(\.controlSize) private var controlSize

    private let items: [TabItem]
    @Binding private var selection: Int
    private let onClose: ((Int) -> Void)?
    private let onAdd: (() -> Void)?

    // Appearance — mutated only through the modifiers below (R2).
    private var scrollable: Bool = false
    private var style: SegmentedTabBarStyle = .underline
    private var size: SegmentedTabBarSize = .medium
    private var scrollAlignment: TabScrollAlignment = .center
    private var showsDividers: Bool = false
    private var fillsWidth: Bool = true
    private var showsBaseline: Bool = false
    private var accessibilityID: String? = nil

    // MARK: Size metrics (Ant `size`) — `.medium` reproduces the original
    // values. They live on `SegmentedTabBarSize` (SegmentedTabBarChromeStyle.swift)
    // so the built-in tabs and `DefaultSegmentedTabBarChromeStyle` can't drift.
    private func titleStyle(_ active: Bool) -> TextStyle { size.titleStyle(isSelected: active) }
    /// Glyph point size for a tab icon at the current density.
    private func iconPoints(base: CGFloat) -> CGFloat { size.iconPoints(base: base) }
    private var tabHPadding: CGFloat { size.tabHorizontalPadding }
    private var tabVPadding: CGFloat { size.tabVerticalPadding }

    /// Whether the bar scrolls horizontally (a `.card` bar always does).
    private var scrolls: Bool { scrollable || style == .card }
    /// Whether the tabs hug their content with no space between them.
    private var hugsTabs: Bool { !fillsWidth && style != .card }
    /// Whether each tab takes an equal share of the bar's width.
    private var stretchesTabs: Bool { fillsWidth && !scrolls }

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
        laidOutBar.modifier(SegmentedTabBarBaseline(on: showsBaseline))
    }

    @ViewBuilder private var laidOutBar: some View {
        if scrolls {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) { bar }
                    .onAppear { scrollToSelection(proxy, animated: false) }
                    .onChangeCompat(of: selection) { _, _ in scrollToSelection(proxy) }
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
                    if chromeStyle.isDefault {
                        switch style {
                        case .card:
                            cardTab(index: index, item: item)
                        case .pill:
                            pillTab(index: index, item: item)
                                .frame(maxWidth: stretchesTabs ? .infinity : nil)
                        case .underline:
                            tab(index: index, item: item)
                                .frame(maxWidth: stretchesTabs ? .infinity : nil)
                        }
                    } else {
                        // The style draws the tab; the bar keeps the button.
                        styledTab(index: index, item: item)
                            .frame(maxWidth: stretchesTabs ? .infinity : nil)
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
                .accessibilityLabel(String(themeKit: "Add tab"))
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
        // A content-hugging bar sizes itself horizontally too, so its tabs take
        // their ideal width instead of sharing the offered one.
        .fixedSize(horizontal: hugsTabs && !scrolls, vertical: showsDividers)
        .a11y(A11yElement.Control.toggle, in: accessibilityID)
        .accessibilityValue(items.indices.contains(selection) ? items[selection].title : "")
        // …and parks at the leading edge of whatever width it's offered.
        .modifier(SegmentedTabBarLeadingRow(on: hugsTabs && !scrolls))
    }

    private var barSpacing: CGFloat {
        // Content-hugging tabs carry their own padding, so the bar adds no gap.
        guard !hugsTabs else { return 0 }
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
                glyph(item, base: 13)
                Text(item.title).textStyle(titleStyle(isActive))
                if let badge = item.badge {
                    SegmentedTabBadge(text: badge)
                }
            }
            .foregroundStyle(item.isEnabled
                             ? (isActive ? theme.foreground(.fgSecondary) : theme.text(.textSecondary))
                             : theme.text(.textDisabled))
            .padding(.horizontal, tabHPadding)
            .padding(.vertical, tabVPadding)
            .frame(maxWidth: stretchesTabs ? .infinity : nil)
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
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func cardTab(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        return HStack(spacing: Theme.SpacingKey.xs.value) {
            Button {
                withAnimation(motion) { selection = index }
            } label: {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    glyph(item, base: 13)
                    Text(item.title).textStyle(titleStyle(isActive))
                    if let badge = item.badge {
                        SegmentedTabBadge(text: badge)
                    }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(isActive ? .isSelected : [])
            if onClose != nil {
                closeButton(index: index, item: item)
                    .accessibilityLabel(String(themeKit: "Close \(item.title)"))
            }
        }
        .padding(.horizontal, tabHPadding)
        .padding(.vertical, tabVPadding)
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
                        glyph(item, base: 14)
                        Text(item.title).textStyle(titleStyle(isActive))
                        if let trailing = item.trailingSystemImage {
                            Image(systemName: trailing).font(.system(size: 13, weight: .semibold))
                        }
                        if let badge = item.badge {
                            SegmentedTabBadge(text: badge)
                        }
                    }
                    if let caption = item.caption {
                        Text(caption).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                    }
                }
                .foregroundStyle(foreground(isActive: isActive, enabled: item.isEnabled))
                // A content-hugging bar has no spacing of its own; the tab's
                // own padding sets the gap, and the rule spans it.
                .padding(.horizontal, hugsTabs ? tabHPadding : 0)

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
        .accessibilityAddTraits(isActive ? .isSelected : [])
    }

    private func foreground(isActive: Bool, enabled: Bool) -> Color {
        guard enabled else { return theme.text(.textDisabled) }
        return isActive ? theme.text(.textPrimary) : theme.text(.textSecondary)
    }

    /// A tab's leading content: the `.leading { }` slot when set, else the SF
    /// Symbol shorthand — both in the density's icon font.
    @ViewBuilder private func glyph(_ item: TabItem, base: CGFloat) -> some View {
        if let slot = item.leadingSlot {
            slot.font(.system(size: iconPoints(base: base), weight: .semibold))
        } else if let icon = item.systemImage {
            Image(systemName: icon).font(.system(size: iconPoints(base: base), weight: .semibold))
        }
    }

    /// The stock close (×) of a closable card tab. Unlabeled here: the built-in
    /// path labels it, and on the style path it sits inside the tab's button,
    /// where the tab's "Close …" action speaks for it.
    private func closeButton(index: Int, item: TabItem) -> some View {
        Button { onClose?(index) } label: {
            Image(systemName: "xmark").font(.system(size: 10, weight: .bold))
                .foregroundStyle(theme.text(.textTertiary))
        }
        .buttonStyle(.plain)
    }

    // MARK: Style path

    /// One tab drawn by the environment ``SegmentedTabBarChromeStyle``. The bar
    /// keeps the button (and the selection it writes), the live press state,
    /// the enabled state, the selected trait and the tab's VoiceOver label.
    private func styledTab(index: Int, item: TabItem) -> some View {
        let isActive = index == selection
        let closes: (() -> Void)? = isClosable ? { onClose?(index) } : nil
        return Button {
            withAnimation(motion) { selection = index }
        } label: {
            SegmentedTabChromeHost(style: chromeStyle,
                                   configuration: chromeConfiguration(index: index, item: item))
        }
        .buttonStyle(SegmentedTabChromePressBridge())
        .disabled(!item.isEnabled)
        .accessibilityLabel(SegmentedTabAccessibility.label(title: item.title,
                                                           caption: item.caption,
                                                           badge: item.badge))
        .accessibilityAddTraits(isActive ? .isSelected : [])
        .modifier(SegmentedTabCloseAction(title: item.title, onClose: closes))
    }

    /// Whether the bar's tabs carry a close button (only `.card` draws one).
    private var isClosable: Bool { style == .card && onClose != nil }

    /// The configuration before the state resolved inside the tab's button
    /// (`SegmentedTabChromeHost` fills `isEnabled` / `isPressed`). A set slot
    /// replaces the SF Symbol shorthand, as on the built-in path.
    private func chromeConfiguration(index: Int, item: TabItem) -> SegmentedTabBarChromeStyleConfiguration {
        let points = iconPoints(base: style == .underline ? 14 : 13)
        return SegmentedTabBarChromeStyleConfiguration(
            title: item.title,
            caption: item.caption,
            badge: item.badge,
            leading: item.leadingSlot.map { AnyView($0) }
                ?? item.systemImage.map { AnyView(Image(systemName: $0).font(.system(size: points, weight: .semibold))) },
            systemImage: item.leadingSlot == nil ? item.systemImage : nil,
            trailingSystemImage: item.trailingSystemImage,
            isSelected: index == selection,
            isEnabled: item.isEnabled,
            isPressed: false,
            tabStyle: style,
            size: size,
            controlSize: controlSize,
            isScrollable: scrolls,
            fillsWidth: fillsWidth,
            indicatorNamespace: underline,
            indicatorID: SegmentedTabAccessibility.indicatorID,
            animation: motion,
            closeButton: isClosable
                ? AnyView(closeButton(index: index, item: item).accessibilityHidden(true))
                : nil,
            onClose: isClosable ? { onClose?(index) } : nil,
            isItemEnabled: item.isEnabled)
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
            PreviewMatrix("SegmentedTabBar") {
                PreviewCase("Underline · icon + badge + disabled") {
                    SegmentedTabBar([TabItem("Overview", systemImage: "square.grid.2x2"),
                                     TabItem("Reviews", badge: "12"),
                                     TabItem("Archived", isEnabled: false)], selection: $sel)
                }
                PreviewCase("Scrollable") {
                    SegmentedTabBar(["All", "Flights", "Hotels", "Cars", "Tours"], selection: $sel).scrollable()
                }
                PreviewCase("Pill") {
                    SegmentedTabBar(["Flights", "Hotels", "Cars"], selection: $sel).tabStyle(.pill)
                }
                // Density axis (Ant `size`) — small / medium / large on the pill style.
                PreviewCase("Sizes (small · medium · large)") {
                    VStack(spacing: Theme.SpacingKey.sm.value) {
                        SegmentedTabBar(["Day", "Week", "Month"], selection: $sel).tabStyle(.pill).size(.small)
                        SegmentedTabBar(["Day", "Week", "Month"], selection: $sel).tabStyle(.pill).size(.medium)
                        SegmentedTabBar(["Day", "Week", "Month"], selection: $sel).tabStyle(.pill).size(.large)
                    }
                }
                PreviewCase("Card · closable + add") {
                    SegmentedTabBar(["Search", "Results", "Booking"], selection: $sel,
                                    onClose: { _ in }, onAdd: { }).tabStyle(.card)
                }
                // Inter-tab dividers — hairlines fade out next to the selection.
                PreviewCase("Dividers") {
                    SegmentedTabBar(["Day", "Week", "Month", "Year"], selection: $sel).dividers()
                }
                // Scrollable auto-scroll: the selected tab is kept centered.
                PreviewCase("Scrollable · centered auto-scroll") {
                    SegmentedTabBar((1...12).map { "Month \($0)" }, selection: $scrollSel)
                        .scrollable()
                        .scrollAlign(.center)
                }
                // Content panes — cross-fade below the bar on selection change.
                PreviewCase("Content panes") {
                    SegmentedTabBar(["Details", "Reviews", "FAQ"], selection: $paneSel)
                        .tabStyle(.pill)
                        .content { index in
                            Text("Pane \(index + 1)")
                                .textStyle(.bodyBase400)
                                .frame(maxWidth: .infinity, minHeight: 80)
                        }
                }
            }
        }
    }
    return Demo()
}

// MARK: - Shared decisions (testable without an accessibility tree)

/// What a styled tab says and where its indicator lives — in one place, so the
/// decisions can be tested without an accessibility tree (a unit-test host
/// builds none).
enum SegmentedTabAccessibility {
    /// The geometry id every bar's selection indicator uses; the namespace
    /// (one per bar) keeps two bars apart.
    static let indicatorID = "indicator"

    /// What VoiceOver reads for a tab drawn by a custom style: its title, its
    /// caption and its badge. (The style's own glyphs are decorative, so the
    /// bar names the tab itself instead of letting them be read out.)
    static func label(title: String, caption: String?, badge: String?) -> String {
        [title, caption, badge]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
    }
}

/// Gives a closable styled tab its "Close …" action: the close button sits
/// inside the tab's button, so VoiceOver reaches it as an action on the tab.
struct SegmentedTabCloseAction: ViewModifier {
    let title: String
    let onClose: (() -> Void)?

    @ViewBuilder
    func body(content: Content) -> some View {
        if let onClose {
            content.accessibilityAction(named: Text(String(themeKit: "Close \(title)")), onClose)
        } else {
            content
        }
    }
}

/// The hairline `.baseline()` draws along the bar's bottom edge, behind the
/// tabs — so the selected tab's indicator (or a card's border) covers it, the
/// way Ant's tab nav line does. It's a ``DividerView``, so a ``DividerStyle``
/// set on an ancestor paints it.
struct SegmentedTabBarBaseline: ViewModifier {
    let on: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if on {
            content.background(alignment: .bottom) { DividerView() }
        } else {
            content
        }
    }
}

/// Parks a content-hugging bar at the leading edge of the width it's offered.
struct SegmentedTabBarLeadingRow: ViewModifier {
    let on: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if on {
            content.frame(maxWidth: .infinity, alignment: .leading)
        } else {
            content
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SegmentedTabBar {
    /// Let the bar scroll horizontally instead of distributing tabs evenly.
    func scrollable(_ on: Bool = true) -> Self { copy { $0.scrollable = on } }

    /// Visual treatment: underline / card / pill (boxed track, filled active tab).
    func tabStyle(_ s: SegmentedTabBarStyle) -> Self { copy { $0.style = s } }

    /// Tab-bar density (Ant Tabs `size`): small / medium (default) / large —
    /// scales the label type, icon glyph and pill/card padding together.
    func size(_ s: SegmentedTabBarSize) -> Self { copy { $0.size = s } }

    /// Where a scrollable bar parks the selected tab on selection change
    /// (HeroUI Tabs `scrollAlign`; default `.center`). `.none` turns auto-scroll
    /// off. Only applies when the bar scrolls (`.scrollable()` / `.tabStyle(.card)`).
    func scrollAlign(_ a: TabScrollAlignment) -> Self { copy { $0.scrollAlignment = a } }

    /// Draw a hairline in the border token between adjacent tabs (HeroUI
    /// Tabs.Separator). Dividers touching the selected tab fade out.
    func dividers(_ on: Bool = true) -> Self { copy { $0.showsDividers = on } }

    /// Whether the tabs share the bar's width evenly (the default, and what
    /// the bar has always done). Turn it off and the tabs hug their content
    /// from the leading edge with no space between them — each tab's own
    /// padding sets the gap, which is what a ``SegmentedTabBarChromeStyle``
    /// with its own tab metrics wants. Has no effect on a bar that already
    /// hugs: one that scrolls (`.scrollable()`, `.tabStyle(.card)`). A hugging
    /// bar wider than the space it's offered overflows — pair it with
    /// `.scrollable()`.
    func fillsWidth(_ on: Bool = true) -> Self { copy { $0.fillsWidth = on } }

    /// Draw a hairline under the whole bar (Ant Tabs' nav line; off by
    /// default). It lies along the bottom edge behind the tabs, so the
    /// selected tab's indicator — or a card tab's border — covers it. It's a
    /// ``DividerView``, so a ``DividerStyle`` set on an ancestor paints it.
    func baseline(_ on: Bool = true) -> Self { copy { $0.showsBaseline = on } }

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
