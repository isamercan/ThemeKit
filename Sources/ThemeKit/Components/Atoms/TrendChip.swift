//
//  TrendChip.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A standalone up/down delta badge — an arrow glyph plus a percentage/value
//  string, tinted success or error by the direction of the trend. (HeroUI Pro
//  "Trend Chip".) Extracted from `Stat`'s private trend badge so the same
//  delta indicator can be dropped next to any price, metric or headline; `Stat`
//  now renders through this atom, pixel-identically.
//

import SwiftUI

public enum TrendChipSize: CaseIterable {
    case small, medium

    var textStyle: TextStyle { self == .small ? .labelSm600 : .labelBase600 }
    var iconPointSize: CGFloat { self == .small ? 11 : 13 }
    var spacing: CGFloat { self == .small ? 2 : 3 }
}

/// Atom. A directional delta indicator: `TrendChip(.up("+12%"))` reads as a
/// green "↗ +12%", `.down("-3%")` as a red "↘ -3%". The arrow *slope* encodes
/// direction (never mirrored for RTL — it is geometry, not text), and VoiceOver
/// speaks the spoken direction ("up 12%") since the glyph alone is silent.
///
///     TrendChip(.up("+12%"))
///     TrendChip(.down("-8%")).positiveIsUp(false)   // a price drop reads as success
public struct TrendChip: View {
    @Environment(\.theme) private var theme

    private let trend: StatTrend

    // Appearance/config — mutated only through the modifiers below (R2).
    private var positiveIsUp = true
    private var showsIcon = true
    private var size: TrendChipSize = .medium

    public init(_ trend: StatTrend) {   // R1 — content only
        self.trend = trend
    }

    public var body: some View {
        HStack(spacing: size.spacing) {
            if showsIcon {
                Image(systemName: trend.systemImage)
                    .font(.system(size: size.iconPointSize, weight: .bold))
            }
            Text(trend.text).textStyle(size.textStyle)
        }
        .foregroundStyle(tint)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(trend.accessibleText))
    }

    /// Success when the trend runs in the "good" direction, error otherwise.
    /// With `positiveIsUp` (the default) an upward trend is good; flipping it
    /// makes a *downward* trend the success — e.g. a falling price.
    private var tint: Color {
        let isGood = isUp == positiveIsUp
        return theme.foreground(isGood ? .systemcolorsFgSuccess : .systemcolorsFgError)
    }

    private var isUp: Bool {
        if case .up = trend { return true } else { return false }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension TrendChip {
    /// Whether an upward trend is the good (success-tinted) outcome. Default
    /// `true`; pass `false` where down is good (falling prices, error counts,
    /// churn) so the semantic color flips without changing the arrow.
    func positiveIsUp(_ on: Bool = true) -> Self { copy { $0.positiveIsUp = on } }

    /// Show or hide the directional arrow glyph (default on). The delta text
    /// and spoken a11y direction remain either way.
    func showsIcon(_ on: Bool = true) -> Self { copy { $0.showsIcon = on } }

    /// Text/glyph scale — `.small` (12pt label) matches `Stat`'s inline badge;
    /// `.medium` (14pt, default) reads well standalone.
    func size(_ s: TrendChipSize) -> Self { copy { $0.size = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            TrendChip(.up("+12%"))
            TrendChip(.down("-3%"))
            TrendChip(.up("+128")).showsIcon(false)
        }
        HStack(spacing: 12) {
            TrendChip(.up("+12%")).size(.small)
            TrendChip(.down("-3%")).size(.small)
        }
        // Inverted semantics: a price drop is good (green).
        HStack(spacing: 8) {
            Text("$412").textStyle(.headingSm)
            TrendChip(.down("-8%")).positiveIsUp(false)
        }
    }
    .padding()
}

#Preview("Matrix") {
    PreviewMatrix("TrendChip") {
        PreviewCase("Up")            { TrendChip(.up("+12%")) }
        PreviewCase("Down")          { TrendChip(.down("-3%")) }
        PreviewCase("Small")         { TrendChip(.up("+5%")).size(.small) }
        PreviewCase("No icon")       { TrendChip(.down("-2%")).showsIcon(false) }
        PreviewCase("Down is good")  { TrendChip(.down("-8%")).positiveIsUp(false) }
    }
}
