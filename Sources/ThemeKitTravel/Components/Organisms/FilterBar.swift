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
import ThemeKit

/// One toggleable quick-filter chip in a ``FilterBar``.
public struct QuickFilter: Identifiable, Hashable, Sendable {
    public let id: String
    public let title: String
    /// Optional SF Symbol rendered before the title.
    public let systemImage: String?
    /// Optional result count rendered as a trailing pill (e.g. "Seafront · 12").
    public let count: Int?
    public init(_ title: String, id: String? = nil, systemImage: String? = nil, count: Int? = nil) {
        self.title = title
        self.id = id ?? title
        self.systemImage = systemImage
        self.count = count
    }
}

/// Overall sizing of a ``FilterBar``.
public enum FilterBarSize: Sendable { case small, medium, large }

/// Chip selection look. `.solid` fills selected chips with the accent; `.outlined`
/// is the design-system pill — a light hero-soft fill + a 2pt hero border when
/// selected, a soft hairline when not (matches the Figma "Filter Section" tabs).
/// `.ghost` draws no chrome at rest — selected chips gain a soft accent fill.
public enum FilterChipStyle: Sendable { case solid, outlined, ghost }

/// How chips select. `.multiple` (default) toggles independently; `.single`
/// keeps at most one chip on — tapping another chip replaces the selection.
public enum FilterSelectionMode: Sendable { case multiple, single }

/// Leading Filter/Sort button shape. `.adaptive` shows text that collapses to an
/// icon on scroll; `.circle` is a fixed accent circle (icon-only).
public enum FilterLeadingShape: Sendable { case adaptive, circle }

