//
//  Avatar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum AvatarSize: CGFloat, CaseIterable {
    case xs = 24
    case sm = 32
    case md = 40
    case lg = 48

    var dimension: CGFloat { rawValue }
}

public enum AvatarShape { case circle, square }

public enum AvatarBackground {
    case blue, white, dark

    func fill(_ theme: Theme) -> Color {
        switch self {
        case .blue: return theme.background(.bgElevatorTertiary)
        case .white: return theme.background(.bgWhite)
        case .dark: return theme.background(.bgTertiary)
        }
    }
    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .blue: return theme.text(.textHero)
        case .white: return theme.text(.textPrimary)
        case .dark: return theme.foreground(.fgSecondary)
        }
    }
    var hasBorder: Bool { self == .white }
}

public enum AvatarContent {
    case icon(String)        // SF Symbol
    case initials(String)
    case image(Image)
    /// Remote image with an explicit fallback (HeroUI `Avatar.Image` +
    /// `Avatar.Fallback` parity): skeleton while loading, fade-in on success,
    /// and the fallback content — rendered through the normal token path —
    /// on failure or a `nil` URL. `indirect` carries the recursive payload;
    /// nested `.remote` fallbacks are flattened to their terminal static
    /// content (fallback chains don't re-fetch).
    indirect case remote(URL?, fallback: AvatarContent)

    /// Remote image with the default person-icon fallback (HeroUI's
    /// `DefaultFallbackIcon` parity).
    public static func remote(_ url: URL?) -> AvatarContent {
        .remote(url, fallback: .icon("person.fill"))
    }

    /// Unwraps `.remote` chains to the terminal static content (icon /
    /// initials / image), for failure rendering and accessibility.
    var terminal: AvatarContent {
        var c = self
        while case .remote(_, let fallback) = c { c = fallback }
        return c
    }
}

