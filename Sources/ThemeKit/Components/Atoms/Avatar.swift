//
//  Avatar.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. Represents a person/business as an icon, initials or image, in a circle
//  or square, plus an `AvatarGroup` that stacks avatars with a +N overflow.
//  (Ant Avatar parity.) Figma sizes 24/32/40/48.
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

    var fill: Color {
        switch self {
        case .blue: return Theme.shared.background(.bgElevatorTertiary)
        case .white: return Theme.shared.background(.bgWhite)
        case .dark: return Theme.shared.background(.bgTertiary)
        }
    }
    var foreground: Color {
        switch self {
        case .blue: return Theme.shared.text(.textHero)
        case .white: return Theme.shared.text(.textPrimary)
        case .dark: return Theme.shared.foreground(.fgSecondary)
        }
    }
    var hasBorder: Bool { self == .white }
}

public enum AvatarContent {
    case icon(String)        // SF Symbol
    case initials(String)
    case image(Image)
}

public struct Avatar: View {
    private let content: AvatarContent
    private let size: AvatarSize
    private let customDimension: CGFloat?
    private let background: AvatarBackground
    private let shape: AvatarShape
    private let presence: StatusKind?
    private let presencePulse: Bool

    public init(
        _ content: AvatarContent,
        size: AvatarSize = .md,
        background: AvatarBackground = .blue,
        shape: AvatarShape = .circle,
        presence: StatusKind? = nil,
        presencePulse: Bool = false
    ) {
        self.content = content
        self.size = size
        self.customDimension = nil
        self.background = background
        self.shape = shape
        self.presence = presence
        self.presencePulse = presencePulse
    }

    /// Arbitrary point-size avatar (Ant numeric `size`), overriding the enum tiers.
    public init(
        _ content: AvatarContent,
        dimension: CGFloat,
        background: AvatarBackground = .blue,
        shape: AvatarShape = .circle,
        presence: StatusKind? = nil,
        presencePulse: Bool = false
    ) {
        self.content = content
        self.size = .md
        self.customDimension = dimension
        self.background = background
        self.shape = shape
        self.presence = presence
        self.presencePulse = presencePulse
    }

    private var dim: CGFloat { customDimension ?? size.dimension }

    private var clip: AnyShape {
        switch shape {
        case .circle: return AnyShape(Circle())
        case .square: return AnyShape(RoundedRectangle(cornerRadius: dim * 0.28, style: .continuous))
        }
    }

    public var body: some View {
        ZStack {
            clip.fill(background.fill)
            if background.hasBorder {
                clip.stroke(Theme.shared.border(.borderPrimary), lineWidth: 2)
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
                Circle().fill(Theme.shared.background(.bgWhite))
                    .frame(width: dot + ring * 2, height: dot + ring * 2)
                StatusDot(presence, size: dot, pulse: presencePulse)
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
                .foregroundStyle(background.foreground)
        case .initials(let text):
            Text(text.prefix(2).uppercased())
                .font(.system(size: dim * 0.38, weight: .semibold))
                .foregroundStyle(background.foreground)
        case .image(let image):
            image.resizable().scaledToFill()
        }
    }
}

/// Overlapping stack of avatars with a "+N" overflow bubble. (Ant Avatar.Group.)
public struct AvatarGroup: View {
    private let avatars: [AvatarContent]
    private let size: AvatarSize
    private let max: Int
    private let background: AvatarBackground

    public init(_ avatars: [AvatarContent], size: AvatarSize = .md, max: Int = 4, background: AvatarBackground = .blue) {
        self.avatars = avatars
        self.size = size
        self.max = Swift.max(max, 1)
        self.background = background
    }

    private var overflow: Int { Swift.max(avatars.count - max, 0) }

    public var body: some View {
        HStack(spacing: -size.dimension * 0.35) {
            ForEach(Array(avatars.prefix(max).enumerated()), id: \.offset) { _, content in
                Avatar(content, size: size, background: background)
                    .overlay(Circle().strokeBorder(Theme.shared.background(.bgWhite), lineWidth: 2))
            }
            if overflow > 0 {
                Avatar(.initials("+\(overflow)"), size: size, background: .dark)
                    .overlay(Circle().strokeBorder(Theme.shared.background(.bgWhite), lineWidth: 2))
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 16) {
        HStack(spacing: 12) {
            Avatar(.icon("person.fill"))
            Avatar(.initials("AB"), background: .dark, shape: .square)
            Avatar(.icon("building.2.fill"), shape: .square)
        }
        AvatarGroup([.initials("AB"), .initials("CD"), .initials("EF"), .icon("person.fill"), .initials("GH"), .initials("IJ")], max: 4)
    }
    .padding()
}