public struct FilterBar: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let chips: [QuickFilter]
    @Binding private var selection: Set<String>
    // Appearance/config — mutated only through the modifiers below (R2).
    private var onFilter: (() -> Void)?
    private var onSort: (() -> Void)?
    private var filterTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var filterTitle: String { filterTitleOverride ?? String(themeKit: "Filter") }
    private var sortTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var sortTitle: String { sortTitleOverride ?? String(themeKit: "Sort") }
    private var filterIcon = "line.3.horizontal.decrease"
    private var sortIcon = "arrow.up.arrow.down"
    private var collapsible = true
    private var size: FilterBarSize = .medium
    private var accentColor: SemanticColor?
    private var spacing: CGFloat = Theme.SpacingKey.sm.value
    private var chipStyleVariant: FilterChipStyle = .solid
    private var leadingShapeVariant: FilterLeadingShape = .adaptive
    private var chipSurfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var selectionModeValue: FilterSelectionMode = .multiple
    private var clearAllTitle: String?
    private var onClearAllAction: (() -> Void)?
    private var overflowFadeValue = false
    private var trailingSlot: AnyView?

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
                    if onClearAllAction != nil, !selection.isEmpty {
                        clearAllChip
                    }
                }
                .padding(.trailing, 4)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID, anchor: .leading)
            .mask { overflowMask }
            if let trailingSlot {
                trailingSlot.fixedSize()
            }
        }
        .frame(height: controlHeight)
        .onChange(of: scrolledID) { _, newID in
            // Collapse once the first chip has scrolled past the leading edge. Driven by
            // the anchored item id (not a measured offset), so it's immune to the frame
            // change that collapsing the buttons causes.
            guard collapsible, hasLeading else { return }
            let shouldCollapse = newID != nil && newID != chips.first?.id
            if shouldCollapse != collapsed {
                // Reduce-Motion / microAnimations gate: nil animation snaps.
                withAnimation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion)) {
                    collapsed = shouldCollapse
                }
            }
        }
    }

    /// Trailing-edge gradient fade hinting at overflowed chips. Built with
    /// `UnitPoint.leading → .trailing`, which resolve against the layout
    /// direction — so the fade sits on the correct edge under RTL.
    @ViewBuilder private var overflowMask: some View {
        if overflowFadeValue {
            LinearGradient(
                stops: [
                    .init(color: .black, location: 0),
                    .init(color: .black, location: 0.92),
                    .init(color: .clear, location: 1),
                ],
                startPoint: .leading, endPoint: .trailing
            )
        } else {
            Rectangle()
        }
    }

    /// The trailing ghost "Clear" chip — visible only while a selection exists.
    private var clearAllChip: some View {
        Button {
            selection.removeAll()
            onClearAllAction?()
        } label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                Image(systemName: "xmark").font(.system(size: iconSize, weight: .semibold))
                Text(clearAllTitle ?? String(themeKit: "Clear")).textStyle(chipTextStyle).fixedSize()
            }
            .foregroundStyle(accentColor?.base ?? theme.foreground(.fgHero))
            .padding(.horizontal, chipHPad)
            .frame(minHeight: controlHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKit: "Clear all filters"))
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
        return Button {
            toggle(chip.id, isOn: isOn)
        } label: {
            HStack(spacing: Theme.SpacingKey.xs.value) {
                if let symbol = chip.systemImage {
                    Image(systemName: symbol).font(.system(size: iconSize, weight: .semibold))
                }
                Text(chip.title).textStyle(chipTextStyle)
                if let count = chip.count {
                    countPill(count, isOn: isOn)
                }
            }
            .foregroundStyle(chipTextColor(isOn: isOn))
            .padding(.horizontal, chipHPad)
            .frame(minHeight: controlHeight)
            .background(chipFill(isOn: isOn), in: Capsule())
            // strokeBorder (not stroke) insets the line fully inside the pill,
            // so the 2pt selected border isn't clipped at the tight top/bottom
            // curves — a centered stroke would bleed outside and look distorted.
            .overlay(Capsule().strokeBorder(chipBorderColor(isOn: isOn),
                                            lineWidth: chipStyleVariant == .outlined && isOn ? 2 : 1))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.count.map { "\(chip.title), \($0)" } ?? chip.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    /// Selection semantics per ``FilterSelectionMode``.
    private func toggle(_ id: String, isOn: Bool) {
        switch selectionModeValue {
        case .multiple:
            if isOn { selection.remove(id) } else { selection.insert(id) }
        case .single:
            selection = isOn ? [] : [id]
        }
    }

    /// Trailing count pill — SemanticColor ladder steps, no raw colors.
    private func countPill(_ count: Int, isOn: Bool) -> some View {
        let tone = accentColor ?? .primary
        let solidSelected = chipStyleVariant == .solid && isOn
        return Text("\(count)")
            .textStyle(.labelSm600)
            .foregroundStyle(solidSelected ? tone.onSolid : tone.strong)
            .padding(.horizontal, Theme.SpacingKey.xs.value)
            .background(solidSelected ? tone.active : tone.soft, in: Capsule())
    }

    // Chip colors per style (token-fed).
    private func chipTextColor(isOn: Bool) -> Color {
        switch chipStyleVariant {
        case .outlined: return theme.text(.textPrimary)
        case .ghost: return isOn ? (accentColor?.strong ?? theme.foreground(.fgHero)) : theme.text(.textSecondary)
        case .solid: return isOn ? accentFg : chipOffText
        }
    }
    private func chipFill(isOn: Bool) -> Color {
        switch chipStyleVariant {
        case .outlined: return isOn ? (accentColor?.soft ?? SemanticColor.primary.soft) : theme.background(chipSurfaceKey)
        case .ghost: return isOn ? (accentColor ?? .primary).soft : .clear
        case .solid: return isOn ? accentBg : theme.background(chipSurfaceKey)
        }
    }
    private func chipBorderColor(isOn: Bool) -> Color {
        switch chipStyleVariant {
        case .outlined:
            return isOn ? (accentColor?.border ?? theme.border(.borderHero)) : theme.background(.bgElevatorTertiary)
        case .ghost:
            return .clear
        case .solid:
            return isOn ? Color.clear : theme.border(.borderPrimary)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension FilterBar {
    /// Adds the pinned leading Filter button (collapses to icon-only on scroll).
    func onFilter(_ title: String = String(themeKit: "Filter"),
                  icon: String = "line.3.horizontal.decrease",
                  action: @escaping () -> Void) -> Self {
        copy { $0.filterTitleOverride = title; $0.filterIcon = icon; $0.onFilter = action }
    }
    /// Adds the pinned leading Sort button (collapses to icon-only on scroll).
    func onSort(_ title: String = String(themeKit: "Sort"), icon: String = "arrow.up.arrow.down", action: @escaping () -> Void) -> Self {
        copy { $0.sortTitleOverride = title; $0.sortIcon = icon; $0.onSort = action }
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
    /// Surface token for the unselected chip fill (default `.bgWhite`).
    func chipSurface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.chipSurfaceKey = key } }
    /// Gap between controls (default 8).
    @available(*, deprecated, message: "Use spacing(_: Theme.SpacingKey) — the token-bound overload.")
    func spacing(_ value: CGFloat) -> Self { copy { $0.spacing = max(0, value) } }
    /// Gap between controls from a theme spacing token (default `.sm`).
    func spacing(_ key: Theme.SpacingKey) -> Self { copy { $0.spacing = max(0, key.value) } }
    /// `.multiple` (default) toggles chips independently; `.single` keeps at
    /// most one chip on — tapping another chip replaces the selection.
    func selectionMode(_ m: FilterSelectionMode) -> Self { copy { $0.selectionModeValue = m } }
    /// Appends a trailing ghost "Clear" chip to the scroller, shown only while
    /// the selection is non-empty. Tapping it empties the bound selection and
    /// then calls `perform` (analytics, refetch…).
    func onClearAll(_ title: String = String(themeKit: "Clear"),
                    perform action: @escaping () -> Void) -> Self {
        copy { $0.clearAllTitle = title; $0.onClearAllAction = action }
    }
    /// Fades the scroller's trailing edge with a gradient mask as an overflow
    /// hint (RTL-safe — `UnitPoint.leading/.trailing` mirror with the layout).
    func overflowFade(_ on: Bool = true) -> Self { copy { $0.overflowFadeValue = on } }
    /// Accessory pinned after the chip scroller (canonical `.trailing { }`
    /// slot) — e.g. a results counter or a "View map" link. Evaluated
    /// immediately at the call site.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingSlot = AnyView(content()) }
    }

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
                // Outlined honors the accent — turquoise soft fill + turquoise border.
                FilterBar([QuickFilter("Beachfront", id: "8"), QuickFilter("Pool"),
                           QuickFilter("Spa")], selection: $sel)
                    .accent(.turquoise).chipStyle(.outlined).size(.small)
                // Unselected chips on a tinted surface.
                FilterBar([QuickFilter("Breakfast", id: "8"), QuickFilter("Pet friendly"),
                           QuickFilter("Parking")], selection: $sel)
                    .chipSurface(.bgSecondaryLight).size(.small)
                // Icons + counts, single-select, clear-all ghost chip, overflow fade.
                FilterBar([
                    QuickFilter("Beach", id: "8", systemImage: "beach.umbrella", count: 24),
                    QuickFilter("Pool", systemImage: "figure.pool.swim", count: 9),
                    QuickFilter("Spa", systemImage: "sparkles", count: 3),
                    QuickFilter("Gym", systemImage: "dumbbell", count: 12),
                ], selection: $sel)
                    .selectionMode(.single)
                    .onClearAll { }
                    .overflowFade()
                    .size(.small)
                // Ghost chips + a trailing pinned slot.
                FilterBar([QuickFilter("Cheapest", id: "8"), QuickFilter("Fastest"),
                           QuickFilter("Direct")], selection: $sel)
                    .chipStyle(.ghost).size(.small)
                    .trailing {
                        Text("128 stays").textStyle(.labelSm600)
                            .padding(.horizontal, Theme.SpacingKey.sm.value)
                    }
                // Token-fed spacing overload.
                FilterBar([QuickFilter("Nonstop", id: "8"), QuickFilter("Refundable")], selection: $sel)
                    .spacing(Theme.SpacingKey.md).size(.small).onFilter { }
            }
            .padding(.vertical)
        }
    }
    return Demo()
}
