//
//  PriceTrendChart.swift
//  ThemeKit
//
//  Molecule. A per-day price bar chart — pick a day to see its fare. A title row
//  with prev/next paging, gradient bars aligned on a common baseline, a highlighted
//  selected day, min/max axis lines and optional horizontal scrolling. Highly
//  configurable via modifiers. Token-bound. Sibling of ``PriceHistogram``.
//

import SwiftUI

/// One day/point in a ``PriceTrendChart``.
public struct PriceTrendPoint: Identifiable, Sendable {
    public var id: String { "\(label)-\(sublabel ?? "")" }
    public let label: String       // e.g. "18"
    public let sublabel: String?   // e.g. "Sat"
    public let price: Decimal
    public init(_ label: String, sublabel: String? = nil, price: Decimal) {
        self.label = label
        self.sublabel = sublabel
        self.price = price
    }
}

public struct PriceTrendChart: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let points: [PriceTrendPoint]
    @Binding private var selection: Int
    // Appearance/state — mutated only through the modifiers below (R2).
    private var title: String?
    private var currencyCode: String?
    private var accentColor: SemanticColor?
    private var selectionColorToken: SemanticColor?
    private var barHeight: CGFloat = 120
    private var barWidth: CGFloat = 26
    private var spacing: CGFloat = 6
    private var cornerRole: Theme.RadiusRole = .selector
    private var showsAxis = false
    private var scrollable = false
    private var maxDays: Int?
    private var showsValues = false
    private var showsWeekday = true
    private var useGradient = true
    private var onPrev: (() -> Void)?
    private var onNext: (() -> Void)?

    public init(_ points: [PriceTrendPoint], selection: Binding<Int>) {   // R1
        self.points = points
        self._selection = selection
    }

    // MARK: Derived

    private var visiblePoints: [PriceTrendPoint] { maxDays.map { Array(points.prefix(max(1, $0))) } ?? points }
    private var accent: Color { accentColor?.base ?? theme.foreground(.fgHero) }
    private var maxPrice: Decimal { visiblePoints.map(\.price).max() ?? 1 }
    private var minPrice: Decimal { visiblePoints.map(\.price).min() ?? 0 }
    private var minFraction: CGFloat { maxPrice > 0 ? CGFloat(NSDecimalNumber(decimal: minPrice / maxPrice).doubleValue) : 0 }
    private var labelReserve: CGFloat { showsWeekday ? 32 : 18 }
    private var valueReserve: CGFloat { showsValues ? 16 : 0 }
    private var barAreaHeight: CGFloat { max(10, barHeight - labelReserve - valueReserve) }
    private var barFill: AnyShapeStyle {
        useGradient ? AnyShapeStyle(LinearGradient(colors: [accent, accent.opacity(0.5)], startPoint: .bottom, endPoint: .top)) : AnyShapeStyle(accent)
    }
    private var selectionBg: Color { selectionColorToken?.base ?? theme.text(.textPrimary) }
    private var selectionFg: Color { selectionColorToken?.onSolid ?? theme.text(.textSecondaryInverse) }
    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }
    private func priceText(_ p: Decimal) -> String { p.formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0))) }

    // MARK: Body

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if title != nil || onPrev != nil || onNext != nil { header }
            ZStack(alignment: .topLeading) {
                if showsAxis { axisOverlay }
                barsContainer
            }
            .frame(height: barHeight)
        }
    }

    @ViewBuilder private var barsContainer: some View {
        if scrollable {
            ScrollView(.horizontal, showsIndicators: false) { barsStack }
        } else {
            barsStack
        }
    }

    private var barsStack: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Array(visiblePoints.enumerated()), id: \.offset) { i, _ in bar(i) }
        }
        .frame(maxWidth: scrollable ? nil : .infinity)
    }

    /// Faint min/max reference lines behind the bars (max at the top, min at the shortest-bar level).
    private var axisOverlay: some View {
        GeometryReader { geo in
            let area = geo.size.height - labelReserve - valueReserve
            let minY = max(0, valueReserve + area * (1 - minFraction))
            ZStack(alignment: .topLeading) {
                axisRow(priceText(maxPrice)).offset(y: valueReserve)
                axisRow(priceText(minPrice)).offset(y: minY)
            }
        }
    }
    private func axisRow(_ text: String) -> some View {
        HStack(spacing: 6) {
            Text(text).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).fixedSize()
            Rectangle().fill(theme.border(.borderPrimary)).frame(height: 1)
        }
        .offset(y: -5)
    }

    private var header: some View {
        HStack {
            if let onPrev { chevron("chevron.left", onPrev) }
            Spacer()
            if let title { Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textSecondary)) }
            Spacer()
            if let onNext { chevron("chevron.right", onNext) }
        }
    }
    private func chevron(_ name: String, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: name).font(.system(size: 13, weight: .semibold)).foregroundStyle(theme.foreground(.fgHero))
                .mirrorsInRTL()
                .frame(width: 28, height: 28).background(theme.background(.bgSecondaryLight), in: Circle())
        }.buttonStyle(.plain)
    }

    // MARK: Bar

    private func bar(_ i: Int) -> some View {
        let point = visiblePoints[i]
        let isSelected = i == selection
        return VStack(spacing: 4) {
            if showsValues {
                Group { if isSelected { Text(priceText(point.price)).textStyle(.overline500).foregroundStyle(theme.text(.textPrimary)).fixedSize() } }
                    .frame(height: 14)
            }
            Spacer(minLength: 0)
            UnevenRoundedRectangle(topLeadingRadius: cornerRole.value, topTrailingRadius: cornerRole.value, style: .continuous)
                .fill(barFill)
                .frame(height: max(6, barAreaHeight * fraction(point.price)))
            labelBlock(point, isSelected: isSelected)
        }
        .frame(width: scrollable ? barWidth : nil)
        .frame(maxWidth: scrollable ? nil : .infinity)
        .contentShape(Rectangle())
        .onTapGesture { selection = i }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(point.label)\(point.sublabel.map { " " + $0 } ?? ""), \(priceText(point.price))")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// Fixed-height label area so every column's day/weekday captions share one baseline.
    private func labelBlock(_ point: PriceTrendPoint, isSelected: Bool) -> some View {
        VStack(spacing: 1) {
            if isSelected {
                Text(point.label).textStyle(.overline500).foregroundStyle(selectionFg).fixedSize()
                    .padding(.horizontal, 5).padding(.vertical, 1)
                    .background(selectionBg, in: Capsule())
            } else {
                Text(point.label).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary)).fixedSize()
            }
            if showsWeekday, let sub = point.sublabel {
                Text(sub).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)).lineLimit(1).fixedSize()
            }
        }
        .frame(height: labelReserve, alignment: .top)
    }

    private func fraction(_ price: Decimal) -> CGFloat {
        guard maxPrice > 0 else { return 0 }
        return CGFloat(NSDecimalNumber(decimal: price / maxPrice).doubleValue)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceTrendChart {
    /// A centered title (e.g. the month).
    func title(_ text: String?) -> Self { copy { $0.title = text } }
    /// Currency code for the prices. Unset, it resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Bar accent colour (token); `nil` (default) uses the hero foreground.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }
    /// Colour of the selected-day pill (token); `nil` (default) uses the
    /// primary-text/inverse pair. Standard accent vocabulary (flexibility audit §6).
    func selectionAccent(_ color: SemanticColor?) -> Self { copy { $0.selectionColorToken = color } }
    /// Colour of the selected-day pill (token). Default the primary-text/inverse pair.
    @available(*, deprecated, message: "Use selectionAccent(_:) with a SemanticColor token.")
    func selectionColor(_ color: SemanticColor?) -> Self { selectionAccent(color) }
    /// Chart height in points (default 120). Chart geometry is a legitimate
    /// raw-CGFloat knob (not deprecated).
    func barHeight(_ height: CGFloat) -> Self { copy { $0.barHeight = max(48, height) } }
    /// Fixed bar/column width — used when ``scrollable(_:)`` is on (default 26).
    /// Chart geometry is a legitimate raw-CGFloat knob (not deprecated).
    func barWidth(_ width: CGFloat) -> Self { copy { $0.barWidth = max(8, width) } }
    /// Gap between bars in points (default 6). Chart geometry is a legitimate
    /// raw-CGFloat knob (not deprecated); prefer the `Theme.SpacingKey` overload
    /// when a spacing token fits.
    func spacing(_ value: CGFloat) -> Self { copy { $0.spacing = max(0, value) } }
    /// Token-bound overload — gap between bars from the spacing scale.
    func spacing(_ key: Theme.SpacingKey) -> Self { spacing(key.value) }
    /// Bar corner radius (radius role, default `.selector`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.cornerRole = role } }
    /// Horizontally scroll the bars (fixed width each) instead of fitting them to the width.
    func scrollable(_ on: Bool = true) -> Self { copy { $0.scrollable = on } }
    /// Cap how many days are shown (from the start). nil ⇒ all.
    func maxDays(_ count: Int?) -> Self { copy { $0.maxDays = count } }
    /// Show faint min/max price reference lines behind the bars.
    func showsAxis(_ on: Bool = true) -> Self { copy { $0.showsAxis = on } }
    /// Show the selected day's price above its bar.
    func showsValues(_ on: Bool = true) -> Self { copy { $0.showsValues = on } }
    /// Show the weekday caption under each day (default on).
    func showsWeekday(_ on: Bool) -> Self { copy { $0.showsWeekday = on } }
    /// Gradient (default) or flat bar fill.
    func gradient(_ on: Bool) -> Self { copy { $0.useGradient = on } }
    /// Adds prev/next paging chevrons in the header.
    func onPage(prev: @escaping () -> Void, next: @escaping () -> Void) -> Self { copy { $0.onPrev = prev; $0.onNext = next } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var sel = 6
        private let points: [PriceTrendPoint] = (12...40).map {
            PriceTrendPoint("\($0)", sublabel: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"][$0 % 7], price: Decimal(1400 + ($0 * 37) % 700))
        }
        var body: some View {
            PriceTrendChart(points, selection: $sel).title("July").currency("USD")
                .scrollable().showsAxis().showsValues().onPage(prev: {}, next: {}).padding()
        }
    }
    return Demo()
}
