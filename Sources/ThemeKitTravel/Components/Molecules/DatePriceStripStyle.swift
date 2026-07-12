//
//  DatePriceStripStyle.swift
//  ThemeKit
//
//  The styling hook for ``DatePriceStrip`` — a Class A style protocol of ADR-0004
//  (per-component style protocols): the configuration hands styles the *typed
//  date/price data* (items, selection, cheapest highlight, paging…), not pre-laid
//  content, so a style owns the entire arrangement. Three built-ins:
//
//    .grid(columns:)  the stock multi-column grid of date/price cards, with
//                     optional prev/next paging chevrons. `.grid(columns: 3)`
//                     is the default — today's render verbatim.
//    .strip           the horizontal "Timeline" strip of scrollable pills; the
//                     selected pill auto-centers (Reduce-Motion-gated).
//    .chart           a price-bar histogram — bar height ∝ price, tap a bar to
//                     select its date (the Google-Flights price-graph pattern).
//
//      DatePriceStrip(items, selection: $day)
//          .datePriceStripStyle(.chart)
//
//  One law (ADR-0004 §6): the component style arranges *content*; the shell
//  `CardStyle` paints the card cells' chrome (grid/strip cells keep composing
//  ``DatePriceCard``, which routes through `\.cardStyle`); the token theme colors
//  everything. The component resolves MicroMotion / Reduce Motion before calling
//  a style — styles read ``DatePriceStripConfiguration/isMotionEnabled``, never
//  the motion environment.
//

import SwiftUI
import ThemeKit

// MARK: - Configuration

/// The typed inputs a ``DatePriceStripStyle`` lays out. Fields a given style
/// doesn't use are simply ignored — every built-in degrades gracefully when
/// optional data is absent (no paging closures → no chevrons, no custom cell →
/// the built-in ``DatePriceCard``).
public struct DatePriceStripConfiguration {
    /// The date/price options, in display order.
    public let items: [DatePriceItem]
    /// Index of the selected item in ``items``.
    public let selectedIndex: Int
    /// Selects the item at an index — writes the component's `selection` binding.
    public let select: (Int) -> Void
    /// Currency code for the prices — already resolved by the component through
    /// the FormatDefaults chain (explicit → `formatDefaults` → `locale.currency`
    /// → `"USD"`). Optional for additive safety only.
    public let currencyCode: String?
    /// Semantic accent for the selected state (`DatePriceStrip.accent(_:)`);
    /// `nil` keeps the stock hero chroma — resolve via ``accentForeground(_:)``.
    public let accent: SemanticColor?
    /// Semantic tone for the lowest-fare highlight; `nil` keeps the stock
    /// success token — resolve via ``cheapestForeground(_:)``.
    public let cheapestTone: SemanticColor?
    /// Height ramp for pill-shaped cells (the `.strip` presentation).
    public let pillSize: DatePricePillSize
    /// Whether the lowest bookable fare is auto-highlighted — when `false`,
    /// ``cheapestIndex`` is `nil` and styles render no highlight.
    public let highlightsCheapest: Bool
    /// Explicit surface fill, or `nil` to let the style choose its default
    /// (resolve via ``surface(default:)``; the built-ins use `.bgElevatorPrimary`).
    public let surfaceKey: Theme.BackgroundColorKey?
    /// Fully custom per-date cell (`DatePriceStrip.cell(_:)`) — `(item,
    /// isSelected) → view`. Cell-based styles must wrap it in their own
    /// selection machinery; non-cell styles (`.chart`) may ignore it.
    public let cellSlot: ((DatePriceItem, Bool) -> AnyView)?
    /// Pages the visible date window backwards; `nil` hides the chevron pair.
    public let onPrev: (() -> Void)?
    /// Pages the visible date window forwards; `nil` hides the chevron pair.
    public let onNext: (() -> Void)?
    /// Micro-animations resolved by the component (`MicroMotion` ∧ ¬Reduce
    /// Motion) — gate scroll/selection animation on this; never read the motion
    /// environment.
    public let isMotionEnabled: Bool
    /// The environment's component density, captured by the component — scale
    /// chrome padding/gaps with ``spacing(_:)``.
    public let density: ComponentDensity
    /// The environment locale, captured by the component — use it for every
    /// price string so injected locales (and RTL demos) render correctly.
    public let locale: Locale

    /// Index of the lowest-priced *bookable* item, or `nil` when highlighting
    /// is off (or every item is unavailable). Capture once per body pass.
    public var cheapestIndex: Int? {
        guard highlightsCheapest else { return nil }
        let bookable = items.indices.filter { !items[$0].unavailable }
        return bookable.min(by: { items[$0].price < items[$1].price })
    }

