//
//  FilterBarStyle.swift
//  ThemeKit
//
//  The styling hook for ``FilterBar`` — the Class A style protocol of
//  ADR-0004: the configuration hands styles the *typed* filter data (chips,
//  selection, leading actions…), not pre-laid content, so a style owns the
//  whole arrangement. Three built-ins:
//
//    .chips      pinned Filter/Sort actions + a horizontally-scrolling chip
//                row that collapses the actions to icon-only on scroll —
//                today's bar. Default.
//    .segmented  fixed equal-width segments, no scrolling — every filter
//                fully visible at once. Best for a small, stable filter set.
//    .stacked    the actions row above a wrapping chip row — every chip
//                visible without horizontal scroll.
//
//      FilterBar([QuickFilter("8+ rating"), QuickFilter("Seafront"), …], selection: $active)
//          .onFilter { openFilters() }.onSort { openSort() }
//          .filterBarStyle(.segmented)
//
//  `FilterChipStyle`/`leadingShape` remain configuration knobs *within* every
//  preset (ADR-0004 §3) — they're paint, not anatomy, so they aren't promoted
//  to styles of their own. FilterBar has no card/bar shell to delegate to
//  (ADR-0004 §6); presets paint their own chrome directly, and the token
//  theme colors everything. The component resolves MicroMotion / Reduce
//  Motion before calling a style — styles read
//  ``FilterBarConfiguration/isMotionEnabled``, never the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``FilterBarStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — `.segmented`/`.stacked` have no scrolling
/// axis, so they ignore ``collapsible`` and ``overflowFade``.
public struct FilterBarConfiguration {
    /// The chip data — title + optional icon/count.
    public let filters: [QuickFilter]
    /// The bound selection's current read snapshot. Styles never mutate it
    /// directly — call ``toggleFilter`` (the selection-mode logic and the
    /// `Binding` mutation stay in the component, ADR-0004's ControllableState
    /// rule).
    public let selection: Set<String>
    /// `.multiple` (default) toggles chips independently; `.single` keeps at
    /// most one chip on. Informational for styles that render selection state
    /// differently per mode; toggling itself always goes through
    /// ``toggleFilter``.
    public let selectionMode: FilterSelectionMode
    /// Flips one chip's selection, honoring ``selectionMode``.
    public let toggleFilter: (String) -> Void
    /// The pinned leading Filter action; `nil` hides it.
    public let onFilter: (() -> Void)?
    /// The pinned leading Sort action; `nil` hides it.
    public let onSort: (() -> Void)?
    /// Localized title for the Filter action (re-resolved every body pass).
    public let filterTitle: String
    /// Localized title for the Sort action (re-resolved every body pass).
    public let sortTitle: String
    /// SF Symbol for the Filter action.
    public let filterIcon: String
    /// SF Symbol for the Sort action.
    public let sortIcon: String
    /// Localized title for the trailing "Clear" affordance.
    public let clearAllTitle: String
    /// Empties the selection and notifies the caller; `nil` hides the
    /// affordance (also hidden whenever ``selection`` is empty).
    public let onClearAll: (() -> Void)?
    /// Whether the leading actions collapse to icon-only on scroll — presets
    /// without a scrolling axis ignore this.
    public let collapsible: Bool
    /// Overall control sizing: heights, icon size, chip padding, type scale.
    public let size: FilterBarSize
    /// Chip paint — solid / outlined / ghost. A knob *within* every preset
    /// (ADR-0004 §3), never a style axis of its own.
    public let chipStyle: FilterChipStyle
    /// Leading-action shape — adaptive (collapsing text) or a fixed circle.
    public let leadingShape: FilterLeadingShape
    /// Surface token for the unselected chip fill.
    public let chipSurfaceKey: Theme.BackgroundColorKey
    /// Trailing-edge overflow gradient hint — presets without horizontal
    /// scroll ignore this.
    public let overflowFade: Bool
    /// Accessory slot pinned after the chip row (canonical `.trailing { }`).
    public let trailing: AnyView?
    /// Token-fed accent for actions and selected chips; `nil` = theme hero.
    public let accent: SemanticColor?
    /// The explicit `spacing(_:)` override — the primary gap between the
    /// leading actions, the chips and the trailing slot. Honored as-is
    /// (never density-scaled): it's already an explicit override, the same
    /// way ``chipSurfaceKey`` overrides a style's own default surface.
    public let spacing: CGFloat
    /// Micro-animations resolved by the component (`MicroMotion` ∧ ¬Reduce
    /// Motion) — gate the collapse animation on this; never read the motion
    /// environment.
    public let isMotionEnabled: Bool
    /// The environment's component density, captured by the component — scale
    /// secondary chrome gaps (that have no dedicated override) with
    /// ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// formatted number so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// Density-scaled spacing for chrome gaps with no explicit override
    /// (e.g. the icon↔title gap inside a chip). Distinct from the ``spacing``
    /// property, which is the explicit, un-scaled `.spacing(_:)` override.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The solid accent fill for a selected `.solid` chip / leading action —
    /// the explicit `accent(_:)` override, else the theme's hero background.
    public func accentFill(_ theme: Theme) -> Color { accent.map { $0.solid } ?? theme.background(.bgHero) }
    /// The foreground atop ``accentFill(_:)`` — contrast-safe on the solid fill.
    public func onAccentFill(_ theme: Theme) -> Color {
        accent.map { $0.onSolid } ?? theme.text(.textSecondaryInverse)
    }
    /// Accent used as a plain text/icon tint on a neutral surface (unselected
    /// `.solid` chip text, the `.ghost` fallback, the Clear affordance).
    public func accentTint(_ theme: Theme) -> Color { accent.map { $0.base } ?? theme.foreground(.fgHero) }

