//
//  PriceHistogram.swift
//  ThemeKit
//
//  A price-distribution histogram over a RangeSlider — bars in the selected range are
//  the brand accent, the rest are muted (the Airbnb-style price filter). Token-bound.
//

import SwiftUI

/// A token-bound price histogram + range filter.
///
/// ```swift
/// PriceHistogram(bins: counts, lowerValue: $low, upperValue: $high, in: 0...5_000)
/// ```
public struct PriceHistogram: View {
    @Environment(\.theme) private var theme

    private let bins: [Int]
    @Binding private var lowerValue: Double
    @Binding private var upperValue: Double
    private let bounds: ClosedRange<Double>
    // Appearance/state — mutated only through the modifiers below (R2).
    private var barHeight: CGFloat = 56
    private var accent: Color?

    public init(bins: [Int], lowerValue: Binding<Double>, upperValue: Binding<Double>, in bounds: ClosedRange<Double>) {
        self.bins = bins
        self._lowerValue = lowerValue
        self._upperValue = upperValue
        self.bounds = bounds
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.xs.value) {
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(Array(bins.enumerated()), id: \.offset) { index, count in
                    Capsule()
                        .fill(isSelected(index) ? selectedColor : theme.background(.bgSecondary))
                        .frame(height: max(3, barHeight * heightRatio(count)))
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: barHeight, alignment: .bottom)
            RangeSlider(lowerValue: $lowerValue, upperValue: $upperValue, in: bounds)
        }
    }

    private var selectedColor: Color { accent ?? theme.foreground(.fgHero) }

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
    func accent(_ color: Color?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State private var low = 800.0
        @State private var high = 3_200.0
        let bins = [2, 5, 9, 14, 18, 22, 19, 12, 8, 5, 3, 2]
        var body: some View {
            PriceHistogram(bins: bins, lowerValue: $low, upperValue: $high, in: 0...5_000)
                .padding()
        }
    }
    return Demo()
}