    /// The explicit `surface(_:)` override, or the style's own default.
    public func surface(default fallback: Theme.BackgroundColorKey) -> Theme.BackgroundColorKey {
        surfaceKey ?? fallback
    }

    /// Density-scaled spacing — use for chrome padding/gaps so `.componentDensity`
    /// compacts or airs out the strip.
    public func spacing(_ key: Theme.SpacingKey) -> CGFloat { density.scale(key.value) }

    /// The `accent(_:)` override's base, else the theme's hero foreground — the
    /// selected-state chroma every built-in uses.
    public func accentForeground(_ theme: Theme) -> Color { accent?.base ?? theme.foreground(.fgHero) }

    /// The `cheapestTone(_:)` override's base, else the stock success token —
    /// the lowest-fare chroma every built-in uses.
    public func cheapestForeground(_ theme: Theme) -> Color {
        cheapestTone?.base ?? theme.foreground(.systemcolorsFgSuccess)
    }

    /// An item's price, formatted with the strip's resolved currency and the
    /// captured locale (default whole units, the pill/chart presentation).
    public func price(_ item: DatePriceItem, fractionDigits: Int = 0) -> String {
        item.price.formatted(
            .currency(code: currencyCode ?? "USD").precision(.fractionLength(fractionDigits)).locale(locale))
    }

    /// VoiceOver summary for the item at an index — "Fri 18 Jul, $1,768,
    /// lowest fare, unavailable" — shared so all styles speak one language.
    public func accessibilityLabel(at index: Int) -> String {
        let item = items[index]
        let dayDate = [item.weekday, item.date].compactMap { $0 }.joined(separator: " ")
        var parts = [dayDate, price(item)]
        if index == cheapestIndex { parts.append(String(themeKit: "lowest fare")) }
        if item.unavailable { parts.append(String(themeKit: "unavailable")) }
        return parts.joined(separator: ", ")
    }
}

// MARK: - Protocol

/// Defines a `DatePriceStrip`'s entire presentation. Implement `makeBody` to
/// lay out the configuration's date/price data. Set one with
/// `.datePriceStripStyle(_:)`; the default is ``GridDatePriceStripStyle``
/// with 3 columns.
public protocol DatePriceStripStyle {
    associatedtype Body: View
    @ViewBuilder @MainActor func makeBody(configuration: DatePriceStripConfiguration) -> Body
}

// MARK: - Shared building blocks (private to the built-ins)

/// One selectable cell, shared by `.grid` and `.strip`: the custom `cell(_:)`
/// slot wrapped in the selection machinery, or the built-in ``DatePriceCard``
/// configured from the strip's settings — extracted verbatim from the
/// pre-style component.
private struct DatePriceStripCellView: View {
    let configuration: DatePriceStripConfiguration
    let index: Int
    let cheapestIndex: Int?
    let pill: Bool

    var body: some View {
        let item = configuration.items[index]
        let isSelected = index == configuration.selectedIndex
        if let slot = configuration.cellSlot {
            Button { configuration.select(index) } label: { slot(item, isSelected) }
                .buttonStyle(.plain)
                .disabled(item.unavailable)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
        } else {
            configuredCard(item, isSelected: isSelected)
        }
    }

    private func configuredCard(_ item: DatePriceItem, isSelected: Bool) -> DatePriceCard {
        var card = DatePriceCard(item, isSelected: isSelected) { configuration.select(index) }
            .currency(configuration.currencyCode ?? "USD")
            .cheapest(index == cheapestIndex)
            .surface(configuration.surface(default: .bgElevatorPrimary))
            .accent(configuration.accent)
        if let tone = configuration.cheapestTone { card = card.cheapestTone(tone) }
        if pill { card = card.pill().pillSize(configuration.pillSize) }
        return card
    }
}

/// The prev/next paging chevron shared by `.grid` and `.chart` — extracted
/// verbatim from the pre-style component (fixed 30 pt circular hit shape).
private struct DatePriceStripPageButton: View {
    @Environment(\.theme) private var theme
    let systemName: String
    let label: String
    let action: (() -> Void)?

