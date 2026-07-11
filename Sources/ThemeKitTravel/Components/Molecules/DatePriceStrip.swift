//
//  DatePriceStrip.swift
//  ThemeKit
//
//  Molecule. A grid of date + price cards — pick a departure date and see its
//  cheapest fare. Composed from the standalone ``DatePriceCard`` so a developer can
//  build their own layout (a row, a carousel…). The lowest fare is auto-highlighted.
//  Token-bound.
//

import SwiftUI
import ThemeKit

/// One date/price option in a ``DatePriceStrip``.
public struct DatePriceItem: Identifiable, Sendable {
    public var id: String { date }
    public let date: String    // e.g. "18 Jul"
    public let price: Decimal
    /// Optional weekday overline, e.g. "Fri" (rendered above the date on cards).
    public let weekday: String?
    /// Marks the date as sold out / not bookable — the card renders disabled and
    /// the strip skips it for selection and the cheapest-fare highlight.
    public let unavailable: Bool

    public init(_ date: String, price: Decimal, weekday: String? = nil, unavailable: Bool = false) {
        self.date = date
        self.price = price
        self.weekday = weekday
        self.unavailable = unavailable
    }
}

/// Layout of a ``DatePriceStrip``: a multi-column ``grid(columns:)`` (the stock
/// three-column presentation) or the horizontal ``strip`` of scrollable pills.
/// `.strip()` / `.columns(_:)` remain as forwarding sugar.
public enum DatePriceLayout: Sendable {
    case grid(columns: Int)
    case strip
}

/// Height ramp for the strip-layout pills (internal 32 / 40 / 48 pt).
public enum DatePricePillSize: Sendable {
    case compact, regular, large

    var height: CGFloat {
        switch self {
        case .compact: 32
        case .regular: 40
        case .large: 48
        }
    }
}

