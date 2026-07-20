//
//  Dropdown.swift
//  ThemeKit
//  Created by İsa Mercan on 7.07.2026.
//
//  Molecule. A lightweight action menu anchored to any trigger view — tap the
//  trigger and a themed floating panel of actions opens beside it; tap an item
//  (or anywhere outside) to dismiss. The token-bound `Menu` replacement: unlike
//  ``Select`` it binds to no selection, and unlike ``MenuCard`` it floats over
//  content instead of sitting in the layout. Items can carry a subtitle and a
//  selected state, group into headed ``DropdownSection``s, and nest one inline
//  submenu tier. (daisyUI Dropdown + HeroUI Menu.)
//

import SwiftUI

// MARK: - Item

/// One entry of a ``Dropdown`` menu — an action row, a divider line, or an
/// inline expandable submenu.
public struct DropdownItem: Identifiable {
    /// Visual intent of an action row. (daisyUI Dropdown menu item.)
    public enum Role: Sendable {
        /// Regular action — primary text color.
        case normal
        /// Dangerous action (delete, sign out…) — error-tinted text and icon.
        case destructive
    }

    public let id = UUID()
    let title: String
    let subtitle: String?
    let systemImage: String?
    let role: Role
    let isDisabled: Bool
    let isSelected: Bool
    let action: () -> Void
    let isDivider: Bool
    /// Non-`nil` marks this item as a submenu trigger row (one tier deep).
    let submenuItems: [DropdownItem]?

    /// Content-stable identity for state that must survive item-array
    /// rebuilds (e.g. submenu expansion): `id` is minted per instance, so a
    /// parent re-render (selection change with `shouldCloseOnSelect(false)`)
    /// would otherwise orphan any state keyed on it.
    var diffIdentity: String { "\(title)|\(systemImage ?? "")" }

    public init(
        _ title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        role: Role = .normal,
        disabled: Bool = false,
        isSelected: Bool = false,
        action: @escaping () -> Void = {}
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.role = role
        self.isDisabled = disabled
        self.isSelected = isSelected
        self.action = action
        self.isDivider = false
        self.submenuItems = nil
    }

    private init(divider: Bool) {
        self.title = ""
        self.subtitle = nil
        self.systemImage = nil
        self.role = .normal
        self.isDisabled = false
        self.isSelected = false
        self.action = {}
        self.isDivider = divider
        self.submenuItems = nil
    }

    private init(submenu title: String, systemImage: String?, disabled: Bool, items: [DropdownItem]) {
        self.title = title
        self.subtitle = nil
        self.systemImage = systemImage
        self.role = .normal
        self.isDisabled = disabled
        self.isSelected = false
        self.action = {}
        self.isDivider = false
        self.submenuItems = items
    }

    /// A thin separator line between groups of actions.
    public static var divider: DropdownItem { DropdownItem(divider: true) }

    /// An inline expandable nested tier — tapping the row discloses `items`
    /// indented beneath it instead of running an action. One level deep:
    /// submenus nested inside a submenu render as plain rows. (HeroUI SubMenu.)
    public static func submenu(
        _ title: String,
        systemImage: String? = nil,
        disabled: Bool = false,
        items: [DropdownItem]
    ) -> DropdownItem {
        DropdownItem(submenu: title, systemImage: systemImage, disabled: disabled, items: items)
    }
}

// MARK: - Section

/// A group of ``DropdownItem`` rows with an optional non-interactive heading.
/// Consecutive sections are separated by a divider line automatically.
/// (HeroUI Menu.Group + Menu.Label.)
public struct DropdownSection: Identifiable {
    public let id = UUID()
    let heading: String?
    let items: [DropdownItem]

    public init(_ heading: String? = nil, items: [DropdownItem]) {
        self.heading = heading
        self.items = items
    }
}

// MARK: - Indicator

/// The leading mark drawn on selected rows. (HeroUI Menu.ItemIndicator.)
public enum DropdownIndicator: Sendable {
    /// A small checkmark glyph.
    case checkmark
    /// A small filled circle.
    case dot
}

