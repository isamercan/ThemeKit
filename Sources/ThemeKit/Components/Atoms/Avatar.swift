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
}

/// Atom. Represents a person/business as an icon, initials or image, in a circle
/// or square, plus an `AvatarGroup` that stacks avatars with a +N overflow.
/// (Ant Avatar parity.) Figma sizes 24/32/40/48.
public struct Avatar: View {
    @Environment(\.theme) private var theme

    private let content: AvatarContent
    // Appearance/state — mutated only through the modifiers below (R2).
    private var size: AvatarSize = .md
    private var customDimension: CGFloat?
    private var background: AvatarBackground = .blue
    private var accentColor: SemanticColor?
    private var shape: AvatarShape = .circle
    private var presence: StatusKind?
    private var presencePulse: Bool = false

    public init(_ content: AvatarContent) {   // R1 — content only
        self.content = content
    }

    private var dim: CGFloat { customDimension ?? size.dimension }

    private var clip: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: dim * 0.28, style: .continuous))
        }
    }

    /// Semantic accent (when set) wins over the `AvatarBackground` palette (R4).
    private var surfaceFill: Color { accentColor?.solid ?? background.fill(theme) }
    private var contentColor: Color { accentColor?.onSolid ?? background.foreground(theme) }

    public var body: some View {
        ZStack {
            clip.fill(surfaceFill)
            if accentColor == nil && background.hasBorder {
                clip.stroke(theme.border(.borderPrimary), lineWidth: 2)
            }
            contentView
        }
        .frame(width: dim, height: dim)
        .clipShape(clip)
        .overlay(alignment: .bottomTrailing) { presenceDot }
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
        }
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

    /// Surface fill behind the icon/initials (renamed from `background:` to avoid
    /// clashing with SwiftUI's `.background`, R5).
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func fillColor(_ b: AvatarBackground) -> Self { backgroundPalette(b) }

    /// Non-deprecated internal path for the `AvatarBackground` palette, so
    /// in-package composition (e.g. `AvatarGroup`) stays warning-free.
    internal func backgroundPalette(_ b: AvatarBackground) -> Self { copy { $0.background = b } }

    /// Circle (default) or rounded square.
    func shape(_ s: AvatarShape) -> Self { copy { $0.shape = s } }

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

    public init(_ avatars: [AvatarContent]) {   // R1 — content only
        self.avatars = avatars
    }

    private var overflow: Int { Swift.max(avatars.count - max, 0) }

    public var body: some View {
        HStack(spacing: -size.dimension * 0.35) {
            ForEach(Array(avatars.prefix(max).enumerated()), id: \.offset) { _, content in
                Avatar(content).size(size).backgroundPalette(background).accent(accentColor)
                    .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 2))
            }
            if overflow > 0 {
                Avatar(.initials("+\(overflow)")).size(size).backgroundPalette(.dark)
                    .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 2))
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
        AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .icon("person.fill"), .initials("GH"), .initials("IJ")]).maxVisible(4)
    }
    .padding()
}

#Preview("States") {
    PreviewMatrix("Avatar") {
        PreviewCase("Icon")     { Avatar(.icon("person.fill")) }
        PreviewCase("Initials") { Avatar(.initials("AB")).accent(.neutral).shape(.square) }
        PreviewCase("Building") { Avatar(.icon("building.2.fill")).shape(.square) }
        PreviewCase("Group +N") { AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .initials("GH"), .initials("IJ")]).maxVisible(3) }
    }
}