    var body: some View {
        Button { action?() } label: {
            Image(systemName: systemName).textStyle(.labelBase600)
                .foregroundStyle(theme.foreground(.fgHero))
                .mirrorsInRTL()
                .frame(width: 30, height: 30)
                .background(theme.background(.bgSecondaryLight), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.4 : 1)
        .accessibilityLabel(label)
    }
}

// MARK: - .grid(columns:)

/// Today's ``DatePriceStrip`` look, extracted verbatim: a multi-column
/// `LazyVGrid` of date/price cards, flanked by prev/next chevrons when paging
/// closures are set. The column count is part of the preset —
/// `.grid(columns: 3)` is the default.
public struct GridDatePriceStripStyle: DatePriceStripStyle {
    /// Number of grid columns (floored at 1).
    public let columns: Int

    public init(columns: Int = 3) { self.columns = max(1, columns) }

    public func makeBody(configuration: DatePriceStripConfiguration) -> some View {
        GridDatePriceStripChrome(configuration: configuration, columns: columns)
    }
}

private struct GridDatePriceStripChrome: View {
    let configuration: DatePriceStripConfiguration
    let columns: Int

    var body: some View {
        if configuration.onPrev != nil || configuration.onNext != nil {
            HStack(spacing: 8) {   // pre-style paged-grid gap, kept for pixel parity
                DatePriceStripPageButton(
                    systemName: "chevron.left",
                    label: String(themeKit: "Previous"),
                    action: configuration.onPrev)
                grid.frame(maxWidth: .infinity)
                DatePriceStripPageButton(
                    systemName: "chevron.right",
                    label: String(themeKit: "Next"),
                    action: configuration.onNext)
            }
        } else {
            grid
        }
    }

    private var grid: some View {
        let cheapest = configuration.cheapestIndex
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: columns), spacing: 8) {
            ForEach(Array(configuration.items.enumerated()), id: \.offset) { i, _ in
                DatePriceStripCellView(configuration: configuration, index: i, cheapestIndex: cheapest, pill: false)
            }
        }
    }
}

// MARK: - .strip

/// The horizontal "Timeline" strip, extracted verbatim: scrollable pills on a
/// surface track, with the selected pill auto-centered (animation gated on the
/// component-resolved ``DatePriceStripConfiguration/isMotionEnabled``). Paging
/// chevrons don't apply — the strip scrolls.
public struct StripDatePriceStripStyle: DatePriceStripStyle {
    public init() {}

    public func makeBody(configuration: DatePriceStripConfiguration) -> some View {
        StripDatePriceStripChrome(configuration: configuration)
    }
}

private struct StripDatePriceStripChrome: View {
    @Environment(\.theme) private var theme
    let configuration: DatePriceStripConfiguration

    var body: some View {
        let cheapest = configuration.cheapestIndex
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    ForEach(Array(configuration.items.enumerated()), id: \.offset) { i, _ in
                        DatePriceStripCellView(configuration: configuration, index: i, cheapestIndex: cheapest, pill: true)
                            .id(i)
                    }
                }
                .padding(configuration.spacing(.sm))
            }
            .background(theme.background(configuration.surface(default: .bgElevatorPrimary)))
            .onChange(of: configuration.selectedIndex) { _, new in
                withAnimation(configuration.isMotionEnabled ? .default : nil) {
                    proxy.scrollTo(new, anchor: .center)
                }
            }
        }
    }
}

// MARK: - .chart

/// A price-bar histogram — the Google-Flights price-graph pattern: one bar per
/// date, bar height proportional to the fare, price above and date below. Tap a
/// bar to select its date; the cheapest bar takes the lowest-fare tone, the
/// selected bar the accent, unavailable dates render muted and disabled. Sits
/// on the strip's surface track; honors the paging chevrons. The custom
/// `cell(_:)` slot doesn't apply — the chart draws its own bars.
public struct ChartDatePriceStripStyle: DatePriceStripStyle {
    public init() {}

    public func makeBody(configuration: DatePriceStripConfiguration) -> some View {
        ChartDatePriceStripChrome(configuration: configuration)
    }
}

private struct ChartDatePriceStripChrome: View {
    @Environment(\.theme) private var theme
    let configuration: DatePriceStripConfiguration

    // Genuine dimensions with no semantic token (SKILL): the bar column's fixed
    // vertical scale — internal to the preset, never exposed as a knob.
    private let chartHeight: CGFloat = 96
    private let minBarHeight: CGFloat = 18

    var body: some View {
        if configuration.onPrev != nil || configuration.onNext != nil {
            HStack(spacing: 8) {   // matches the paged-grid gap
                DatePriceStripPageButton(
                    systemName: "chevron.left",
                    label: String(themeKit: "Previous"),
                    action: configuration.onPrev)
                chart.frame(maxWidth: .infinity)
                DatePriceStripPageButton(
                    systemName: "chevron.right",
                    label: String(themeKit: "Next"),
                    action: configuration.onNext)
            }
        } else {
            chart
        }
    }