/// Fixed indicator geometry — genuine dimensions with no semantic token.
private enum DropdownMetrics {
    /// Width of the leading indicator slot; reserved on every row of a section
    /// that contains a selection so titles stay aligned.
    static let indicatorSlot: CGFloat = IconSize.xs.value
    /// Diameter of the `.dot` indicator mark.
    static let dotDiameter: CGFloat = 6
}

// MARK: - Placement

/// Which corner of the trigger the menu panel grows from. (daisyUI Dropdown
/// `dropdown-top/bottom` + `dropdown-end`.)
public enum DropdownEdge: Sendable {
    case topLeading, topTrailing, bottomLeading, bottomTrailing

    /// `true` when the panel opens above the trigger.
    var isTop: Bool { self == .topLeading || self == .topTrailing }

    /// The overlay alignment that pins the panel to this corner of the anchor.
    var alignment: Alignment {
        switch self {
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }

    /// Anchor point the open/close scale animates from (the corner touching the trigger).
    var scaleAnchor: UnitPoint {
        switch self {
        case .topLeading: return .bottomLeading
        case .topTrailing: return .bottomTrailing
        case .bottomLeading: return .topLeading
        case .bottomTrailing: return .topTrailing
        }
    }
}

/// Pushes the panel just outside the chosen edge of the anchor (Tooltip's approach).
private struct DropdownPlacement: ViewModifier {
    let edge: DropdownEdge

