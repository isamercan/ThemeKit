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
//  The *arrangement* is owned by the active ``FilterBarStyle`` from the environment
//  (ADR-0004): the component gathers its typed data into a `FilterBarConfiguration`
//  and hands it to the style — `.chips` (default) is today's bar verbatim, `.segmented`
//  and `.stacked` swap the whole layout, and apps can implement their own. See
//  `FilterBarStyle.swift`.
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
/// `.ghost` draws no chrome at rest — selected chips gain a soft accent fill. A
/// paint knob that composes with every ``FilterBarStyle`` preset (ADR-0004 §3) —
/// it never becomes a style axis of its own.
public enum FilterChipStyle: Sendable { case solid, outlined, ghost }

/// How chips select. `.multiple` (default) toggles independently; `.single`
/// keeps at most one chip on — tapping another chip replaces the selection.
public enum FilterSelectionMode: Sendable { case multiple, single }

/// Leading Filter/Sort button shape. `.adaptive` shows text that collapses to an
/// icon on scroll; `.circle` is a fixed accent circle (icon-only).
public enum FilterLeadingShape: Sendable { case adaptive, circle }

public struct FilterBar: View {
    @Environment(\.componentDensity) private var density
    @Environment(\.filterBarStyle) private var style
    @Environment(\.locale) private var locale
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
    private var clearAllTitleOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var clearAllTitle: String { clearAllTitleOverride ?? String(themeKit: "Clear") }
    private var onClearAllAction: (() -> Void)?
    private var overflowFadeValue = false
    private var trailingSlot: AnyView?

    public init(_ chips: [QuickFilter], selection: Binding<Set<String>>) {   // R1
        self.chips = chips
        self._selection = selection
    }

    // MARK: Body

    public var body: some View {
        // The arrangement is owned by the active `FilterBarStyle` (ADR-0004);
        // motion is resolved *here* (MicroMotion ∧ ¬Reduce Motion) so styles
        // never read the motion environment. Selection stays a `Binding` in
        // the component — styles only see the read snapshot + a toggle
        // closure (ADR-0004's ControllableState rule).
        let configuration = FilterBarConfiguration(
            filters: chips,
            selection: selection,
            selectionMode: selectionModeValue,
            toggleFilter: toggle,
            onFilter: onFilter,
            onSort: onSort,
            filterTitle: filterTitle,
            sortTitle: sortTitle,
            filterIcon: filterIcon,
            sortIcon: sortIcon,
            clearAllTitle: clearAllTitle,
            onClearAll: onClearAllAction.map { action in
                { selection.removeAll(); action() }
            },
            collapsible: collapsible,
            size: size,
            chipStyle: chipStyleVariant,
            leadingShape: leadingShapeVariant,
            chipSurfaceKey: chipSurfaceKey,
            overflowFade: overflowFadeValue,
            trailing: trailingSlot,
            accent: accentColor,
            spacing: spacing,
            isMotionEnabled: micro && !reduceMotion,
            density: density,
            locale: locale)
        style.makeBody(configuration: configuration)
    }

    /// Selection semantics per ``FilterSelectionMode`` — the mutation stays on
    /// the component's `Binding`; styles call this and never touch
    /// `selection` directly.
    private func toggle(_ id: String) {
        switch selectionModeValue {
        case .multiple:
            if selection.contains(id) { selection.remove(id) } else { selection.insert(id) }
        case .single:
            selection = selection.contains(id) ? [] : [id]
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
    /// Only the `.chips` style has a scroll axis to gate this on.
    func collapsible(_ on: Bool = true) -> Self { copy { $0.collapsible = on } }
    /// Overall size (heights + typography): small / medium (default) / large.
    func size(_ size: FilterBarSize) -> Self { copy { $0.size = size } }
    /// Chip selection look — `.solid` (accent fill) or `.outlined` (the
    /// design-system light-blue + hero-border pill). Composes with every
    /// ``FilterBarStyle`` preset.
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
        copy { $0.clearAllTitleOverride = title; $0.onClearAllAction = action }
    }
    /// Fades the scroller's trailing edge with a gradient mask as an overflow
    /// hint (RTL-safe — `UnitPoint.leading/.trailing` mirror with the layout).
    /// Only the `.chips` style has a scroll axis to fade.
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
    @Previewable @State var sel: Set<String> = ["8"]
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
