//
//  PointsBadge.swift
//  ThemeKit
//
//  A loyalty points / miles pill (earn · redeem · balance). Token-bound: the colour
//  comes from the theme, so it re-skins with the brand. Reused by LoyaltyCard.
//
//  Flexible: Dynamic-Type-safe height (scaledControlHeight, never clips), a numeric-text
//  animation on change (reduce-motion aware), a trailing slot, and density-aware padding.
//

import SwiftUI

public enum PointsStyle {
    /// Points you'll earn — success/green.
    case earn
    /// Points spent / redeemable — the brand accent.
    case redeem
    /// A neutral balance readout.
    case balance

    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .earn: return theme.foreground(.systemcolorsFgSuccess)
        case .redeem: return theme.text(.textSecondaryInverse)   // white on the brand fill
        case .balance: return theme.text(.textPrimary)
        }
    }
    func background(_ theme: Theme) -> Color {
        switch self {
        case .earn: return theme.background(.systemcolorsBgSuccessLight)
        case .redeem: return theme.background(.bgHero)
        case .balance: return theme.background(.bgSecondaryLight)
        }
    }
}

public enum PointsSize {
    case small, medium, large

    var height: CGFloat {
        switch self {
        case .small: return 20
        case .medium: return 24
        case .large: return 32
        }
    }
    var textStyle: TextStyle {
        switch self {
        case .small: return .labelSm600
        case .medium: return .labelBase600
        case .large: return .labelMd600
        }
    }
}

/// A token-bound loyalty-points pill.
///
/// ```swift
/// PointsBadge(1_250).unit("mil").style(.earn).size(.large)   // "＋1.250 mil"
/// PointsBadge(8_430).style(.balance).animatesValue().trailing { TierDot(.gold) }
/// ```
public struct PointsBadge: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.locale) private var locale

    private let points: Int
    // Appearance/state — mutated only through the modifiers below (R2).
    private var unitOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var unit: String { unitOverride ?? String(themeKit: "pts") }
    private var style: PointsStyle = .balance
    private var size: PointsSize = .medium
    private var systemImage: String = "star.circle.fill"
    private var showsSign: Bool = true
    private var animatesValue: Bool = false
    private var trailingSlot: AnyView?

    public init(_ points: Int) {   // R1 — content
        self.points = points
    }

    public var body: some View {
        HStack(spacing: density.scale(Theme.SpacingKey.xs.value)) {
            Image(systemName: systemImage).font(size.textStyle.font)
            Text(label)
                .textStyle(size.textStyle)
                .contentTransition(animatesValue && !reduceMotion ? .numericText(value: Double(points)) : .identity)
            if let trailingSlot { trailingSlot }
        }
        .foregroundStyle(style.foreground(theme))
        .padding(.horizontal, density.scale(Theme.SpacingKey.sm.value))
        .scaledControlHeight(size.height)
        .background(style.background(theme), in: Capsule())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }

    private var label: String {
        let value = points.formatted(.number.grouping(.automatic).locale(locale))
        let sign = (showsSign && style == .earn && points > 0) ? "＋" : ""
        return "\(sign)\(value) \(unit)"
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PointsBadge {
    /// The points unit, e.g. `"pts"` / `"mil"`.
    func unit(_ text: String) -> Self { copy { $0.unitOverride = text } }
    /// earn / redeem / balance colour treatment.
    func style(_ s: PointsStyle) -> Self { copy { $0.style = s } }
    /// Size tier: small / medium / large.
    func size(_ s: PointsSize) -> Self { copy { $0.size = s } }
    /// Leading SF Symbol (default `star.circle.fill`).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Shows a leading `＋` on earned points (default true).
    func showsSign(_ on: Bool) -> Self { copy { $0.showsSign = on } }
    /// Animates digit changes (numeric-text transition); no-op under Reduce Motion.
    func animatesValue(_ on: Bool = true) -> Self { copy { $0.animatesValue = on } }
    /// A trailing slot after the value (e.g. a tier marker).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.trailingSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("PointsBadge") {
        PreviewCase("Earn") { PointsBadge(1_250).unit("mil").style(.earn).size(.large) }
        PreviewCase("Redeem") { PointsBadge(500).style(.redeem) }
        PreviewCase("Balance + trailing") {
            PointsBadge(8_430).unit("pts").style(.balance).icon("wallet.pass.fill")
                .trailing { Image(systemName: "chevron.right").font(.caption2).opacity(0.5) }
        }
    }
}
