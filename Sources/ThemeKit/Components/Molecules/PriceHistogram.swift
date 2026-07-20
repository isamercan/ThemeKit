//
//  PriceHistogram.swift
//  ThemeKit
//
//  A price-distribution histogram over a RangeSlider — bars in the selected range are
//  the brand accent, the rest are muted (the Airbnb-style price filter). Token-bound.
//
//  Flexible: a live selected-range readout + result count, min/max bound labels, and
//  animated bar heights (reduce-motion aware).
//

import SwiftUI

/// A token-bound price histogram + range filter.
///
/// ```swift
/// PriceHistogram(bins: counts, lowerValue: $low, upperValue: $high, in: 0...5_000)
///     .showsBounds().resultCount(results)
/// ```
public struct PriceHistogram: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let bins: [Int]
    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double
    private let bounds: ClosedRange<Double>
    // Appearance/state — mutated only through the modifiers below (R2).
    private var barHeight: CGFloat = 56
    private var accent: Color?
    // ADR-0006: the token overload stores the `SemanticColor` (not a resolved
    // `Color`) so it re-resolves against the environment theme in `body`.
    private var semanticAccent: SemanticColor?
    private var currencyCode: String?
    private var resultCount: Int?
    private var showsBounds: Bool = false

    public init(bins: [Int], lowerValue: Binding<Double>, upperValue: Binding<Double>, in bounds: ClosedRange<Double>) {
        self.bins = bins
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
    }

    public var body: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            if showsBounds || resultCount != nil {
                HStack {
                    Text("\(formatted(lowerValue)) – \(formatted(upperValue))")
                        .textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    Spacer()
                    if let resultCount {
                        Text(String(themeKit: "\(resultCount) results")).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                    }
                }
            }
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bins.enumerated()), id: \.offset) { index, count in
                    Capsule()
                        .fill(isSelected(index) ? selectedColor : theme.background(.bgSecondary))
                        .frame(height: max(3, barHeight * heightRatio(count)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight, alignment: .bottom)
            .accessibilityHidden(true)   // decorative; the RangeSlider carries the interactive a11y
            .animation(ThemeMotion.snappy.ifMotionAllowed(reduceMotion), value: bins)
            .animation(Animation.easeInOut.ifMotionAllowed(reduceMotion), value: lowerValue)
            .animation(Animation.easeInOut.ifMotionAllowed(reduceMotion), value: upperValue)
            RangeSlider(lowerValue: $lowerValue, upperValue: $upperValue, in: bounds)
            if showsBounds {
                HStack {
                    Text(formatted(bounds.lowerBound)).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                    Spacer()
                    Text(formatted(bounds.upperBound)).textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                }
            }
        }
    }

    private var selectedColor: Color { semanticAccent.map { theme.resolve($0).base } ?? accent ?? theme.foreground(.fgHero) }

    /// Explicit `.currency(_:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    private func formatted(_ value: Double) -> String {
        Decimal(Int(value.rounded())).formatted(.currency(code: resolvedCurrency).precision(.fractionLength(0)).locale(locale))
    }

    private func heightRatio(_ count: Int) -> CGFloat {
        let maxCount = bins.max() ?? 0
        guard maxCount > 0 else { return 0 }
        return CGFloat(count) / CGFloat(maxCount)
    }

    private func isSelected(_ index: Int) -> Bool {
        guard !bins.isEmpty else { return false }
        let width = (bounds.upperBound - bounds.lowerBound) / Double(bins.count)
        let center = bounds.lowerBound + (Double(index) + 0.5) * width
        return center >= lowerValue && center <= upperValue
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PriceHistogram {
    /// Max bar height in points (default 56).
    func barHeight(_ height: CGFloat) -> Self { copy { $0.barHeight = height } }
    /// Overrides the selected-bar colour (otherwise the theme accent).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func accent(_ color: Color?) -> Self { copy { $0.accent = color; $0.semanticAccent = nil } }
    /// Token-bound overload — selected bars use the semantic colour's base.
    func accent(_ color: SemanticColor) -> Self { copy { $0.semanticAccent = color; $0.accent = nil } }
    /// Currency for the range / bound labels. Unset, it resolves from
    /// `\.formatDefaults`, then the locale's currency, then "USD".
    func currency(_ code: String) -> Self { copy { $0.currencyCode = code } }
    /// Shows a live selected-range readout and how many results it matches.
    func resultCount(_ count: Int?) -> Self { copy { $0.resultCount = count } }
    /// Shows the min / max bound labels under the slider (and the range readout above).
    func showsBounds(_ on: Bool = true) -> Self { copy { $0.showsBounds = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var low = 800.0
        @State var high = 3_200.0
        var body: some View {
            let bins = [2, 5, 9, 14, 18, 22, 19, 12, 8, 5, 3, 2]
            PreviewMatrix("PriceHistogram") {
                PreviewCase("Bounds + result count") {
                    PriceHistogram(bins: bins, lowerValue: $low, upperValue: $high, in: 0...5_000)
                        .showsBounds().resultCount(87)
                }
                PreviewCase("Minimal + accent") {
                    PriceHistogram(bins: bins, lowerValue: $low, upperValue: $high, in: 0...5_000)
                        .accent(.success)
                }
            }
        }
    }
    return Demo()
}
