//
//  FilterBar.swift
//  ThemeKit
//
//  Organism. A horizontal quick-filter bar — pinned leading Filter / Sort action
//  buttons that collapse to icon-only once the chips are scrolled, followed by a
//  horizontally-scrolling row of toggleable filter chips. Token-bound and generic.
//
//  ```swift
//  FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront"), …], selection: $active)
//      .onFilter { openFilters() }.onSort { openSort() }
//      .size(.large).accent(.turquoise)
//  ```
//

import SwiftUI

/// One toggleable quick-filter chip in a ``FilterBar``.
public struct QuickFilter: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    public init(_ title: String, id: String? = nil) {
        self.title = title
        self.id = id ?? title
    }
}

/// Overall sizing of a ``FilterBar``.
public enum FilterBarSize: Sendable { case small, medium, large }

/// Chip selection look. `.solid` fills selected chips with the accent; `.outlined`
/// is the design-system pill — a light hero-soft fill + a 2pt hero border when
/// selected, a soft hairline when not (matches the Figma "Filter Section" tabs).
public enum FilterChipStyle: Sendable { case solid, outlined }

/// Leading Filter/Sort button shape. `.adaptive` shows text that collapses to an
/// icon on scroll; `.circle` is a fixed accent circle (icon-only).
public enum FilterLeadingShape: Sendable { case adaptive, circle }

public struct FilterBar: View {
    @Environment(\.theme) private var theme

    private let chips: [QuickFilter]
    @Binding private var selection: Set<String>
    // Appearance/config — mutated only through the modifiers below (R2).
    private var onFilter: (() -> Void)?
    private var onSort: (() -> Void)?
    private var filterTitle = "Filter"
    private var sortTitle = "Sort"
    private var filterIcon = "line.3.horizontal.decrease"
    private var sortIcon = "arrow.up.arrow.down"
    private var collapsible = true
    private var size: FilterBarSize = .medium
    private var accentColor: SemanticColor?
    private var spacing: CGFloat = 8
    private var chipStyleVariant: FilterChipStyle = .solid
    private var leadingShapeVariant: FilterLeadingShape = .adaptive

    @State private var collapsed = false
    @State private var scrolledID: String?

    public init(_ chips: [QuickFilter], selection: Binding<Set<String>>) {   // R1
        self.chips = chips
        self._selection = selection
    }

    // MARK: Derived sizing / colours (token-fed)

    private var controlHeight: CGFloat { switch size { case .small: 34; case .medium: 40; case .large: 48 } }
    private var chipTextStyle: TextStyle { switch size { case .small: .labelSm600; case .medium: .labelBase600; case .large: .labelMd600 } }
    private var iconSize: CGFloat { switch size { case .small: 13; case .medium: 15; case .large: 17 } }
    private var chipHPad: CGFloat { switch size { case .small: 12; case .medium: 16; case .large: 20 } }
    private var accentBg: Color { accentColor.map { $0.solid } ?? theme.background(.bgHero) }
    private var accentFg: Color { accentColor.map { $0.onSolid } ?? theme.text(.textSecondaryInverse) }
    private var chipOffText: Color { accentColor.map { $0.base } ?? theme.foreground(.fgHero) }
    private var hasLeading: Bool { onFilter != nil || onSort != nil }

    // MARK: Body