/// A single selectable date+price card. Public so it can be reused outside ``DatePriceStrip``.
/// The shell (surface, hairline, selected frame) is drawn by the active `CardStyle`;
/// selection flows through `Configuration.isSelected`, so `.cardStyle(_:)` reskins it.
public struct DatePriceCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let item: DatePriceItem
    private let isSelected: Bool
    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var currencyCode: String?
    private var isCheapest = false
    private var pill = false
    private var surface: Theme.BackgroundColorKey = .bgElevatorPrimary
    private var accent: SemanticColor?
    private var cheapestToneOverride: SemanticColor?
    private var pillSize: DatePricePillSize = .regular

    public init(_ item: DatePriceItem, isSelected: Bool, action: @escaping () -> Void) {   // R1
        self.item = item
        self.isSelected = isSelected
        self.action = action
    }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    /// Selected-state foreground — the accent's base shade, or the stock hero.
    private var selectedColor: Color { accent?.base ?? theme.foreground(.fgHero) }
    /// Lowest-fare foreground — the tone's base shade, or the stock success token.
    private var cheapestColor: Color { cheapestToneOverride?.base ?? theme.foreground(.systemcolorsFgSuccess) }

    private var priceColor: Color {
        if item.unavailable { return theme.text(.textDisabled) }
        return isSelected ? selectedColor : (isCheapest ? cheapestColor : theme.text(.textPrimary))
    }

    /// VoiceOver label — built in explicit steps to keep the SwiftUI body type-checkable.
    private var accessibilityText: String {
        let dayDate = [item.weekday, item.date].compactMap { $0 }.joined(separator: " ")
        let priceText = item.price.formatted(
            .currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale))
        var parts = [dayDate, priceText]
        if isCheapest { parts.append(String(themeKit: "lowest fare")) }
        if item.unavailable { parts.append(String(themeKit: "unavailable")) }
        return parts.joined(separator: ", ")
    }

    public var body: some View {
        Button(action: action) {
            if pill { pillShell } else { cardedShell }
        }
        .buttonStyle(.plain)
        .disabled(item.unavailable)
        .accessibilityLabel(accessibilityText)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// The default carded shell — drawn by the active `CardStyle` (grid layout).
    private var cardedShell: some View {
        // Flat card → `.none` elevation keeps the classic 1pt hairline.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: .none,
            isSelected: isSelected,
            isPressed: false,
            surfaceKey: surface,
            radius: .selector))
    }

    /// The pill shell — the horizontal "Timeline" strip presentation: a rounded
    /// capsule that turns accent-soft with a 2pt accent border + semibold date
    /// when selected. Brand color resolves from the theme (or ``accent(_:)``).
    private var pillShell: some View {
        let shape = Capsule(style: .continuous)
        return VStack(spacing: 2) {
            Text(item.date)
                .textStyle(isSelected ? .labelSm600 : .bodySm400)
                .foregroundStyle(item.unavailable ? theme.text(.textDisabled) : theme.text(.textPrimary))
            Text(item.price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale)))
                .textStyle(.overline400)
                .foregroundStyle(item.unavailable
                                 ? theme.text(.textDisabled)
                                 : (isCheapest ? cheapestColor : theme.text(.textTertiary)))
        }
        .padding(.horizontal, Theme.SpacingKey.base.value)
        .frame(height: pillSize.height)
        .background(isSelected ? (accent ?? .primary).soft : theme.background(.bgWhite), in: shape)
        .overlay {
            if isSelected { shape.strokeBorder(accent?.base ?? theme.border(.borderHero), lineWidth: 2) }
        }
    }

    /// The card's inner layout — everything inside the shell. The selected wash is
    /// the accent's `bg` shade (token-fed; not expressible as a `surfaceKey`, so it
    /// stays in-content, layered over the style's surface fill).
    private var cardContent: some View {
        VStack(spacing: 2) {
            if let weekday = item.weekday {
                Text(weekday).textStyle(.overline400)
                    .foregroundStyle(item.unavailable ? theme.text(.textDisabled) : theme.text(.textTertiary))
            }
            Text(item.date).textStyle(.labelSm600)
                .foregroundStyle(item.unavailable
                                 ? theme.text(.textDisabled)
                                 : (isSelected ? selectedColor : theme.text(.textSecondary)))
            Text(item.price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(2)).locale(locale)))
                .textStyle(.labelBase700).foregroundStyle(priceColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
        .padding(.horizontal, Theme.SpacingKey.xs.value)
        .background(isSelected ? (accent ?? .primary).bg : Color.clear)
    }
}