/// Atom. Represents a person/business as an icon, initials, image, or a remote
/// URL with a token-path fallback, in a circle or square, plus an `AvatarGroup`
/// that stacks avatars with a +N overflow. (Ant Avatar + HeroUI Native
/// Image/Fallback parity.) Figma sizes 24/32/40/48.
public struct Avatar: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let content: AvatarContent
    // Appearance/state — mutated only through the modifiers below (R2).
    private var size: AvatarSize = .md
    private var customDimension: CGFloat?
    private var background: AvatarBackground = .blue
    private var accentColor: SemanticColor?
    private var fillVariant: FillVariant = .solid
    private var shape: AvatarShape = .circle
    private var presence: StatusKind?
    private var presencePulse: Bool = false
    private var isBordered: Bool = false
    private var borderAccent: SemanticColor?

    public init(_ content: AvatarContent) {   // R1 — content only
        self.content = content
    }

    private var dim: CGFloat { customDimension ?? size.dimension }

    /// Rounding of the `.square` shape — shared by the clip outline and the
    /// remote-loading skeleton so the two can never drift apart.
    private var squareCornerRadius: CGFloat { dim * 0.28 }

    private var clip: ThemeAnyShape {
        switch shape {
        case .circle: return ThemeAnyShape(Circle())
        case .square: return ThemeAnyShape(RoundedRectangle(cornerRadius: squareCornerRadius, style: .continuous))
        }
    }

    /// The semantic color driving the surface. An explicit `.accent(_:)` always
    /// wins; `.fill(.soft)` with no accent falls back to `.neutral` (HeroUI's
    /// `default` soft look), so the soft variant is visible on its own.
    private var effectiveAccent: SemanticColor? {
        accentColor ?? (fillVariant == .soft ? .neutral : nil)
    }

    /// Semantic accent (when set) wins over the `AvatarBackground` palette (R4).
    /// `.soft` maps to the SemanticColor's soft surface + accent foreground;
    /// every other `FillVariant` resolves like `.solid` (documented on `fill(_:)`).
    private var surfaceFill: Color {
        guard let accent = effectiveAccent else { return background.fill(theme) }
        let resolved = theme.resolve(accent)
        return fillVariant == .soft ? resolved.soft : resolved.solid
    }
    private var contentColor: Color {
        guard let accent = effectiveAccent else { return background.foreground(theme) }
        let resolved = theme.resolve(accent)
        return fillVariant == .soft ? resolved.accent : resolved.onSolid
    }

    public var body: some View {
        ZStack {
            clip.fill(surfaceFill)
            if effectiveAccent == nil && background.hasBorder {
                clip.stroke(theme.border(.borderPrimary), lineWidth: 2)
            }
            contentView
        }
        .frame(width: dim, height: dim)
        .clipShape(clip)
        // Border ring (HeroUI `isBordered`): drawn after the clip so it sits on
        // top of image content; token stroke — the semantic accent's solid when
        // set, else the primary border token.
        .overlay {
            if isBordered {
                clip.stroke(borderAccent.map { theme.resolve($0).solid } ?? theme.border(.borderPrimary), lineWidth: 2)
            }
        }
        .overlay(alignment: .bottomTrailing) { presenceDot }
        // One element for VoiceOver; callers override with `.accessibilityLabel`.
        // The presence dot's spoken status survives the collapse as the value,
        // so state is never conveyed by color alone.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(defaultAccessibilityLabel)
        .accessibilityValue(presence?.accessibleName ?? "")
    }

    /// Default VoiceOver label: the initials when the terminal content is
    /// `.initials` (untruncated — speech doesn't need the visual clamp), else
    /// a localized "Avatar".
    private var defaultAccessibilityLabel: String {
        if case .initials(let text) = content.terminal {
            return text.uppercased()
        }
        return String(themeKit: "Avatar")
    }

    /// Corner presence dot (online / away / busy …), ringed in the surface color so
    /// it reads against the avatar. Drawn outside the clip so it isn't masked.
    @ViewBuilder
    private var presenceDot: some View {
        if let presence {
            let dot = max(8, dim * 0.28)
            let ring = max(1.5, dim * 0.05)
            ZStack {
                Circle().fill(theme.background(.bgWhite))
                    .frame(width: dot + ring * 2, height: dot + ring * 2)
                StatusDot(presence).size(dot).pulse(presencePulse)
            }
            .offset(x: shape == .circle ? -dim * 0.15 : -dim * 0.02,
                    y: shape == .circle ? -dim * 0.15 : -dim * 0.02)
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch content {
        case .remote(let url, let fallback):
            remoteContent(url: url, fallback: fallback.terminal)
        default:
            staticContent(content.terminal)
        }
    }

    /// Renders terminal (non-remote) content; `staticContent` is only ever fed
    /// pre-flattened content, so `.remote` is unreachable here (kept exhaustive
    /// without recursive opaque types).
    @ViewBuilder
    private func staticContent(_ content: AvatarContent) -> some View {
        switch content {
        case .icon(let name):
            Image(systemName: name)
                .font(.system(size: dim * 0.5))
                .foregroundStyle(contentColor)
        case .initials(let text):
            Text(text.prefix(2).uppercased())
                .font(.system(size: dim * 0.38, weight: .semibold))
                .foregroundStyle(contentColor)
        case .image(let image):
            image.resizable().scaledToFill()
        case .remote:
            EmptyView()   // unreachable — callers pass `.terminal` content
        }
    }

    /// Remote avatar image (HeroUI `Avatar.Image`): Skeleton atom while loading,
    /// fade-in via the house motion token (`microAnimations` + Reduce Motion
    /// gated) on success, token-path fallback content on failure / `nil` URL.
    /// `RemoteImage` isn't reused here: its failure state is a fixed photo
    /// placeholder, while the avatar must fall back to initials/icon through
    /// the normal `contentColor` path.
    @ViewBuilder
    private func remoteContent(url: URL?, fallback: AvatarContent) -> some View {
        if let url {
            AsyncImage(
                url: url,
                transaction: Transaction(animation: MicroMotion.animation(.base, enabled: micro, reduceMotion: reduceMotion))
            ) { phase in
                switch phase {
                case .success(let image):
                    image.resizable().scaledToFill()
                case .failure:
                    staticContent(fallback)
                case .empty:
                    loadingSkeleton
                @unknown default:
                    loadingSkeleton
                }
            }
            .frame(width: dim, height: dim)
        } else {
            staticContent(fallback)
        }
    }

    /// Loading placeholder matching the avatar's clip outline.
    private var loadingSkeleton: some View {
        Skeleton(shape == .circle ? .circle : .rounded(squareCornerRadius))
            .size(width: dim, height: dim)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Avatar {
    /// Size tier: xs / sm / md / lg (Figma 24/32/40/48).
    func size(_ s: AvatarSize) -> Self { copy { $0.size = s } }

    /// Arbitrary point-size avatar (Ant numeric `size`), overriding the size tier.
    func dimension(_ points: CGFloat) -> Self { copy { $0.customDimension = points } }

    /// Semantic tint for the surface behind the icon/initials (content
    /// auto-contrasts); `nil` (default) keeps the `AvatarBackground` palette.
    /// Standard accent vocabulary (flexibility audit §6).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    /// Fill treatment for the semantic surface (HeroUI Avatar variants):
    /// `.solid` (default) keeps the accent's solid shade with auto-contrast
    /// content; `.soft` resolves the surface to the accent `SemanticColor`'s
    /// `.soft` shade and the content to its high-contrast `.accent` foreground.
    /// With no `.accent(_:)` set, `.soft` falls back to `.neutral`. `.outline`
    /// and `.ghost` have no avatar archetype and resolve like `.solid`.
    func fill(_ v: FillVariant) -> Self { copy { $0.fillVariant = v } }

    /// Surface fill behind the icon/initials (renamed from `background:` to avoid
    /// clashing with SwiftUI's `.background`, R5).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func fillColor(_ b: AvatarBackground) -> Self { backgroundPalette(b) }

    /// Non-deprecated internal path for the `AvatarBackground` palette, so
    /// in-package composition (e.g. `AvatarGroup`) stays warning-free.
    internal func backgroundPalette(_ b: AvatarBackground) -> Self { copy { $0.background = b } }

    /// Circle (default) or rounded square.
    func shape(_ s: AvatarShape) -> Self { copy { $0.shape = s } }

    /// Draws a token stroke ring around the avatar (HeroUI `isBordered`) —
    /// e.g. to mark the active speaker or lift a photo off a busy surface.
    /// `accent` tints the ring from the semantic palette; `nil` (default)
    /// uses the primary border token.
    func bordered(_ on: Bool = true, accent: SemanticColor? = nil) -> Self {
        copy { $0.isBordered = on; $0.borderAccent = accent }
    }

    /// Corner presence dot (online / away / busy …); `nil` hides it.
    func presence(_ kind: StatusKind?, pulse: Bool = false) -> Self {
        copy { $0.presence = kind; $0.presencePulse = pulse }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

/// Overlapping stack of avatars with a "+N" overflow bubble. (Ant Avatar.Group.)
public struct AvatarGroup: View {
    @Environment(\.theme) private var theme

    private let avatars: [AvatarContent]
    // Appearance/config — mutated only through the modifiers below (R2).
    private var size: AvatarSize = .md
    private var max: Int = 4
    private var background: AvatarBackground = .blue
    private var accentColor: SemanticColor?
    private var fillVariant: FillVariant = .solid

    public init(_ avatars: [AvatarContent]) {   // R1 — content only
        self.avatars = avatars
    }

    private var overflow: Int { Swift.max(avatars.count - max, 0) }

    public var body: some View {
        HStack(spacing: -size.dimension * 0.35) {
            ForEach(Array(avatars.prefix(max).enumerated()), id: \.offset) { _, content in
                Avatar(content).size(size).backgroundPalette(background).accent(accentColor).fill(fillVariant)
                    .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 2))
            }
            if overflow > 0 {
                Avatar(.initials("+\(overflow)")).size(size).backgroundPalette(.dark)
                    .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 2))
                    // The visual bubble clamps to two glyphs; speech gets the
                    // real count.
                    .accessibilityLabel(String(themeKit: "\(overflow) more"))
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AvatarGroup {
    /// Size tier for every avatar in the group: xs / sm / md / lg.
    func size(_ s: AvatarSize) -> Self { copy { $0.size = s } }

    /// How many avatars show before collapsing into the "+N" bubble (default 4, floored at 1).
    func maxVisible(_ count: Int) -> Self { copy { $0.max = Swift.max(count, 1) } }

    /// Semantic tint for every member avatar's surface (content auto-contrasts);
    /// `nil` (default) keeps the `AvatarBackground` palette. The "+N" overflow
    /// bubble keeps its dark palette for contrast. Matches Avatar's `.accent(_:)`.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accentColor = color } }

    /// Fill treatment for every member avatar's semantic surface (`.solid`
    /// default · `.soft`); the "+N" overflow bubble keeps its dark palette.
    /// Matches Avatar's `.fill(_:)`.
    func fill(_ v: FillVariant) -> Self { copy { $0.fillVariant = v } }

    /// Surface fill behind the avatars' icon/initials (matches Avatar's `.fillColor`, R5).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func fillColor(_ b: AvatarBackground) -> Self { copy { $0.background = b } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            Avatar(.icon("person.fill"))
            Avatar(.initials("AB")).accent(.neutral).shape(.square)
            Avatar(.icon("building.2.fill")).shape(.square)
        }
        // Remote: skeleton while loading → fade-in; the invalid host falls back
        // to initials/icon through the token path.
        HStack(spacing: 12) {
            Avatar(.remote(URL(string: "https://i.pravatar.cc/96")))
            Avatar(.remote(URL(string: "https://invalid.invalid/broken.png"), fallback: .initials("FB")))
                .accent(.warning)
            Avatar(.remote(nil, fallback: .icon("person.crop.circle.badge.exclamationmark")))
                .shape(.square)
        }
        // Soft fill: accent's .soft surface + high-contrast accent foreground.
        HStack(spacing: 12) {
            Avatar(.initials("SO")).accent(.success).fill(.soft)
            Avatar(.icon("person.fill")).accent(.info).fill(.soft)
            Avatar(.initials("NE")).fill(.soft)   // no accent → neutral soft
            Avatar(.initials("SO")).accent(.success)   // solid, for contrast
        }
        // Border ring: default border token, semantic accent, and on a photo.
        HStack(spacing: 12) {
            Avatar(.initials("BR")).bordered()
            Avatar(.initials("AC")).accent(.success).fill(.soft).bordered(accent: .success)
            Avatar(.remote(URL(string: "https://i.pravatar.cc/96"))).bordered(accent: .primary)
            Avatar(.icon("person.fill")).shape(.square).bordered(accent: .warning)
        }
        AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .icon("person.fill"), .initials("GH"), .initials("IJ")]).maxVisible(4)
        AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF")]).accent(.info).fill(.soft)
        // a11y: each avatar is one VoiceOver element — initials are spoken when
        // present ("AB"), else the localized "Avatar"; callers override with the
        // native `.accessibilityLabel(_:)`.
        Avatar(.initials("VO")).accessibilityLabel("Profile photo of Vera Osman")
    }
    .padding()
}

#Preview("States") {
    PreviewMatrix("Avatar") {
        PreviewCase("Icon")     { Avatar(.icon("person.fill")) }
        PreviewCase("Initials") { Avatar(.initials("AB")).accent(.neutral).shape(.square) }
        PreviewCase("Building") { Avatar(.icon("building.2.fill")).shape(.square) }
        PreviewCase("Remote")   { Avatar(.remote(URL(string: "https://i.pravatar.cc/96"))) }
        PreviewCase("Remote fallback") { Avatar(.remote(URL(string: "https://invalid.invalid/broken.png"), fallback: .initials("FB"))).accent(.warning) }
        PreviewCase("Soft fill") { Avatar(.initials("SO")).accent(.success).fill(.soft) }
        PreviewCase("Bordered") { Avatar(.initials("BR")).bordered(accent: .success) }
        PreviewCase("Group +N") { AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .initials("GH"), .initials("IJ")]).maxVisible(3) }
    }
}