    private var chart: some View {
        let cheapest = configuration.cheapestIndex
        return HStack(alignment: .bottom, spacing: Theme.SpacingKey.xs.value) {
            ForEach(Array(configuration.items.enumerated()), id: \.offset) { i, _ in
                bar(at: i, cheapestIndex: cheapest)
            }
        }
        .padding(configuration.spacing(.sm))
        .background(
            theme.background(configuration.surface(default: .bgElevatorPrimary)),
            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
    }

    private func bar(at index: Int, cheapestIndex: Int?) -> some View {
        let item = configuration.items[index]
        let isSelected = index == configuration.selectedIndex
        let isCheapest = index == cheapestIndex
        return Button { configuration.select(index) } label: {
            VStack(spacing: Theme.SpacingKey.xs.value) {
                Text(configuration.price(item))
                    .textStyle(isSelected ? .overline500 : .overline400)
                    .foregroundStyle(priceColor(item, isSelected: isSelected, isCheapest: isCheapest))
                    .lineLimit(1)
                UnevenRoundedRectangle(
                    topLeadingRadius: Theme.RadiusRole.selector.value,
                    topTrailingRadius: Theme.RadiusRole.selector.value,
                    style: .continuous)
                    .fill(barFill(item, isSelected: isSelected, isCheapest: isCheapest))
                    .frame(height: barHeight(for: item))
                Text(item.date)
                    .textStyle(isSelected ? .labelSm600 : .overline400)
                    .foregroundStyle(dateColor(item, isSelected: isSelected))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(item.unavailable)
        .accessibilityLabel(configuration.accessibilityLabel(at: index))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Bar height ∝ price, normalized across *all* items (unavailable included,
    /// so the scale stays stable): the cheapest date draws at ``minBarHeight``,
    /// the priciest at ``chartHeight``. A flat fare curve draws mid-height.
    private func barHeight(for item: DatePriceItem) -> CGFloat {
        let prices = configuration.items.map(\.price)
        guard let lowest = prices.min(), let highest = prices.max(), highest > lowest else {
            return chartHeight * 0.62
        }
        let fraction = CGFloat(truncating: NSDecimalNumber(decimal: (item.price - lowest) / (highest - lowest)))
        return minBarHeight + fraction * (chartHeight - minBarHeight)
    }

    private func barFill(_ item: DatePriceItem, isSelected: Bool, isCheapest: Bool) -> Color {
        if item.unavailable { return theme.background(.bgSecondaryLight) }
        if isSelected { return configuration.accentForeground(theme) }
        if isCheapest { return configuration.cheapestForeground(theme) }
        return (configuration.accent ?? .primary).soft
    }

    private func priceColor(_ item: DatePriceItem, isSelected: Bool, isCheapest: Bool) -> Color {
        if item.unavailable { return theme.text(.textDisabled) }
        if isSelected { return configuration.accentForeground(theme) }
        if isCheapest { return configuration.cheapestForeground(theme) }
        return theme.text(.textSecondary)
    }

    private func dateColor(_ item: DatePriceItem, isSelected: Bool) -> Color {
        if item.unavailable { return theme.text(.textDisabled) }
        return isSelected ? theme.text(.textPrimary) : theme.text(.textTertiary)
    }
}

// MARK: - Static accessors

public extension DatePriceStripStyle where Self == GridDatePriceStripStyle {
    /// The stock multi-column grid of date/price cards — today's strip. The
    /// default is `.grid(columns: 3)`.
    static func grid(columns: Int = 3) -> GridDatePriceStripStyle { GridDatePriceStripStyle(columns: columns) }
}
public extension DatePriceStripStyle where Self == StripDatePriceStripStyle {
    /// The horizontal "Timeline" strip of scrollable pills.
    static var strip: StripDatePriceStripStyle { StripDatePriceStripStyle() }
}
public extension DatePriceStripStyle where Self == ChartDatePriceStripStyle {
    /// A price-bar histogram — bar height ∝ price (the Google-Flights pattern).
    static var chart: ChartDatePriceStripStyle { ChartDatePriceStripStyle() }
}

// MARK: - Type erasure + environment plumbing

struct AnyDatePriceStripStyle: DatePriceStripStyle {
    private let _makeBody: @MainActor (DatePriceStripConfiguration) -> AnyView
    init<S: DatePriceStripStyle>(_ style: sending S) {
        _makeBody = { AnyView(style.makeBody(configuration: $0)) }
    }
    func makeBody(configuration: DatePriceStripConfiguration) -> AnyView { _makeBody(configuration) }
}

private struct DatePriceStripStyleKey: EnvironmentKey {
    static let defaultValue = AnyDatePriceStripStyle(GridDatePriceStripStyle(columns: 3))
}

extension EnvironmentValues {
    var datePriceStripStyle: AnyDatePriceStripStyle {
        get { self[DatePriceStripStyleKey.self] }
        set { self[DatePriceStripStyleKey.self] = newValue }
    }
}

public extension View {
    /// Set the ``DatePriceStripStyle`` for `DatePriceStrip`s in this view and
    /// its descendants — one screen can mix presentations per section.
    func datePriceStripStyle<S: DatePriceStripStyle>(_ style: sending S) -> some View {
        environment(\.datePriceStripStyle, AnyDatePriceStripStyle(style))
    }
}

// MARK: - Previews

/// A custom style built purely on the public API — what an app target would
/// write: a vertical agenda list, one row per date with the price trailing.
private struct AgendaDatePriceStripStyle: DatePriceStripStyle {
    func makeBody(configuration: DatePriceStripConfiguration) -> some View {
        AgendaChrome(configuration: configuration)
    }

    private struct AgendaChrome: View {
        @Environment(\.theme) private var theme
        let configuration: DatePriceStripConfiguration

        var body: some View {
            let cheapest = configuration.cheapestIndex
            return VStack(spacing: Theme.SpacingKey.xs.value) {
                ForEach(Array(configuration.items.enumerated()), id: \.offset) { i, item in
                    row(i, item, isCheapest: i == cheapest)
                }
            }
        }

        private func row(_ index: Int, _ item: DatePriceItem, isCheapest: Bool) -> some View {
            let isSelected = index == configuration.selectedIndex
            return Button { configuration.select(index) } label: {
                HStack {
                    Text([item.weekday, item.date].compactMap { $0 }.joined(separator: " "))
                        .textStyle(isSelected ? .labelSm700 : .bodySm400)
                        .foregroundStyle(item.unavailable ? theme.text(.textDisabled) : theme.text(.textPrimary))
                    Spacer()
                    Text(configuration.price(item))
                        .textStyle(.labelSm600)
                        .foregroundStyle(isCheapest
                            ? configuration.cheapestForeground(theme)
                            : theme.text(.textSecondary))
                }
                .padding(configuration.spacing(.sm))
                .background(
                    isSelected ? (configuration.accent ?? .primary).soft : theme.background(.bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value))
            }
            .buttonStyle(.plain)
            .disabled(item.unavailable)
            .accessibilityLabel(configuration.accessibilityLabel(at: index))
            .accessibilityAddTraits(isSelected ? .isSelected : [])
        }
    }
}

#Preview("DatePriceStripStyle — presets × light/dark") {
    @Previewable @State var sel = 1
    let items = [
        DatePriceItem("17 Jul", price: 1_697.99, weekday: "Fri"),
        DatePriceItem("18 Jul", price: 1_767.99, weekday: "Sat"),
        DatePriceItem("19 Jul", price: 1_960.99, weekday: "Sun", unavailable: true),
        DatePriceItem("20 Jul", price: 1_914.99, weekday: "Mon"),
        DatePriceItem("21 Jul", price: 1_474.99, weekday: "Tue"),
        DatePriceItem("22 Jul", price: 1_483.99, weekday: "Wed"),
    ]
    PreviewMatrix("DatePriceStripStyle") {
        PreviewCase("Grid (default, 3 columns)") { DatePriceStrip(items, selection: $sel) }
        PreviewCase("Grid · 2 columns") {
            DatePriceStrip(items, selection: $sel).datePriceStripStyle(.grid(columns: 2))
        }
        PreviewCase("Grid · paged") {
            DatePriceStrip(items, selection: $sel).onPage(prev: {}, next: {})
        }
        PreviewCase("Strip") { DatePriceStrip(items, selection: $sel).datePriceStripStyle(.strip) }
        PreviewCase("Chart") { DatePriceStrip(items, selection: $sel).datePriceStripStyle(.chart) }
        PreviewCase("Chart · accent + cheapest tone + paged") {
            DatePriceStrip(items, selection: $sel)
                .accent(.info).cheapestTone(.warning)
                .onPage(prev: {}, next: {})
                .datePriceStripStyle(.chart)
        }
        PreviewCase("Custom (in-preview)") {
            DatePriceStrip(items, selection: $sel).datePriceStripStyle(AgendaDatePriceStripStyle())
        }
    }
}
