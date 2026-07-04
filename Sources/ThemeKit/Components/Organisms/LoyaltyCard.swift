//
//  LoyaltyCard.swift
//  ThemeKit
//
//  A loyalty / membership card — tier, member, a points balance and optional progress
//  to the next tier, on a brand gradient. Token-bound: the gradient is built from the
//  theme's primary palette, so it re-skins with the brand.
//

import SwiftUI

/// A token-bound loyalty membership card.
///
/// ```swift
/// LoyaltyCard(tier: "Gold", points: 8_430)
///     .memberName("Elif Kaya").progress(0.62, toNextTier: "Platinum")
/// ```
public struct LoyaltyCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Required content (R1).
    private let tier: String
    private let points: Int
    // Appearance/state — mutated only through the modifiers below (R2).
    private var memberName: String?
    private var unit: String = "pts"
    private var progress: Double?
    private var nextTier: String?
    private var systemImage: String = "seal.fill"
    private var gradientOverride: [Color]?
    private var animatesValue: Bool = false
    private var logoSlot: AnyView?

    public init(tier: String, points: Int) {
        self.tier = tier
        self.points = points
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.md.value)) {
            HStack {
                Text(tier.uppercased()).textStyle(.labelMd700).foregroundStyle(onCard)
                Spacer()
                if let logoSlot {
                    logoSlot
                } else {
                    Image(systemName: systemImage).font(.title3).foregroundStyle(onCard)
                }
            }
            if let memberName {
                Text(memberName).textStyle(.bodyBase500).foregroundStyle(onCard.opacity(0.9))
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
                Text(points.formatted(.number.grouping(.automatic)))
                    .textStyle(.heading2xl).foregroundStyle(onCard)
                    .contentTransition(animatesValue && !reduceMotion ? .numericText(value: Double(points)) : .identity)
                Text(unit).textStyle(.bodyBase400).foregroundStyle(onCard.opacity(0.8))
            }
            if let progress { progressView(progress) }
        }
        .padding(density.scale(Theme.SpacingKey.lg.value))
        .frame(maxWidth: .infinity, minHeight: 180, alignment: .topLeading)
        .background(gradient, in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
    }

    private func progressView(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(onCard.opacity(0.25))
                    Capsule().fill(onCard).frame(width: geo.size.width * min(1, max(0, value)))
                }
            }
            .frame(height: 6)
            if let nextTier {
                Text("\(Int((1 - min(1, max(0, value))) * 100))% to \(nextTier)")
                    .textStyle(.bodySm400).foregroundStyle(onCard.opacity(0.85))
            }
        }
    }

    private var gradient: LinearGradient {
        let colors = gradientOverride ?? [theme.palette(.primary600), theme.palette(.primary900)]
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    /// Text/marks drawn on the gradient — white for legibility on the brand fill.
    private var onCard: Color { theme.text(.textSecondaryInverse) }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LoyaltyCard {
    /// The member's name, shown under the tier.
    func memberName(_ name: String?) -> Self { copy { $0.memberName = name } }
    /// The points unit (default `"pts"`).
    func unit(_ text: String) -> Self { copy { $0.unit = text } }
    /// Progress (0…1) to the next tier, with its name.
    func progress(_ value: Double, toNextTier tier: String? = nil) -> Self { copy { $0.progress = value; $0.nextTier = tier } }
    /// A tier SF Symbol (default `seal.fill`).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Overrides the brand gradient.
    func gradient(_ colors: [Color]?) -> Self { copy { $0.gradientOverride = colors } }
    /// A brand logo slot in the top-trailing corner (replaces the tier icon).
    func logo<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.logoSlot = AnyView(content()) } }
    /// Animates the points balance on change (numeric-text; no-op under Reduce Motion).
    func animatesValue(_ on: Bool = true) -> Self { copy { $0.animatesValue = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    LoyaltyCard(tier: "Gold", points: 8_430)
        .memberName("Elif Kaya")
        .progress(0.62, toNextTier: "Platinum")
        .padding()
}
