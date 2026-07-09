//
//  Skeleton.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference SkeletonView. An animated
//  placeholder driven by the skeleton color tokens (which adapt to the dark
//  theme automatically), applied via `.skeleton(_:)` over any view, via
//  `.skeleton(_:shape:)` for a custom outline, or as a standalone `Skeleton`
//  primitive of an arbitrary shape and size. Three variants (HeroUI Native
//  parity): a traveling `shimmer` sweep (default), an opacity `pulse`, and
//  `none` for a static fill. When loading ends the placeholder cross-fades
//  into the revealed content, honoring `microAnimations` + Reduce Motion.
//

import SwiftUI

/// The outline of a skeleton placeholder.
public enum SkeletonShape: Equatable {
    /// Raw corner radius. Prefer the token-fed `rounded(_ role:)` overload so a
    /// theme can re-round every skeleton from one token.
    case rounded(CGFloat)
    case circle
    case capsule

    /// Token-fed rounded outline: the corner resolves from the active theme's
    /// radius *role* (`.box` cards · `.field` controls · `.selector` chips).
    public static func rounded(_ role: Theme.RadiusRole) -> SkeletonShape {
        .rounded(role.value)
    }

    var anyShape: AnyShape {
        switch self {
        case .rounded(let r): return AnyShape(RoundedRectangle(cornerRadius: r, style: .continuous))
        case .circle: return AnyShape(Circle())
        case .capsule: return AnyShape(Capsule())
        }
    }
}

/// How a skeleton placeholder animates while loading (HeroUI Native parity).
public enum SkeletonVariant: CaseIterable, Equatable {
    /// A traveling highlight sweep over the fill (default).
    case shimmer
    /// The fill breathes between two fixed opacities.
    case pulse
    /// A static fill — no motion at all.
    case none
}

/// The animated fill, reused by the modifier and the standalone view.
struct SkeletonShimmer: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let shape: SkeletonShape
    var variant: SkeletonVariant = .shimmer
    var highlight: SemanticColor? = nil
    @State private var animate = false

    // Fixed internal motion constants (HeroUI Native defaults) — genuine
    // non-semantic dimensions, deliberately not exposed as knobs.
    private static let shimmerDuration: TimeInterval = 1.2
    private static let pulseDuration: TimeInterval = 1.0
    private static let pulseMinOpacity: Double = 0.5
    private static let pulseMaxOpacity: Double = 1.0

    /// The sweep's tint — a semantic color's soft shade when set, else the
    /// token default.
    private var highlightColor: Color {
        highlight?.soft ?? theme.background(.bgWhite).opacity(0.7)
    }

    /// Pulse breathes the fill; shimmer / `none` / Reduce Motion keep it solid.
    private var fillOpacity: Double {
        guard variant == .pulse, !reduceMotion else { return Self.pulseMaxOpacity }
        return animate ? Self.pulseMinOpacity : Self.pulseMaxOpacity
    }

    var body: some View {
        shape.anyShape
            .fill(theme.background(.skeletonBgSkeletonBase))
            .opacity(fillOpacity)
            .overlay {
                // Honor Reduce Motion (and `.none`): a static placeholder,
                // no traveling sweep.
                if variant == .shimmer && !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, highlightColor, .clear],
                            startPoint: .leading, endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.5)
                        .offset(x: animate ? geo.size.width : -geo.size.width * 0.5)
                    }
                }
            }
            .clipShape(shape.anyShape)
            .onAppear {
                guard !reduceMotion else { return }
                switch variant {
                case .shimmer:
                    withAnimation(.linear(duration: Self.shimmerDuration).repeatForever(autoreverses: false)) {
                        animate = true
                    }
                case .pulse:
                    withAnimation(.easeInOut(duration: Self.pulseDuration).repeatForever(autoreverses: true)) {
                        animate = true
                    }
                case .none:
                    break   // static fill — same no-motion path as Reduce Motion
                }
            }
    }
}

/// A standalone skeleton block of an arbitrary shape and size.
public struct Skeleton: View {
    private let shape: SkeletonShape
    // Appearance/config — mutated only through the modifiers below (R2).
    private var width: CGFloat? = nil
    private var height: CGFloat? = nil
    private var variant: SkeletonVariant = .shimmer
    private var highlight: SemanticColor? = nil

    public init(_ shape: SkeletonShape = .rounded(8)) {   // R1 — shape only
        self.shape = shape
    }

