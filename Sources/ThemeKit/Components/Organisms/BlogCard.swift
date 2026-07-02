//
//  BlogCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. An article card: media + title + excerpt + read-more link, with a
/// compact (media-left) variant. Media supplied via a ViewBuilder.
public struct BlogCard<Media: View>: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let media: () -> Media

    // Appearance/config — mutated only through the modifiers below (R2).
    private var excerpt: String?
    private var readMoreTitle = String(themeKit: "Read more")
    private var compact = false
    private var onReadMore: () -> Void = {}

    public init(title: String, @ViewBuilder media: @escaping () -> Media) {   // R1
        self.title = title
        self.media = media
    }

    public var body: some View {
        if compact {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                media()
                    .aspectRatioToken(.square, contentMode: .fill)
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    titleText
                    readMore
                }
                Spacer(minLength: 0)
            }
        } else {
            VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
                media()
                    .aspectRatioToken(.landscape2x1, contentMode: .fill)
                    .frame(maxWidth: .infinity)
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