    /// A count formatted with the captured locale (grouping separators honor
    /// injected locales) — shared by every preset's trailing count pill.
    public func formattedCount(_ n: Int) -> String { n.formatted(.number.locale(locale)) }
}

// MARK: - Protocol

/// Defines a `FilterBar`'s entire presentation. Implement `makeBody` to lay
/// out the configuration's filter data. Set one with `.filterBarStyle(_:)`;
/// the default is ``ChipsFilterBarStyle``.
public protocol FilterBarStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: FilterBarConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// Pure `size` → dimension mapping, unaffected by density (density scales
/// gaps, not dimensions — `ComponentDensity.swift`'s documented split).
/// File-private so every preset shares one source of truth without adding
/// public surface.
private extension FilterBarSize {
    var controlHeight: CGFloat {
        switch self { case .small: 34; case .medium: 40; case .large: 48 }
    }
    var chipTextStyle: TextStyle {
        switch self { case .small: .labelSm600; case .medium: .labelBase600; case .large: .labelMd600 }
    }
    var iconSize: CGFloat {
        switch self { case .small: 13; case .medium: 15; case .large: 17 }
    }
    var chipHPad: CGFloat {
        switch self { case .small: 12; case .medium: 16; case .large: 20 }
    }
}

/// Chip text / fill / border colors for a given ``FilterChipStyle`` — shared
/// by every preset that renders pill chips or segments. Token-fed throughout;
/// reproduces `FilterBar`'s pre-style color logic exactly.
private struct FilterChipPalette {
    let text: Color
    let fill: Color
    let border: Color
    let borderWidth: CGFloat

    init(isOn: Bool, configuration: FilterBarConfiguration, theme: Theme) {
        let accent = configuration.accent
        switch configuration.chipStyle {
        case .outlined:
            text = theme.text(.textPrimary)
            fill = isOn ? (accent?.soft ?? SemanticColor.primary.soft) : theme.background(configuration.chipSurfaceKey)
            border = isOn ? (accent?.border ?? theme.border(.borderHero)) : theme.background(.bgElevatorTertiary)
            borderWidth = isOn ? 2 : 1
        case .ghost:
            text = isOn ? (accent?.strong ?? theme.foreground(.fgHero)) : theme.text(.textSecondary)
            fill = isOn ? (accent ?? .primary).soft : .clear
            border = .clear
            borderWidth = 1
        case .solid:
            text = isOn ? configuration.onAccentFill(theme) : configuration.accentTint(theme)
            fill = isOn ? configuration.accentFill(theme) : theme.background(configuration.chipSurfaceKey)
            border = isOn ? .clear : theme.border(.borderPrimary)
            borderWidth = 1
        }
    }
}

