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
public struct DatePriceCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density

    private let item: DatePriceItem
    private let isSelected: Bool
    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var currencyCode = "TRY"
    private var isCheapest = false

    public init(_ item: DatePriceItem, isSelected: Bool, action: @escaping () -> Void) {   // R1
        self.item = item
        self.isSelected = isSelected
        self.action = action
    }

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous) }
    private var priceColor: Color {
        isSelected ? theme.foreground(.fgHero) : (isCheapest ? theme.foreground(.systemcolorsFgSuccess) : theme.text(.textPrimary))
    }

    public var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(item.date).textStyle(.labelSm600)
                    .foregroundStyle(isSelected ? theme.foreground(.fgHero) : theme.text(.textSecondary))
                Text(item.price.formatted(.currency(code: currencyCode).precision(.fractionLength(2))))
                    .textStyle(.labelBase700).foregroundStyle(priceColor)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, density.scale(Theme.SpacingKey.sm.value))
            .padding(.horizontal, Theme.SpacingKey.xs.value)
            .background(isSelected ? theme.background(.bgHero).opacity(0.06) : theme.background(.bgElevatorPrimary), in: shape)
            .overlay(shape.stroke(isSelected ? theme.foreground(.fgHero) : theme.border(.borderPrimary), lineWidth: isSelected ? 1.5 : 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(item.date), \(item.price.formatted(.currency(code: currencyCode).precision(.fractionLength(0))))\(isCheapest ? ", lowest fare" : "")")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

public extension DatePriceCard {
    /// Currency code for the price (default "TRY").
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Highlights this as the lowest fare (price shown in success green).
    func cheapest(_ on: Bool = true) -> Self { copy { $0.isCheapest = on } }

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
    private var currencyCode = "TRY"
    private var columns = 3
    private var highlightsCheapest = true
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

    public var body: some View {
        if onPrev != nil || onNext != nil {
            HStack(spacing: 8) {
                pageButton("chevron.left", onPrev)
                gridView.frame(maxWidth: .infinity)
                pageButton("chevron.right", onNext)
            }
        } else {
            gridView
        }
    }

    private var gridView: some View {
        let cheapest = cheapestIndex
        return LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: max(1, columns)), spacing: 8) {
            ForEach(Array(items.enumerated()), id: \.offset) { i, item in
                DatePriceCard(item, isSelected: i == selection) { selection = i }
                    .currency(currencyCode)
                    .cheapest(i == cheapest)
            }
        }
    }

    private func pageButton(_ name: String, _ action: (() -> Void)?) -> some View {
        Button { action?() } label: {
            Image(systemName: name).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.foreground(.fgHero))
                .frame(width: 30, height: 30)
                .background(theme.background(.bgSecondaryLight), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
        .opacity(action == nil ? 0.4 : 1)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DatePriceStrip {
    /// Currency code for the prices (default "TRY").
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Number of columns (default 3).
    func columns(_ count: Int) -> Self { copy { $0.columns = max(1, count) } }
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
        var body: some View { DatePriceStrip(items, selection: $sel).padding() }
    }
    return Demo()
}
