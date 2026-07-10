//
//  BlogCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. An article card: media + title + excerpt + read-more link, with a
/// compact (media-left) variant. Media supplied via a ViewBuilder; `.overlay {}`
/// layers content over it.
///
/// By default the card is chrome-free (no fill, border or shadow — the original
/// look). Calling `.surface(_:)`, `.cornerRadius(_:)` or `.elevation(_:)` opts it
/// into an outer shell drawn by the active `CardStyle` from the environment, so
/// `.cardStyle(_:)` can restyle it like the other card organisms.
public struct BlogCard<Media: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle

    private let title: String
    private let media: () -> Media

    // Appearance/config — mutated only through the modifiers below (R2).
    private var excerpt: String?
    private var readMoreTitle = String(themeKit: "Read more")
    private var compact = false
    private var onReadMore: () -> Void = {}
    private var overlaySlot: AnyView?
    // Shell — off by default (today's chrome-free layout); any shell modifier enables it.
    private var hasShell = false
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .none

    public init(title: String, @ViewBuilder media: @escaping () -> Media) {   // R1
        self.title = title
        self.media = media
    }

    public var body: some View {
        if hasShell {
            // The shell (fill, corner clipping, border, shadow) is drawn by the
            // active `CardStyle` — built-ins and custom styles go through the same
            // gate. Shelled content gets standard card padding.
            cardStyle.makeBody(configuration: CardStyleConfiguration(
                content: AnyView(layout.padding(Theme.SpacingKey.md.value)),
                elevation: elevation,
                isSelected: false,
                isPressed: false,
                surfaceKey: surfaceKey,
                radius: radiusRole))
        } else {
            layout   // default: the original chrome-free article layout
        }
    }

    @ViewBuilder private var layout: some View {
        if compact {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                // The `.overlay {}` slot layers over the media, inside its clip.
                ZStack(alignment: .topLeading) {
                    media()
                        .aspectRatioToken(.square, contentMode: .fill)
                        .frame(width: 64, height: 64)
                    if let overlaySlot { overlaySlot }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    titleText
                    readMore
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                // The `.overlay {}` slot layers over the media, inside its clip.
                ZStack(alignment: .topLeading) {
                    media()
                        .aspectRatioToken(.landscape2x1, contentMode: .fill)
                        .frame(maxWidth: .infinity)
                    if let overlaySlot { overlaySlot }
                }
                .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                titleText
                if let excerpt {
                    Text(excerpt)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .lineLimit(3)
                }
                readMore
            }
        }
    }

    private var titleText: some View {
        Text(title)
            .textStyle(.labelMd700)
            .foregroundStyle(theme.text(.textPrimary))
            .lineLimit(2)
    }

    private var readMore: some View {
        Button(action: onReadMore) {
            HStack(spacing: 4) {
                Text(readMoreTitle).textStyle(.linkSm)
                Image(systemName: "arrow.right").font(.system(size: 11, weight: .semibold))
                    .mirrorsInRTL()
            }
            .foregroundStyle(theme.text(.textHero))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension BlogCard {
    /// Excerpt paragraph under the title (regular layout only).
    func excerpt(_ text: String?) -> Self { copy { $0.excerpt = text } }

    /// Read-more link title and tap action.
    func readMore(_ title: String = String(themeKit: "Read more"), action: @escaping () -> Void = {}) -> Self {
        copy { $0.readMoreTitle = title; $0.onReadMore = action }
    }

    /// Compact (media-left) variant.
    func compact(_ on: Bool = true) -> Self { copy { $0.compact = on } }

    /// Layer custom content over the media (top-leading in its ZStack, clipped with
    /// it) — a category chip, a duration badge. The slot positions itself with its
    /// own padding.
    func overlay<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.overlaySlot = AnyView(content()) } }

    // Shell (token-fed, drawn by the active `CardStyle`). The card ships chrome-free;
    // any of these opts it into the shell. Defaults reproduce the classic card look
    // (`.bgWhite` fill, `.box` corner, `.none` elevation → hairline border).
    /// Surface fill (background token key) — enables the card shell.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.hasShell = true; $0.surfaceKey = key } }
    /// Container corner radius role — enables the card shell.
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.hasShell = true; $0.radiusRole = role } }
    /// Surface elevation — enables the card shell.
    func elevation(_ e: CardElevation) -> Self { copy { $0.hasShell = true; $0.elevation = e } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    VStack(spacing: 20) {
        BlogCard(title: "How About Exploring Cappadocia on Your Own?") {
            theme.background(.bgTertiary)
        }
        .excerpt("To some a miracle of nature, to others a fairyland…")
        .readMore(action: {})
        BlogCard(title: "How About Exploring Cappadocia on Your Own?") {
            theme.background(.bgTertiary)
        }
        .compact()
        .readMore(action: {})
    }
    .padding()
}

#Preview("Outlined style + overlay slot") {
    @Previewable @Environment(\.theme) var theme
    BlogCard(title: "How About Exploring Cappadocia on Your Own?") {
        theme.background(.bgTertiary)
    }
    .overlay {
        Text("Travel").textStyle(.labelSm700)
            .foregroundStyle(theme.text(.textSecondaryInverse))
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(MediaScrim.solid, in: Capsule())
            .padding(Theme.SpacingKey.sm.value)
    }
    .excerpt("To some a miracle of nature, to others a fairyland…")
    .readMore(action: {})
    .surface(.bgWhite)
    .cardStyle(.outlined)
    .padding()
}