/// The trailing count pill on a chip, e.g. "Seafront · 12". Shared across
/// presets — `SemanticColor` ladder steps, no raw colors.
private struct FilterCountPill: View {
    let count: Int
    let isOn: Bool
    let configuration: FilterBarConfiguration

    var body: some View {
        let tone = configuration.accent ?? .primary
        let solidSelected = configuration.chipStyle == .solid && isOn
        Text(configuration.formattedCount(count))
            .textStyle(.labelSm600)
            .foregroundStyle(solidSelected ? tone.onSolid : tone.strong)
            .padding(.horizontal, configuration.spacing(.xs))
            .background(solidSelected ? tone.active : tone.soft, in: Capsule())
    }
}

/// One pinned leading action (Filter/Sort). `.adaptive` shows text that
/// collapses to an icon when `collapsed` is set; `.circle` is always
/// icon-only. Shared by every preset — only `.chips` ever passes
/// `collapsed: true` (it's the only preset with a scroll axis to gate on).
private struct FilterLeadingAction: View {
    @Environment(\.theme) private var theme
    let icon: String
    let title: String
    let configuration: FilterBarConfiguration
    let collapsed: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if configuration.leadingShape == .circle {
                Image(systemName: icon).font(.system(size: configuration.size.iconSize, weight: .semibold))
                    .foregroundStyle(configuration.onAccentFill(theme))
                    .frame(width: configuration.size.controlHeight, height: configuration.size.controlHeight)
                    .background(configuration.accentFill(theme), in: Circle())
            } else {
                HStack(spacing: 6) {
                    Image(systemName: icon).font(.system(size: configuration.size.iconSize, weight: .semibold))
                    if !collapsed { Text(title).textStyle(configuration.size.chipTextStyle).fixedSize() }
                }
                .foregroundStyle(configuration.onAccentFill(theme))
                .padding(.horizontal, collapsed ? 0 : configuration.size.chipHPad)
                .frame(width: collapsed ? configuration.size.controlHeight : nil, height: configuration.size.controlHeight)
                .background(configuration.accentFill(theme),
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

/// One selectable pill chip (icon + title + count). Shared by `.chips` and
/// `.stacked` — both lay chips out as individually-shaped capsules.
private struct FilterChipPill: View {
    @Environment(\.theme) private var theme
    let chip: QuickFilter
    let configuration: FilterBarConfiguration

    private var isOn: Bool { configuration.selection.contains(chip.id) }

    var body: some View {
        let palette = FilterChipPalette(isOn: isOn, configuration: configuration, theme: theme)
        Button {
            configuration.toggleFilter(chip.id)
        } label: {
            HStack(spacing: configuration.spacing(.xs)) {
                if let symbol = chip.systemImage {
                    Image(systemName: symbol).font(.system(size: configuration.size.iconSize, weight: .semibold))
                }
                Text(chip.title).textStyle(configuration.size.chipTextStyle)
                if let count = chip.count {
                    FilterCountPill(count: count, isOn: isOn, configuration: configuration)
                }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, configuration.size.chipHPad)
            .frame(minHeight: configuration.size.controlHeight)
            .background(palette.fill, in: Capsule())
            // strokeBorder (not stroke) insets the line fully inside the pill,
            // so the 2pt selected border isn't clipped at the tight top/bottom
            // curves — a centered stroke would bleed outside and look distorted.
            .overlay(Capsule().strokeBorder(palette.border, lineWidth: palette.borderWidth))
            .fixedSize()
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.count.map { "\(chip.title), \($0)" } ?? chip.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

/// The trailing ghost "Clear" chip — visible only while a selection exists.
/// Shared by every preset.
private struct FilterClearAllChip: View {
    @Environment(\.theme) private var theme
    let configuration: FilterBarConfiguration

    var body: some View {
        Button {
            configuration.onClearAll?()
        } label: {
            HStack(spacing: configuration.spacing(.xs)) {
                Image(systemName: "xmark").font(.system(size: configuration.size.iconSize, weight: .semibold))
                Text(configuration.clearAllTitle).textStyle(configuration.size.chipTextStyle).fixedSize()
            }
            .foregroundStyle(configuration.accentTint(theme))
            .padding(.horizontal, configuration.size.chipHPad)
            .frame(minHeight: configuration.size.controlHeight)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKit: "Clear all filters"))
    }
}

// MARK: - .chips

/// Today's ``FilterBar`` look, extracted verbatim: pinned leading Filter/Sort
/// actions (collapsing to icon-only once the first chip scrolls past the
/// leading edge) followed by a horizontally-scrolling chip row, with an
/// optional trailing-edge overflow fade and a trailing accessory slot.
public struct ChipsFilterBarStyle: FilterBarStyle {
    public init() {}
    public func makeBody(configuration: FilterBarConfiguration) -> some View {
        ChipsFilterBarChrome(configuration: configuration)
    }
}

private struct ChipsFilterBarChrome: View {
    let configuration: FilterBarConfiguration

    @State private var collapsed = false
    @State private var scrolledID: String?

    private var hasLeading: Bool { configuration.onFilter != nil || configuration.onSort != nil }

    var body: some View {
        HStack(spacing: configuration.spacing) {
            if hasLeading {
                HStack(spacing: configuration.spacing) {
                    if let onFilter = configuration.onFilter {
                        FilterLeadingAction(icon: configuration.filterIcon, title: configuration.filterTitle,
                                             configuration: configuration, collapsed: collapsed, action: onFilter)
                    }
                    if let onSort = configuration.onSort {
                        FilterLeadingAction(icon: configuration.sortIcon, title: configuration.sortTitle,
                                             configuration: configuration, collapsed: collapsed, action: onSort)
                    }
                }
                .fixedSize()
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: configuration.spacing) {
                    ForEach(configuration.filters) {
                        FilterChipPill(chip: $0, configuration: configuration).id($0.id)
                    }
                    if configuration.onClearAll != nil, !configuration.selection.isEmpty {
                        FilterClearAllChip(configuration: configuration)
                    }
                }
                .padding(.trailing, 4)
                .scrollTargetLayout()
            }
            .scrollPosition(id: $scrolledID, anchor: .leading)
            .mask { overflowMask }
            if let trailing = configuration.trailing {
                trailing.fixedSize()
            }
        }
        .frame(height: configuration.size.controlHeight)
        .onChange(of: scrolledID) { _, newID in
            // Collapse once the first chip has scrolled past the leading edge. Driven by
            // the anchored item id (not a measured offset), so it's immune to the frame
            // change that collapsing the buttons causes.
            guard configuration.collapsible, hasLeading else { return }
            let shouldCollapse = newID != nil && newID != configuration.filters.first?.id
            if shouldCollapse != collapsed {
                // Reduce-Motion / microAnimations gate: nil animation snaps. Resolved by
                // the component into `isMotionEnabled` — never read the motion environment.
                withAnimation(configuration.isMotionEnabled ? Motion.fast.animation : nil) {
                    collapsed = shouldCollapse
                }
            }
        }
    }

    /// Trailing-edge gradient fade hinting at overflowed chips. Built with
    /// `UnitPoint.leading → .trailing`, which resolve against the layout
    /// direction — so the fade sits on the correct edge under RTL.
    @ViewBuilder private var overflowMask: some View {
        if configuration.overflowFade {
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
}

// MARK: - .segmented

/// Fixed equal-width segments in one bordered row — no scrolling, every
/// filter fully visible at once. The pinned leading actions (never
/// collapsing — there's no scroll to gate on) sit before the segments; a
/// Clear affordance and the trailing slot sit after.
public struct SegmentedFilterBarStyle: FilterBarStyle {
    public init() {}
    public func makeBody(configuration: FilterBarConfiguration) -> some View {
        SegmentedFilterBarChrome(configuration: configuration)
    }
}

private struct SegmentedFilterBarChrome: View {
    @Environment(\.theme) private var theme
    let configuration: FilterBarConfiguration

    var body: some View {
        HStack(spacing: configuration.spacing) {
            if let onFilter = configuration.onFilter {
                FilterLeadingAction(icon: configuration.filterIcon, title: configuration.filterTitle,
                                     configuration: configuration, collapsed: false, action: onFilter)
            }
            if let onSort = configuration.onSort {
                FilterLeadingAction(icon: configuration.sortIcon, title: configuration.sortTitle,
                                     configuration: configuration, collapsed: false, action: onSort)
            }
            segments
            if configuration.onClearAll != nil, !configuration.selection.isEmpty {
                FilterClearAllChip(configuration: configuration)
            }
            if let trailing = configuration.trailing {
                trailing.fixedSize()
            }
        }
        .frame(height: configuration.size.controlHeight)
    }

    private var segments: some View {
        HStack(spacing: 0) {
            ForEach(configuration.filters) { segment($0) }
        }
        .frame(height: configuration.size.controlHeight)
        .background(theme.background(configuration.chipSurfaceKey))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous)
                .strokeBorder(theme.border(.borderPrimary), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }

    /// One equal-width cell. Deliberately borderless per-segment (the outer
    /// row already draws the container border) so `.outlined`/`.ghost`
    /// contribute only fill + text color here, keeping the segmented shape
    /// coherent across every ``FilterChipStyle``.
    private func segment(_ chip: QuickFilter) -> some View {
        let isOn = configuration.selection.contains(chip.id)
        let palette = FilterChipPalette(isOn: isOn, configuration: configuration, theme: theme)
        return Button {
            configuration.toggleFilter(chip.id)
        } label: {
            HStack(spacing: configuration.spacing(.xs)) {
                if let symbol = chip.systemImage {
                    Image(systemName: symbol).font(.system(size: configuration.size.iconSize, weight: .semibold))
                }
                Text(chip.title).textStyle(configuration.size.chipTextStyle).lineLimit(1)
                if let count = chip.count {
                    FilterCountPill(count: count, isOn: isOn, configuration: configuration)
                }
            }
            .foregroundStyle(palette.text)
            .padding(.horizontal, configuration.size.chipHPad)
            .frame(maxWidth: .infinity, minHeight: configuration.size.controlHeight)
            .background(palette.fill)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(chip.count.map { "\(chip.title), \($0)" } ?? chip.title)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}

// MARK: - .stacked

/// The pinned actions row (Filter/Sort/trailing slot) above a wrapping chip
/// row — every chip visible without horizontal scroll. RTL-safe via the
/// injected `layoutDirection` on ``FlowLayout``.
public struct StackedFilterBarStyle: FilterBarStyle {
    public init() {}
    public func makeBody(configuration: FilterBarConfiguration) -> some View {
        StackedFilterBarChrome(configuration: configuration)
    }
}

private struct StackedFilterBarChrome: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let configuration: FilterBarConfiguration

    private var hasActionsRow: Bool {
        configuration.onFilter != nil || configuration.onSort != nil || configuration.trailing != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: configuration.spacing) {
            if hasActionsRow {
                HStack(spacing: configuration.spacing) {
                    if let onFilter = configuration.onFilter {
                        FilterLeadingAction(icon: configuration.filterIcon, title: configuration.filterTitle,
                                             configuration: configuration, collapsed: false, action: onFilter)
                    }
                    if let onSort = configuration.onSort {
                        FilterLeadingAction(icon: configuration.sortIcon, title: configuration.sortTitle,
                                             configuration: configuration, collapsed: false, action: onSort)
                    }
                    Spacer(minLength: 0)
                    if let trailing = configuration.trailing { trailing }
                }
            }
            FlowLayout(spacing: configuration.spacing, lineSpacing: configuration.spacing,
                       layoutDirection: layoutDirection) {
                ForEach(configuration.filters) { FilterChipPill(chip: $0, configuration: configuration) }
                if configuration.onClearAll != nil, !configuration.selection.isEmpty {
                    FilterClearAllChip(configuration: configuration)
                }
            }
        }
    }
}

// MARK: - Static accessors

public extension FilterBarStyle where Self == ChipsFilterBarStyle {
    /// Pinned Filter/Sort actions + a horizontally-scrolling chip row that
    /// collapses the actions to icon-only on scroll — today's bar. The default.
    static var chips: ChipsFilterBarStyle { ChipsFilterBarStyle() }
}
public extension FilterBarStyle where Self == SegmentedFilterBarStyle {
    /// Fixed equal-width segments, no scrolling — every filter fully visible
    /// at once. Best for a small, stable filter set.
    static var segmented: SegmentedFilterBarStyle { SegmentedFilterBarStyle() }
}
public extension FilterBarStyle where Self == StackedFilterBarStyle {
    /// The actions row above a wrapping chip row — every chip visible without
    /// horizontal scroll.
    static var stacked: StackedFilterBarStyle { StackedFilterBarStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyFilterBarStyle: FilterBarStyle {
    private let _makeBody: @MainActor (FilterBarConfiguration) -> AnyView
    init<S: FilterBarStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: FilterBarConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct FilterBarStyleKey: EnvironmentKey {
    static let defaultValue = AnyFilterBarStyle(ChipsFilterBarStyle())
}

extension EnvironmentValues {
    var filterBarStyle: AnyFilterBarStyle {
        get { self[FilterBarStyleKey.self] }
        set { self[FilterBarStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``FilterBarStyle`` for `FilterBar`s in this view and its
    /// descendants — one screen can mix archetypes per section.
    func filterBarStyle<S: FilterBarStyle>(_ style: sending S) -> some View {
        environment(\.filterBarStyle, AnyFilterBarStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a plain underline-tab row, no chip chrome at all.
private struct UnderlineFilterBarStyle: FilterBarStyle {
    func makeBody(configuration: FilterBarConfiguration) -> some View {
        UnderlineFilterBarChrome(configuration: configuration)
    }

    private struct UnderlineFilterBarChrome: View {
        @Environment(\.theme) private var theme
        let configuration: FilterBarConfiguration

        var body: some View {
            HStack(spacing: configuration.spacing(.md)) {
                ForEach(configuration.filters) { chip in
                    let isOn = configuration.selection.contains(chip.id)
                    Button {
                        configuration.toggleFilter(chip.id)
                    } label: {
                        VStack(spacing: 4) {
                            Text(chip.title).textStyle(.labelBase600)
                                .foregroundStyle(isOn ? configuration.accentTint(theme) : theme.text(.textSecondary))
                            Rectangle()
                                .fill(isOn ? configuration.accentTint(theme) : Color.clear)
                                .frame(height: 2)
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(chip.title)
                    .accessibilityAddTraits(isOn ? .isSelected : [])
                }
            }
        }
    }
}

#Preview("FilterBarStyle — presets × light/dark") {
    @Previewable @State var sel: Set<String> = ["8"]
    let chips = [
        QuickFilter("8+ rating", id: "8", systemImage: "star.fill", count: 24),
        QuickFilter("Seafront", systemImage: "beach.umbrella", count: 9),
        QuickFilter("All-inclusive", count: 3),
        QuickFilter("Free cancellation"),
    ]
    PreviewMatrix("FilterBarStyle") {
        PreviewCase("Chips (default)") {
            FilterBar(chips, selection: $sel)
                .onFilter { }.onSort { }.onClearAll { }
                .filterBarStyle(.chips)
        }
        PreviewCase("Segmented") {
            FilterBar(chips, selection: $sel)
                .onFilter { }.accent(.turquoise)
                .filterBarStyle(.segmented)
        }
        PreviewCase("Stacked") {
            FilterBar(chips, selection: $sel)
                .onFilter { }.onSort { }.onClearAll { }
                .chipStyle(.outlined)
                .frame(width: 260)
                .filterBarStyle(.stacked)
        }
        PreviewCase("Custom (in-preview)") {
            FilterBar(chips, selection: $sel)
                .filterBarStyle(UnderlineFilterBarStyle())
        }
    }
}
