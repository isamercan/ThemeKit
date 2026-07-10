//
//  ChartSupport.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Chrome shared by the generic chart family: hairline axes, the scrub-readout
//  card, and value formatting — one source of truth so Line/Area/Bar stay
//  visually identical.
//

import SwiftUI
import Charts

extension View {
    /// Hairline grid lines (`borderPrimary`) and tertiary tick labels on both
    /// axes; grid suppressed when `showsGrid` is false. Chart-family only.
    func themedChartAxes(theme: Theme, showsGrid: Bool) -> some View {
        self
            .chartXAxis {
                AxisMarks { _ in
                    if showsGrid { AxisGridLine().foregroundStyle(theme.border(.borderPrimary)) }
                    AxisValueLabel().font(.caption2).foregroundStyle(theme.text(.textTertiary))
                }
            }
            .chartYAxis {
                AxisMarks { _ in
                    if showsGrid { AxisGridLine().foregroundStyle(theme.border(.borderPrimary)) }
                    AxisValueLabel().font(.caption2).foregroundStyle(theme.text(.textTertiary))
                }
            }
    }
}

/// The scrub-readout card: a category title plus one color-dotted row per
/// series, on the standard elevated token card. (This is the "chart tooltip"
/// answer — SwiftUI has no standalone tooltip component.)
struct ChartScrubCard: View {
    let theme: Theme
    let title: String
    let rows: [ChartScrubRow]

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title).textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            ForEach(rows) { row in
                HStack(spacing: 5) {
                    Circle().fill(row.color).frame(width: 6, height: 6)
                    Text(row.label).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                    Spacer(minLength: 10)
                    Text(row.value).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
                }
            }
        }
        .padding(Theme.SpacingKey.sm.value)
        .background(theme.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
        .themeShadow(.elevated)
    }
}

struct ChartScrubRow: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    let color: Color
}

/// Standard chart value formatting: up to one fraction digit, localized.
func chartValueFormatted(_ value: Double, locale: Locale) -> String {
    value.formatted(.number.precision(.fractionLength(0...1)).locale(locale))
}
