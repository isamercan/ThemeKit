//
//  ReviewCard.swift
//  ThemeKit
//
//  A single guest review — avatar, author, date, a ScoreBadge, optional title, the
//  review text, and an optional photo strip. The per-review counterpart to the
//  aggregate RatingSummary. Token-bound.
//
//  The outer shell (surface fill, corner clipping, hairline border) is drawn by the
//  active `CardStyle` from the environment — `.surface()/.cornerRadius()/.elevation()`
//  feed the `CardStyleConfiguration`. The default `.none` elevation reproduces the
//  original shadow-free, hairline-bordered look, while `.cardStyle(_:)` can swap in
//  a completely different shell.
//

import SwiftUI

/// A token-bound single review card.
///
/// ```swift
/// ReviewCard(author: "Elif K.", score: 9.2, text: "Spotless rooms, great location.")
///     .date(reviewDate).title("Would stay again").verified()
/// ```
public struct ReviewCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.locale) private var locale
    @State private var expanded = false

    // Required content (R1).
    private let author: String
    private let score: Double
    private let text: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .none
    private var date: Date?
    private var title: String?
    private var verified: Bool = false
    private var photos: [URL] = []
    private var showsStars: Bool = false
    private var isExpandable: Bool = false
    private var onPhotoTap: ((Int) -> Void)?
    private var actionsSlot: AnyView?

    public init(author: String, score: Double, text: String) {
        self.author = author
        self.score = score
        self.text = text
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — the default `.none` elevation yields the original hairline.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            header
            if let title {
                Text(title).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary))
            }
            Text(text)
                .textStyle(.bodyBase400).foregroundStyle(theme.text(.textSecondary))
                .lineLimit(isExpandable && !expanded ? 3 : nil)
            if isExpandable {
                Button {
                    withAnimation(Animation.snappy.ifMotionAllowed(reduceMotion)) { expanded.toggle() }
                } label: {
                    Text(expanded ? String(themeKit: "Show less") : String(themeKit: "Read more"))
                        .textStyle(.labelBase600).foregroundStyle(theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
            }
            if !photos.isEmpty { photoStrip }
            if let actionsSlot { actionsSlot }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }

    private var header: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Avatar(.initials(initials)).size(.md)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(author).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary))
                    if verified {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(theme.foreground(.fgHero))
                            .accessibilityLabel(String(themeKit: "Verified"))
                    }
                }
                if let date {
                    Text(date.formatted(Date.FormatStyle(date: .abbreviated, time: .omitted).locale(locale)))
                        .textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary))
                }
            }
            Spacer()
            if showsStars {
                Rating(value: score / 2).allowHalf()
            } else {
                ScoreBadge(score, large: false)
            }
        }
    }

    private var photoStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: density.scale(Theme.SpacingKey.sm.value)) {
                ForEach(Array(photos.enumerated()), id: \.element) { index, url in
                    Button { onPhotoTap?(index) } label: {
                        RemoteImage(url)
                            .frame(width: 72, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(onPhotoTap == nil)
                    .accessibilityLabel(String(themeKit: "Review photo \(index + 1) of \(photos.count)"))
                }
            }
        }
    }

    private var initials: String {
        let parts = author.split(separator: " ")
        let letters = parts.prefix(2).compactMap { $0.first }
        return String(letters).uppercased()
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ReviewCard {
    /// Surface fill (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Container corner radius role (default `.box`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Surface elevation (default `.none` — the original hairline-bordered look).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    /// The review date, shown under the author.
    func date(_ date: Date?) -> Self { copy { $0.date = date } }
    /// A bold one-line summary above the body.
    func title(_ text: String?) -> Self { copy { $0.title = text } }
    /// Shows a verified-stay seal next to the author.
    func verified(_ on: Bool = true) -> Self { copy { $0.verified = on } }
    /// A horizontal strip of review photos.
    func photos(_ urls: [URL]) -> Self { copy { $0.photos = urls } }
    /// Shows a star rating (derived from the 0–10 score) instead of the ScoreBadge.
    func stars(_ on: Bool = true) -> Self { copy { $0.showsStars = on } }
    /// Truncates long text to 3 lines with a "Read more" toggle.
    func expandable(_ on: Bool = true) -> Self { copy { $0.isExpandable = on } }
    /// Called with the photo index when a photo is tapped (enables the lightbox).
    func onPhotoTap(_ handler: @escaping (Int) -> Void) -> Self { copy { $0.onPhotoTap = handler } }
    /// A footer slot for actions — Helpful, Report, a host reply.
    func actions<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.actionsSlot = AnyView(content()) } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ReviewCard") {
        PreviewCase("Full · title + verified + date") {
            ReviewCard(author: "Elif Kaya", score: 9.2, text: "Spotless rooms and a great location right by the marina. Breakfast was excellent.")
                .date(.now).title("Would absolutely stay again").verified()
        }
        PreviewCase("Minimal") {
            ReviewCard(author: "Marco P.", score: 7.4, text: "Good value, though the wifi was slow in the evenings.")
        }
        PreviewCase("Stars + expandable") {
            ReviewCard(author: "Jonas W.", score: 8.8,
                       text: "Wonderful pool area and very friendly staff. The rooms were quiet, the beds "
                           + "comfortable, and the breakfast buffet had plenty of choice — we would come back.")
                .date(.now).stars().expandable()
        }
    }
}

#Preview("Outlined style") {
    ReviewCard(author: "Ayşe D.", score: 8.6, text: "Lovely staff and a quiet room overlooking the courtyard.")
        .date(.now).verified()
        .cardStyle(.outlined)
        .padding()
}
