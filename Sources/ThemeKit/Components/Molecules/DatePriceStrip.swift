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

/// One date/price option in a ``DatePriceStrip``.
public struct DatePriceItem: Identifiable, Sendable {
    public var id: String { date }
    public let date: String    // e.g. "18 Jul"
    public let price: Decimal
    public init(_ date: String, price: Decimal) {
        self.date = date
        self.price = price
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

    public init(_ item: DatePriceItem, isSelected: Bool, action: @escaping () -> Void) {   // R1
        self.item = item
        self.isSelected = isSelected
        self.action = action
    }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    private var priceColor: Color {
        isSelected ? theme.foreground(.fgHero) : (isCheapest ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textPrimary))
    }

    public var body: some View {
        Button(action: action) {
            if pill { pillShell } else { cardedShell }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            "\(item.date), "
                + item.price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale))
                + (isCheapest ? ", " + String(themeKit: "lowest fare") : "")
        )
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
            surfaceKey: .bgElevatorPrimary,
            radius: .selector))
    }

    /// The pill shell — the horizontal "Timeline" strip presentation: a rounded
    /// capsule that turns hero-soft with a 2pt hero border + semibold date when
    /// selected. Brand color resolves from the theme.
    private var pillShell: some View {
        let shape = Capsule(style: .continuous)
        return VStack(spacing: 2) {
            Text(item.date)
                .textStyle(isSelected ? .labelSm600 : .bodySm400)
                .foregroundStyle(theme.text(.textPrimary))
            Text(item.price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale)))
                .textStyle(.overline400)
                .foregroundStyle(isCheapest ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textTertiary))
        }
        .padding(.horizontal, Theme.SpacingKey.base.value)
        .frame(height: 40)
        .background(isSelected ? SemanticColor.primary.soft : theme.background(.bgWhite), in: shape)
        .overlay { if isSelected { shape.strokeBorder(theme.border(.borderHero), lineWidth: 2) } }
    }

    /// The card's inner layout — everything inside the shell. The 6% hero wash on
    /// selection is not expressible as a `surfaceKey` token, so it stays in-content,
    /// layered over the style's surface fill (a custom style cannot recolour it).
    private var cardContent: some View {
        VStack(spacing: 2) {
            Text(item.date).textStyle(.labelSm600)
                .foregroundStyle(isSelected ? theme.foreground(.fgHero) : theme.text(.textSecondary))
            Text(item.price.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(2)).locale(locale)))
                .textStyle(.labelBase700).foregroundStyle(priceColor)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
        .padding(.horizontal, Theme.SpacingKey.xs.value)
        .background(isSelected ? theme.background(.bgHero).opacity(0.06) : Color.clear)
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
    private var onPrev: (() -> Void)?
    private var onNext: (() -> Void)?

    public init(_ items: [DatePriceItem], selection: Binding<Int>) {   // R1
        self.items = items
        self._selection = selection
    }

    private var cheapestIndex: Int? {
        guard highlightsCheapest, !items.isEmpty else { return nil }
        return items.indices.min(by: { items[$0].price < items[$1].price })
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
    /// selected pill auto-centered.
    private var stripView: some View {
        let cheapest = cheapestIndex
        return ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                        DatePriceCard(item, isSelected: i == selection) { selection = i }
                            .currency(resolvedCurrency)
                            .cheapest(i == cheapest)
                            .pill()
                            .id(i)
                    }
                }
                .padding(density.scale(Theme.SpacingKey.sm.value))
            }
            .background(theme.background(.bgElevatorPrimary))
            .onChange(of: selection) { _, new in
                withAnimation { proxy.scrollTo(new, anchor: .center) }
            }
        }
    }

    private var gridView: some View {
        let cheapest = cheapestIndex
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, columns)), spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                DatePriceCard(item, isSelected: i == selection) { selection = i }
                    .currency(resolvedCurrency)
                    .cheapest(i == cheapest)
            }
        }
    }

    private func pageButton(_ name: String, label: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: name).font(.system(size: 13, weight: .semibold))
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
    /// Number of columns for the grid layout (default 3).
    func columns(_ count: Int) -> Self { copy { $0.columns = max(1, count) } }
    /// Lay the dates out as a horizontal **strip** of scrollable pills (the
    /// "Timeline" presentation) instead of the multi-column grid.
    func strip(_ on: Bool = true) -> Self { copy { $0.stripLayout = on } }
    /// Auto-highlight the lowest fare in success green (default on).
    func highlightCheapest(_ on: Bool = true) -> Self { copy { $0.highlightsCheapest = on } }
    /// Adds prev/next paging chevrons flanking the strip.
    func onPage(prev: @escaping () -> Void, next: @escaping () -> Void) -> Self { copy { $0.onPrev = prev; $0.onNext = next } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel = 1
        private let items = [
            DatePriceItem("17 Jul", price: 1_697.99), DatePriceItem("18 Jul", price: 1_767.99),
            DatePriceItem("19 Jul", price: 1_960.99), DatePriceItem("20 Jul", price: 1_914.99),
            DatePriceItem("21 Jul", price: 1_474.99), DatePriceItem("22 Jul", price: 1_483.99),
        ]
        var body: some View {
            VStack(spacing: 16) {
                DatePriceStrip(items, selection: $sel).strip()          // Timeline pills
                DatePriceStrip(items, selection: $sel).padding()        // grid
            }
        }
    }
    return Demo()
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