    public var body: some View {
        HStack(spacing: spacing) {
            if hasLeading {
                HStack(spacing: spacing) {
                    if let onFilter { action(filterIcon, filterTitle, onFilter) }
                    if let onSort { action(sortIcon, sortTitle, onSort) }
                }
                .fixedSize()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: spacing) {
                    ForEach(chips) { chipView($0).id($0.id) }
                }
                .padding(.trailing, 4)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID, anchor: .leading)
        }
        .frame(height: controlHeight)
        .onChange(of: scrolledID) { _, newID in
            // Collapse once the first chip has scrolled past the leading edge. Driven by
            // the anchored item id (not a measured offset), so it's immune to the frame
            // change that collapsing the buttons causes.
            guard collapsible, hasLeading else { return }
            let shouldCollapse = newID != nil && newID != chips.first?.id
            if shouldCollapse != collapsed {
                withAnimation(.easeOut(duration: 0.22)) { collapsed = shouldCollapse }
            }
        }
    }

    @ViewBuilder private func action(_ icon: String, _ title: String, _ handler: @escaping () -> Void) -> some View {
        Button(action: handler) {
            if leadingShapeVariant == .circle {
                // Fixed accent circle (icon-only) — the Figma "Filter Section" look.
                Image(systemName: icon).font(.system(size: iconSize, weight: .semibold))
                    .foregroundStyle(accentFg)
                    .frame(width: controlHeight, height: controlHeight)
                    .background(accentBg, in: Circle())
            } else {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: iconSize, weight: .semibold))
                    if !collapsed { Text(title).textStyle(chipTextStyle).fixedSize() }
                }
                .foregroundStyle(accentFg)
                .padding(.horizontal, collapsed ? 0 : chipHPad)
                .frame(width: collapsed ? controlHeight : nil, height: controlHeight)
                .background(accentBg, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }

    private func chipView(_ chip: QuickFilter) -> some View {
        let isOn = selection.contains(chip.id)
        let outlined = chipStyleVariant == .outlined
        return Button {
            if isOn { selection.remove(chip.id) } else { selection.insert(chip.id) }
        } label: {
            Text(chip.title)
                .textStyle(chipTextStyle)
                .foregroundStyle(chipTextColor(isOn: isOn, outlined: outlined))
                .padding(.horizontal, chipHPad)
                .frame(minHeight: controlHeight)
                .background(chipFill(isOn: isOn, outlined: outlined), in: Capsule())
                .overlay(Capsule().stroke(chipBorderColor(isOn: isOn, outlined: outlined),
                                          lineWidth: outlined && isOn ? 2 : 1))
                .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    // Chip colors per style (token-fed).
    private func chipTextColor(isOn: Bool, outlined: Bool) -> Color {
        if outlined { return theme.text(.textPrimary) }
        return isOn ? accentFg : chipOffText
    }
    private func chipFill(isOn: Bool, outlined: Bool) -> Color {
        if outlined { return isOn ? SemanticColor.primary.soft : theme.background(.bgWhite) }
        return isOn ? accentBg : theme.background(.bgWhite)
    }
    private func chipBorderColor(isOn: Bool, outlined: Bool) -> Color {
        if outlined { return isOn ? theme.border(.borderHero) : theme.background(.bgElevatorTertiary) }
        return isOn ? Color.clear : theme.border(.borderPrimary)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterBar {
    /// Adds the pinned leading Filter button (collapses to icon-only on scroll).
    func onFilter(_ title: String = "Filter", icon: String = "line.3.horizontal.decrease", action: @escaping () -> Void) -> Self {
        copy { $0.filterTitle = title; $0.filterIcon = icon; $0.onFilter = action }
    }
    /// Adds the pinned leading Sort button (collapses to icon-only on scroll).
    func onSort(_ title: String = "Sort", icon: String = "arrow.up.arrow.down", action: @escaping () -> Void) -> Self {
        copy { $0.sortTitle = title; $0.sortIcon = icon; $0.onSort = action }
    }
    /// Whether the leading buttons collapse to icons on scroll (default on).
    func collapsible(_ on: Bool = true) -> Self { copy { $0.collapsible = on } }
    /// Overall size (heights + typography): small / medium (default) / large.
    func size(_ size: FilterBarSize) -> Self { copy { $0.size = size } }
    /// Chip selection look — `.solid` (accent fill) or `.outlined` (the
    /// design-system light-blue + hero-border pill).
    func chipStyle(_ style: FilterChipStyle) -> Self { copy { $0.chipStyleVariant = style } }
    /// Leading Filter/Sort button shape — `.adaptive` (collapsing text) or
    /// `.circle` (a fixed accent circle, icon-only).
    func leadingShape(_ shape: FilterLeadingShape) -> Self { copy { $0.leadingShapeVariant = shape } }
    /// Token-fed accent for the leading buttons and selected chips (default hero).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }
    /// Gap between controls (default 8).
    func spacing(_ value: CGFloat) -> Self { copy { $0.spacing = max(0, value) } }
    /// Gap between controls from a theme spacing token.
    func spacing(_ key: Theme.SpacingKey) -> Self { spacing(key.value) }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel: Set<String> = ["8"]
        var body: some View {
            VStack(spacing: 20) {
                FilterBar([
                    QuickFilter("8+ rating", id: "8"), QuickFilter("Ultra all-inclusive"), QuickFilter("All-inclusive"),
                    QuickFilter("Seafront"), QuickFilter("Aquapark"), QuickFilter("Free cancellation"),
                ], selection: $sel)
                .onFilter { }.onSort { }
                FilterBar([QuickFilter("Cheapest"), QuickFilter("Fastest"), QuickFilter("Direct")], selection: $sel)
                    .size(.small).accent(.turquoise).onFilter { }
                // Figma "Filter Section" look — outlined pills + circle buttons.
                FilterBar([QuickFilter("Cheapest", id: "8"), QuickFilter("Fastest"),
                           QuickFilter("Fast & Cheap"), QuickFilter("Direct")], selection: $sel)
                    .chipStyle(.outlined).leadingShape(.circle).size(.small)
                    .onFilter { }.onSort { }
            }
            .padding(.vertical)
        }
    }
    return Demo()
}