    func body(content: Content) -> some View {
        let gap = Theme.SpacingKey.xs.value
        if edge.isTop {
            content.offset(y: -gap).alignmentGuide(.top) { $0[.bottom] }
        } else {
            content.offset(y: gap).alignmentGuide(.bottom) { $0[.top] }
        }
    }
}

// MARK: - Dropdown

/// Molecule. A lightweight action menu anchored to any trigger view — tapping
/// the trigger presents a themed floating panel of ``DropdownItem`` actions;
/// tapping an item or anywhere outside dismisses it. (daisyUI Dropdown +
/// HeroUI Menu.)
///
/// ```swift
/// Dropdown(items: [
///     .init("Rename", systemImage: "pencil") { rename() },
///     .divider,
///     .init("Delete", systemImage: "trash", role: .destructive) { delete() },
/// ]) {
///     Icon(systemName: "ellipsis.circle").size(.md)
/// }
/// .edge(.bottomTrailing)
/// ```
///
/// Selection menus group items into headed ``DropdownSection``s, mark rows
/// with `isSelected:`, and can stay open across taps:
///
/// ```swift
/// Dropdown(sections: [
///     DropdownSection("Sort by", items: [
///         .init("Name", isSelected: sort == .name) { sort = .name },
///         .init("Date", isSelected: sort == .date) { sort = .date },
///     ]),
/// ]) { trigger }
/// .indicator(.checkmark)
/// .shouldCloseOnSelect(false)
/// ```
public struct Dropdown<Trigger: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.isEnabled) private var isEnabled   // set natively by `.disabled(_:)`
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let sections: [DropdownSection]
    private let trigger: Trigger

    // Appearance/config — mutated only through the modifiers below (R2).
    private var edge: DropdownEdge = .bottomLeading
    private var accentColor: SemanticColor = .neutral
    private var menuWidth: CGFloat? = nil
    private var indicatorStyle: DropdownIndicator = .checkmark
    private var closesOnSelect = true

    /// Open state — uncontrolled (internal `@State`) or controlled (the
    /// caller's `isPresented:` binding drives it), unified by
    /// `ControllableState` (ADR-4).
    @ControllableState private var open: Bool
    @State private var expandedSubmenus: Set<String> = []

    /// A flat menu of items. Pass `isPresented:` to own the open state
    /// (controlled); omit it for the self-managing convenience.
    public init(
        items: [DropdownItem],
        isPresented: Binding<Bool>? = nil,
        @ViewBuilder trigger: () -> Trigger
    ) {   // R1
        self.sections = [DropdownSection(items: items)]
        self._open = ControllableState(wrappedValue: false, external: isPresented)
        self.trigger = trigger()
    }

    /// A sectioned menu — each ``DropdownSection`` renders its optional heading
    /// and rows, divided from the next section by a separator line.
    public init(
        sections: [DropdownSection],
        isPresented: Binding<Bool>? = nil,
        @ViewBuilder trigger: () -> Trigger
    ) {   // R1
        self.sections = sections
        self._open = ControllableState(wrappedValue: false, external: isPresented)
        self.trigger = trigger()
    }

    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    public var body: some View {
        Button {
            open.toggle()
        } label: {
            trigger.contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        // Outside-tap catcher — an invisible surface centered on the anchor, big
        // enough to cover the screen; drawn under the panel (earlier overlay).
        .overlay {
            if open {
                Color.clear
                    .contentShape(Rectangle())
                    .frame(width: 10_000, height: 10_000)
                    .onTapGesture { open = false }
                    .accessibilityHidden(true)
            }
        }
        .overlay(alignment: edge.alignment) {
            if open {
                panel
                    .modifier(DropdownPlacement(edge: edge))
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: edge.scaleAnchor)))
            }
        }
        .zIndex(open ? 1 : 0)   // float over later siblings while open (Tooltip-style)
        .animation(motion, value: open)
        .onChangeCompat(of: open) { _, isOpen in
            if !isOpen { expandedSubmenus = [] }   // fresh submenu state on reopen
        }
        .accessibilityAddTraits(.isButton)
        .accessibilityValue(open ? Text(String(themeKit: "Expanded")) : Text(String(themeKit: "Collapsed")))
        .accessibilityAction(.escape) { open = false }
    }

    // MARK: Panel

    private var panelShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
    }

    @MainActor
    private var panel: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(sections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    DividerView().size(.small)
                        .padding(.vertical, Theme.SpacingKey.xs.value)
                }
                sectionRows(section)
            }
        }
        .padding(Theme.SpacingKey.xs.value)
        .frame(width: menuWidth, alignment: .leading)
        .fixedSize(horizontal: menuWidth == nil, vertical: true)
        .background(theme.background(.bgWhite), in: panelShape)
        .overlay(panelShape.stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.soft)
        .animation(motion, value: expandedSubmenus)
        .zIndex(1)
    }

    // MARK: Section

    @MainActor @ViewBuilder
    private func sectionRows(_ section: DropdownSection) -> some View {
        if let heading = section.heading {
            headingRow(heading)
        }
        // Reserve the indicator slot across the whole section when any row is
        // selected, so titles stay aligned. (HeroUI ItemIndicator forceMount.)
        let reservesIndicator = section.items.contains { $0.isSelected }
        ForEach(section.items) { item in
            if item.isDivider {
                DividerView().size(.small)
                    .padding(.vertical, Theme.SpacingKey.xs.value)
            } else if let children = item.submenuItems {
                submenuRows(item, children: children, reservesIndicator: reservesIndicator)
            } else {
                row(item, reservesIndicator: reservesIndicator)
            }
        }
    }

    /// Non-interactive section heading. (HeroUI Menu.Label.)
    private func headingRow(_ heading: String) -> some View {
        Text(heading)
            .textStyle(.overline500)
            .foregroundStyle(theme.text(.textTertiary))
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.xs.value)
            .accessibilityAddTraits(.isHeader)
    }

    // MARK: Rows

    @MainActor
    private func row(_ item: DropdownItem, reservesIndicator: Bool, indented: Bool = false) -> some View {
        let destructive = item.role == .destructive
        let titleColor = destructive ? theme.resolve(.error).accent : theme.text(.textPrimary)
        let iconColor = destructive ? theme.resolve(.error).accent : theme.text(.textSecondary)

        return Button {
            if closesOnSelect { open = false }
            item.action()
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if reservesIndicator {
                    indicatorMark(selected: item.isSelected)
                }
                if let systemImage = item.systemImage {
                    Icon(systemName: systemImage).size(.sm).colorOverride(iconColor)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(titleColor)
                        .lineLimit(1)
                    if let subtitle = item.subtitle {
                        Text(subtitle)
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                            .lineLimit(2)
                    }
                }
                Spacer(minLength: Theme.SpacingKey.md.value)
            }
            .padding(.leading, indented ? Theme.SpacingKey.md.value : 0)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(DropdownRowPressStyle(tint: destructive ? theme.resolve(.error).soft : theme.resolve(accentColor).soft))
        .disabled(item.isDisabled)
        .opacity(item.isDisabled ? 0.4 : 1)
        .accessibilityAddTraits(item.isSelected ? .isSelected : [])
    }

    /// Inline expandable submenu — a disclosure row plus, when expanded, its
    /// children indented beneath it. (HeroUI SubMenu.)
    @MainActor @ViewBuilder
    private func submenuRows(_ item: DropdownItem, children: [DropdownItem], reservesIndicator: Bool) -> some View {
        let expanded = expandedSubmenus.contains(item.diffIdentity)

        Button {
            if expanded {
                expandedSubmenus.remove(item.diffIdentity)
            } else {
                expandedSubmenus.insert(item.diffIdentity)
            }
        } label: {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if reservesIndicator {
                    indicatorMark(selected: false)
                }
                if let systemImage = item.systemImage {
                    Icon(systemName: systemImage).size(.sm).colorOverride(theme.text(.textSecondary))
                }
                Text(item.title)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textPrimary))
                    .lineLimit(1)
                Spacer(minLength: Theme.SpacingKey.md.value)
                Icon(systemName: "chevron.right").size(.xs).colorOverride(theme.text(.textTertiary))
                    .rotationEffect(.degrees(expanded ? 90 : 0))
                    .mirrorsInRTL()
            }
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, Theme.SpacingKey.sm.value)
            .contentShape(Rectangle())
        }
        .buttonStyle(DropdownRowPressStyle(tint: theme.resolve(accentColor).soft))
        .disabled(item.isDisabled)
        .opacity(item.isDisabled ? 0.4 : 1)
        .accessibilityValue(expanded ? Text(String(themeKit: "Expanded")) : Text(String(themeKit: "Collapsed")))

        if expanded {
            let childReservesIndicator = children.contains { $0.isSelected }
            ForEach(children) { child in
                if child.isDivider {
                    DividerView().size(.small)
                        .padding(.vertical, Theme.SpacingKey.xs.value)
                } else {
                    // One tier deep: a nested `.submenu` renders as a plain row.
                    row(child, reservesIndicator: childReservesIndicator, indented: true)
                }
            }
        }
    }

    /// Fixed-width leading slot holding the selection mark; clear when the row
    /// is unselected so titles align across the section.
    private func indicatorMark(selected: Bool) -> some View {
        Group {
            if selected {
                switch indicatorStyle {
                case .checkmark:
                    Icon(systemName: "checkmark").size(.xs).colorOverride(theme.foreground(.fgHero))
                case .dot:
                    Circle()
                        .fill(theme.foreground(.fgHero))
                        .frame(width: DropdownMetrics.dotDiameter, height: DropdownMetrics.dotDiameter)
                }
            } else {
                Color.clear
            }
        }
        .frame(width: DropdownMetrics.indicatorSlot, height: DropdownMetrics.indicatorSlot)
        .accessibilityHidden(true)
    }
}