public extension DatePriceCard {
    /// Currency code for the price. Unset, it resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Highlights this as the lowest fare (price shown in success green).
    func cheapest(_ on: Bool = true) -> Self { copy { $0.isCheapest = on } }
    /// Render as a horizontal-strip pill (rounded capsule) instead of a card.
    func pill(_ on: Bool = true) -> Self { copy { $0.pill = on } }
    /// Surface token for the carded shell (default `.bgElevatorPrimary`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surface = key } }
    /// Semantic accent for the selected state — pill fill `soft` + border `base`,
    /// card date/price `base`, wash `bg`. `nil` (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Semantic tone for the lowest-fare highlight (default `.success`).
    func cheapestTone(_ color: SemanticColor) -> Self { copy { $0.cheapestToneOverride = color } }
    /// Height ramp for the pill presentation (default `.regular`, 40 pt).
    func pillSize(_ s: DatePricePillSize) -> Self { copy { $0.pillSize = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

public struct DatePriceStrip: View {
    @Environment(\.componentDensity) private var density

    private let items: [DatePriceItem]
    @Binding private var selection: Int
    // Appearance/state — mutated only through the modifiers below (R2).
    @Environment(\.theme) private var theme
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale
    private var currencyCode: String?
    private var columns = 3
    private var highlightsCheapest = true
    private var stripLayout = false
    private var surface: Theme.BackgroundColorKey = .bgElevatorPrimary
    private var accent: SemanticColor?
    private var cheapestToneOverride: SemanticColor?
    private var pillSize: DatePricePillSize = .regular
    private var customCell: ((DatePriceItem, Bool) -> AnyView)?
    private var onPrev: (() -> Void)?
    private var onNext: (() -> Void)?

    public init(_ items: [DatePriceItem], selection: Binding<Int>) {   // R1
        self.items = items
        self._selection = selection
    }

    private var cheapestIndex: Int? {
        guard highlightsCheapest else { return nil }
        let bookable = items.indices.filter { !items[$0].unavailable }
        return bookable.min(by: { items[$0].price < items[$1].price })
    }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    /// Passed down explicitly so every card renders the strip's one resolved code.
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        if stripLayout {
            stripView
        } else if onPrev != nil || onNext != nil {
            HStack(spacing: 8) {
                pageButton("chevron.left", label: String(themeKit: "Previous"), onPrev)
                gridView.frame(maxWidth: .infinity)
                pageButton("chevron.right", label: String(themeKit: "Next"), onNext)
            }
        } else {
            gridView
        }
    }

    /// The horizontal "Timeline" strip — scrollable pills on a surface, with the
    /// selected pill auto-centered. The scroll/selection machinery also hosts a
    /// custom ``cell(_:)`` when one is set.
    private var stripView: some View {
        let cheapest = cheapestIndex
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        cell(i, item, cheapest: cheapest, pill: true)
                            .id(i)
                    }
                }
                .padding(density.scale(Theme.SpacingKey.sm.value))
            }
            .background(theme.background(surface))
            .onChange(of: selection) { _, new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private var gridView: some View {
        let cheapest = cheapestIndex
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, columns)), spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                cell(i, item, cheapest: cheapest, pill: false)
            }
        }
    }

    /// One cell — a fully custom ``cell(_:)`` slot (selection machinery retained)
    /// or the built-in ``DatePriceCard``, configured with the strip's settings.
    @ViewBuilder private func cell(_ i: Int, _ item: DatePriceItem, cheapest: Int?, pill: Bool) -> some View {
        if let customCell {
            Button { selection = i } label: { customCell(item, i == selection) }
                .buttonStyle(.plain)
                .disabled(item.unavailable)
                .accessibilityAddTraits(i == selection ? .isSelected : [])
        } else {
            configuredCard(i, item, cheapest: cheapest, pill: pill)
        }
    }

    private func configuredCard(_ i: Int, _ item: DatePriceItem, cheapest: Int?, pill: Bool) -> DatePriceCard {
        var card = DatePriceCard(item, isSelected: i == selection) { selection = i }
            .currency(resolvedCurrency)
            .cheapest(i == cheapest)
            .surface(surface)
            .accent(accent)
        if let cheapestToneOverride { card = card.cheapestTone(cheapestToneOverride) }
        if pill { card = card.pill().pillSize(pillSize) }
        return card
    }

    private func pageButton(_ name: String, label: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: name).textStyle(.labelBase600)
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DatePriceStrip {
    /// Currency code for the prices. Unset, it resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Number of columns for the grid layout (default 3). Sugar for
    /// `.layout(.grid(columns:))`.
    func columns(_ count: Int) -> Self { copy { $0.columns = max(1, count) } }
    /// Lay the dates out as a horizontal **strip** of scrollable pills (the
    /// "Timeline" presentation) instead of the multi-column grid. Sugar for
    /// `.layout(.strip)`.
    func strip(_ on: Bool = true) -> Self { copy { $0.stripLayout = on } }
    /// Layout of the strip: `.grid(columns:)` (default, 3 columns) or the
    /// horizontal `.strip` of scrollable pills. Consolidates `.strip()` / `.columns(_:)`.
    func layout(_ l: DatePriceLayout) -> Self {
        copy {
            switch l {
            case .grid(let columns):
                $0.stripLayout = false
                $0.columns = max(1, columns)
            case .strip:
                $0.stripLayout = true
            }
        }
    }
    /// Auto-highlight the lowest fare in success green (default on).
    func highlightCheapest(_ on: Bool = true) -> Self { copy { $0.highlightsCheapest = on } }
    /// Surface token for the strip track and the cards it builds (default `.bgElevatorPrimary`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surface = key } }
    /// Semantic accent for the selected state, forwarded to every card — pill
    /// fill `soft` + border `base`, card date/price `base`, wash `bg`.
    /// `nil` (default) keeps the stock hero chroma.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    /// Semantic tone for the lowest-fare highlight (default `.success`).
    func cheapestTone(_ color: SemanticColor) -> Self { copy { $0.cheapestToneOverride = color } }
    /// Height ramp for the strip-layout pills (default `.regular`, 40 pt).
    func pillSize(_ s: DatePricePillSize) -> Self { copy { $0.pillSize = s } }
    /// Fully custom cell — render your own view per date; the strip keeps its
    /// selection, disabled-date and scroll-centering machinery.
    func cell<V: View>(@ViewBuilder _ content: @escaping (DatePriceItem, Bool) -> V) -> Self {
        copy { $0.customCell = { item, isSelected in AnyView(content(item, isSelected)) } }
    }
    /// Adds prev/next paging chevrons flanking the strip.
    func onPage(prev: @escaping () -> Void, next: @escaping () -> Void) -> Self { copy { $0.onPrev = prev; $0.onNext = next } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var sel = 1
    let items = [
        DatePriceItem("17 Jul", price: 1_697.99), DatePriceItem("18 Jul", price: 1_767.99),
        DatePriceItem("19 Jul", price: 1_960.99), DatePriceItem("20 Jul", price: 1_914.99),
        DatePriceItem("21 Jul", price: 1_474.99), DatePriceItem("22 Jul", price: 1_483.99),
    ]
    PreviewMatrix("DatePriceStrip") {
        PreviewCase("Timeline strip (pills)") { DatePriceStrip(items, selection: $sel).strip() }
        PreviewCase("Grid") { DatePriceStrip(items, selection: $sel) }
        PreviewCase("Paged grid") { DatePriceStrip(items, selection: $sel).onPage(prev: {}, next: {}) }
        PreviewCase("Custom surface") { DatePriceStrip(items, selection: $sel).surface(.bgSecondaryLight) }
        PreviewCase("Accent + cheapest tone") {
            DatePriceStrip(items, selection: $sel).accent(.info).cheapestTone(.warning)
        }
        PreviewCase("Strip · large pills · accent") {
            DatePriceStrip(items, selection: $sel).layout(.strip).pillSize(.large).accent(.success)
        }
        PreviewCase("Weekdays + unavailable · 2 columns") {
            DatePriceStrip(
                [
                    DatePriceItem("17 Jul", price: 1_697.99, weekday: "Fri"),
                    DatePriceItem("18 Jul", price: 1_767.99, weekday: "Sat", unavailable: true),
                    DatePriceItem("19 Jul", price: 1_474.99, weekday: "Sun"),
                    DatePriceItem("20 Jul", price: 1_914.99, weekday: "Mon"),
                ],
                selection: $sel
            )
            .layout(.grid(columns: 2))
        }
        PreviewCase("Custom cell slot") {
            DatePriceStrip(items, selection: $sel).strip().cell { item, isSelected in
                VStack(spacing: 2) {
                    Text(item.date).textStyle(isSelected ? .labelSm700 : .bodySm400)
                    Text(item.price.formatted(.currency(code: "USD").precision(.fractionLength(0))))
                        .textStyle(.overline500)
                }
                .padding(Theme.SpacingKey.sm.value)
                .background(isSelected ? SemanticColor.accent.soft : .clear,
                            in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value))
            }
        }
    }
}

#Preview("Selected card + outlined style") {
    HStack(spacing: 8) {
        DatePriceCard(DatePriceItem("17 Jul", price: 1_697.99), isSelected: true) { }
        DatePriceCard(DatePriceItem("18 Jul", price: 1_474.99), isSelected: false) { }
            .cheapest()
    }
    .cardStyle(.outlined)
    .padding()
}