    public var body: some View {
        SkeletonShimmer(shape: shape, variant: variant, highlight: highlight)
            .frame(width: width, height: height)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Skeleton {
    /// Fixed block size in points; `nil` leaves that axis unconstrained.
    func size(width: CGFloat? = nil, height: CGFloat? = nil) -> Self {
        copy { $0.width = width; $0.height = height }
    }

    /// Animation variant: `.shimmer` (default) · `.pulse` · `.none`.
    func variant(_ v: SkeletonVariant) -> Self {
        copy { $0.variant = v }
    }

    /// Tints the shimmer sweep with a semantic color's soft shade;
    /// `nil` restores the default token highlight.
    func highlight(_ color: SemanticColor?) -> Self {
        copy { $0.highlight = color }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

private struct SkeletonModifier: ViewModifier {
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isLoading: Bool
    let shape: SkeletonShape
    var variant: SkeletonVariant = .shimmer
    var highlight: SemanticColor? = nil

    func body(content: Content) -> some View {
        content
            .opacity(isLoading ? 0 : 1)
            .overlay {
                if isLoading {
                    SkeletonShimmer(shape: shape, variant: variant, highlight: highlight)
                        .transition(.opacity)
                }
            }
            // Animated reveal: fade the placeholder out / the content in when
            // loading flips, honoring the `microAnimations` switch and Reduce
            // Motion exactly like SkeletonGroup does (nil = instant swap).
            .animation(MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion), value: isLoading)
    }
}

public extension View {
    /// Replaces the view with an animated rounded skeleton while `isLoading` is
    /// true, cross-fading back to the content when loading ends.
    /// Prefer `skeleton(_:radius:variant:highlight:)` — the token-fed overload.
    func skeleton(
        _ isLoading: Bool,
        cornerRadius: CGFloat = 8,
        variant: SkeletonVariant = .shimmer,
        highlight: SemanticColor? = nil
    ) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, shape: .rounded(cornerRadius), variant: variant, highlight: highlight))
    }

    /// Token-fed rounded skeleton: the corner resolves from the active theme's
    /// radius role (`.box` · `.field` · `.selector`).
    func skeleton(
        _ isLoading: Bool,
        radius: Theme.RadiusRole,
        variant: SkeletonVariant = .shimmer,
        highlight: SemanticColor? = nil
    ) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, shape: .rounded(radius), variant: variant, highlight: highlight))
    }

    /// Replaces the view with an animated skeleton of a custom shape while loading.
    func skeleton(
        _ isLoading: Bool,
        shape: SkeletonShape,
        variant: SkeletonVariant = .shimmer,
        highlight: SemanticColor? = nil
    ) -> some View {
        modifier(SkeletonModifier(isLoading: isLoading, shape: shape, variant: variant, highlight: highlight))
    }
}

// MARK: - Previews

#Preview("Shimmer (default)") {
    VStack(alignment: .leading, spacing: 12) {
        Text("Loading title").font(.title).skeleton(true)
        Text("A line of body text that is being loaded.").skeleton(true)
        RoundedRectangle(cornerRadius: 12).frame(height: 120).skeleton(true, cornerRadius: 12)
        HStack {
            Skeleton(.circle).size(width: 48, height: 48)
            VStack(alignment: .leading, spacing: 8) {
                Skeleton(.capsule).size(width: 160, height: 12)
                Skeleton(.capsule).size(width: 100, height: 12)
            }
        }
    }
    .padding()
}

#Preview("Variants · highlight tint") {
    VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
        Text("shimmer (default)").font(.caption).foregroundStyle(.secondary)
        Skeleton(.capsule).size(width: 200, height: 12)

        Text("pulse").font(.caption).foregroundStyle(.secondary)
        Skeleton(.capsule).variant(.pulse).size(width: 200, height: 12)

        Text("none (static)").font(.caption).foregroundStyle(.secondary)
        Skeleton(.capsule).variant(.none).size(width: 200, height: 12)

        Text("highlight tint — .info soft sweep").font(.caption).foregroundStyle(.secondary)
        Skeleton(.rounded(.field)).highlight(.info).size(width: 200, height: 32)

        Text("token radius role — .box").font(.caption).foregroundStyle(.secondary)
        Skeleton(.rounded(.box)).size(width: 200, height: 64)

        Text("Modifier-applied pulse").skeleton(true, radius: .selector, variant: .pulse)
    }
    .padding(Theme.SpacingKey.md.value)
}

#Preview("Reveal toggle") {
    @Previewable @State var isLoading = true

    VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
        Toggle("Loading", isOn: $isLoading)

        Text("Cross-fades in when loading ends").skeleton(isLoading)
        Text("Token radius + pulse placeholder").skeleton(isLoading, radius: .field, variant: .pulse)
        Text("Tinted shimmer placeholder").skeleton(isLoading, highlight: .success)
    }
    .padding(Theme.SpacingKey.md.value)
}