/// Row press feedback tinted by the dropdown's accent — the menu analog of
/// ``RowPressStyle``, with a configurable highlight color.
private struct DropdownRowPressStyle: ButtonStyle {
    let tint: Color
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                configuration.isPressed ? tint : .clear,
                in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous)
            )
            .animation(MicroMotion.animation(.instant, enabled: micro, reduceMotion: reduceMotion),
                       value: configuration.isPressed)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Dropdown {
    /// Which corner of the trigger the panel opens from (default `.bottomLeading`).
    func edge(_ edge: DropdownEdge) -> Self { copy { $0.edge = edge } }

    /// Semantic tint of the pressed-row highlight (default `.neutral`).
    func accent(_ color: SemanticColor) -> Self { copy { $0.accentColor = color } }

    /// Fixed panel width in points; `nil` (default) fits the widest item.
    func menuWidth(_ points: CGFloat?) -> Self { copy { $0.menuWidth = points } }

    /// The leading mark drawn on selected rows (default `.checkmark`).
    func indicator(_ v: DropdownIndicator) -> Self { copy { $0.indicatorStyle = v } }

    /// Whether tapping an action row dismisses the menu (default `true`).
    /// Pass `false` for selection menus that should stay open across taps.
    func shouldCloseOnSelect(_ on: Bool = true) -> Self { copy { $0.closesOnSelect = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        @State var sortBy = "Name"
        var body: some View {
            // Overlay component — closed cells show the resting trigger; the "open"
            // cells pin the panel with a constant `isPresented:` inside a taller frame
            // so the floating panel stays within the matrix cell.
            let items: [DropdownItem] = [
                .init("Rename", systemImage: "pencil"),
                .init("Duplicate", subtitle: "Copies into the same folder", systemImage: "plus.square.on.square"),
                .init("Share", systemImage: "square.and.arrow.up", disabled: true),
                .submenu("Export", systemImage: "arrow.up.doc", items: [
                    .init("PDF", systemImage: "doc.richtext"),
                    .init("PNG", systemImage: "photo"),
                    .divider,
                    .init("Plain text", systemImage: "doc.plaintext"),
                ]),
                .divider,
                .init("Delete", systemImage: "trash", role: .destructive),
            ]

            let triggerLabel: (String) -> AnyView = { title in
                AnyView(HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(title).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                    Icon(systemName: "chevron.down").size(.xs).colorOverride(theme.text(.textTertiary))
                }
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .padding(.vertical, Theme.SpacingKey.sm.value)
                .background(theme.background(.bgSecondaryLight),
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)))
            }

            PreviewMatrix("Dropdown") {
                PreviewCase("Triggers (closed — tap in live preview)") {
                    HStack(spacing: Theme.SpacingKey.lg.value) {
                        Dropdown(items: items) { triggerLabel("Options") }
                        Dropdown(items: items) {
                            Icon(systemName: "ellipsis.circle").size(.md).colorOverride(theme.foreground(.fgHero))
                        }
                        .edge(.bottomTrailing)
                        .accent(.primary)
                    }
                }
                PreviewCase("Open panel · subtitle + submenu + destructive") {
                    VStack {
                        Dropdown(items: items, isPresented: .constant(true)) { triggerLabel("Open") }
                            .menuWidth(220)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 360)
                }
                PreviewCase("Open selection · checkmark indicator, stays open") {
                    VStack {
                        Dropdown(sections: [
                            DropdownSection("Sort by", items: ["Name", "Date", "Size"].map { option in
                                DropdownItem(option, isSelected: sortBy == option) { sortBy = option }
                            }),
                        ], isPresented: .constant(true)) {
                            triggerLabel(sortBy)
                        }
                        .shouldCloseOnSelect(false)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 220)
                }
                PreviewCase("Open selection · dot indicator") {
                    VStack {
                        Dropdown(sections: [
                            DropdownSection("Layout", items: ["List", "Grid"].map { option in
                                DropdownItem(option, isSelected: option == "List")
                            }),
                        ], isPresented: .constant(true)) {
                            triggerLabel("List")
                        }
                        .indicator(.dot)
                        .shouldCloseOnSelect(false)
                        Spacer(minLength: 0)
                    }
                    .frame(height: 180)
                }
            }
        }
    }
    return Demo()
}
