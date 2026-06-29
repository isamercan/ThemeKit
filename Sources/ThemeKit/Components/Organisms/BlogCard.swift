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
    private let excerpt: String?
    private let readMoreTitle: String
    private let compact: Bool
    private let onReadMore: () -> Void
    private let media: () -> Media

    public init(
        title: String,
        excerpt: String? = nil,
        readMoreTitle: String = String(themeKit: "Read more"),
        compact: Bool = false,
        onReadMore: @escaping () -> Void = {},
        @ViewBuilder media: @escaping () -> Media
    ) {
        self.title = title
        self.excerpt = excerpt
        self.readMoreTitle = readMoreTitle
        self.compact = compact
        self.onReadMore = onReadMore
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

#Preview {
    @Previewable @Environment(\.theme) var theme
    VStack(spacing: 20) {
        BlogCard(title: "How About Exploring Cappadocia on Your Own?",
                 excerpt: "To some a miracle of nature, to others a fairyland…",
                 onReadMore: {}) {
            theme.background(.bgTertiary)
        }
        BlogCard(title: "How About Exploring Cappadocia on Your Own?", compact: true, onReadMore: {}) {
            theme.background(.bgTertiary)
        }
    }
    .padding()
}
