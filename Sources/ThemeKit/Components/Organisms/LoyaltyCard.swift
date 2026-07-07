//
//  LoyaltyCard.swift
//  ThemeKit
//
//  A loyalty / membership card — tier, member, a points balance and optional progress
//  to the next tier, on a brand gradient. Token-bound: the gradient is built from the
//  theme's primary palette, so it re-skins with the brand.
//

import SwiftUI

/// A scannable membership code shown on the back of a ``LoyaltyCard``.
public enum MembershipCode: Sendable, Equatable {
    case qr(String)
    case barcode(String)
}

/// A token-bound loyalty membership card.
///
/// ```swift
/// LoyaltyCard(tier: "Gold", points: 8_430)
///     .memberName("Elif Kaya").progress(0.62, toNextTier: "Platinum")
///     .membership(.qr(memberId)).flippable()
/// ```
public struct LoyaltyCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var flipped = false

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
    private var membership: MembershipCode?
    private var flippable: Bool = false

    public init(tier: String, points: Int) {
        self.tier = tier
        self.points = points
    }

    public var body: some View {
        ZStack {
            frontFace.opacity(flipped ? 0 : 1)
            if membership != nil {
                backFace
                    .opacity(flipped ? 1 : 0)
                    .rotation3DEffect(.degrees(180), axis: (x: 0, y: 1, z: 0))
            }
        }
        .rotation3DEffect(.degrees(flipped ? 180 : 0), axis: (x: 0, y: 1, z: 0))
        .contentShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .onTapGesture {
            guard flippable, membership != nil else { return }
            withAnimation(Animation.spring(.smooth).ifMotionAllowed(reduceMotion)) { flipped.toggle() }
        }
        .accessibilityAddTraits(flippable && membership != nil ? .isButton : [])
        .accessibilityHint(flippable && membership != nil ? "Double-tap to \(flipped ? "show card" : "show membership code")" : "")
    }

    private var frontFace: some View {
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

    private var backFace: some View {
        VStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Text("MEMBERSHIP").textStyle(.overline500).foregroundStyle(theme.text(.textTertiary))
            codeView
            if let memberName {
                Text(memberName).textStyle(.bodyBase500).foregroundStyle(theme.text(.textPrimary))
            }
            Text(tier.uppercased()).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
        }
        .padding(density.scale(Theme.SpacingKey.lg.value))
        .frame(maxWidth: .infinity, minHeight: 180)
        .background(theme.background(.bgBase), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.box.value, style: .continuous).stroke(theme.border(.borderPrimary), lineWidth: 1))
    }

    @ViewBuilder private var codeView: some View {
        switch membership {
        case .qr(let value):
            QRCode(value).size(120).padding(8).background(.white, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        case .barcode(let value):
            Barcode(value).height(52).showsValue().padding(.horizontal, 8)
        case .none:
            EmptyView()
        }
    }

    private func progressView(_ value: Double) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Canvas { context, size in
                let radius = size.height / 2
                let clamped = min(1, max(0, value))
                context.fill(
                    Path(roundedRect: CGRect(origin: .zero, size: size), cornerRadius: radius),
                    with: .color(onCard.opacity(0.25))
                )
                let width = max(size.height, size.width * clamped)
                context.fill(
                    Path(roundedRect: CGRect(x: 0, y: 0, width: width, height: size.height), cornerRadius: radius),
                    with: .color(onCard)
                )
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
    /// A scannable membership code (QR or barcode) shown on the card back.
    func membership(_ code: MembershipCode?) -> Self { copy { $0.membership = code } }
    /// Lets the card flip to its membership code on tap (needs `.membership`).
    func flippable(_ on: Bool = true) -> Self { copy { $0.flippable = on } }

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
