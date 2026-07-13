//
//  DestinationCard.swift
//  ThemeKit
//
//  A travel destination / favourite card — a media header with an optional corner
//  ribbon and a favourite heart, then a title, subtitle, tag chips and a price +
//  score row. Token-bound. Composes the atoms (RemoteImage, PriceTag, ScoreBadge,
//  Tag) into one richly-configurable card, in the spirit of ``ListRow``.
//
//  The outer shell (surface fill, corner clipping, border, elevation shadow) is drawn
//  by the active `CardStyle` from the environment — `.surface()` and `.elevation()`
//  feed the `CardStyleConfiguration`, so `.cardStyle(_:)` can swap in a completely
//  different shell. `.media {}` replaces the image; `.overlay {}` layers over it.
//

import SwiftUI

/// A token-bound destination / favourite card.
///
/// ```swift
/// DestinationCard("Bali & Unforgettable 3-Days", image: url)
///     .subtitle("Indonesia").ribbon("Top #1")
///     .price(1_450).rating(4.8).favorite($isFavourite)
///     .tags(["Beach", "Culture"]).onTap { open() }
/// ```
public struct DestinationCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    // Required content (R1).
    private let title: String
    private let imageURL: URL?
    // Appearance/state — mutated only through the modifiers below (R2).
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var subtitle: String?
    private var price: Decimal?
    private var currencyCode: String?
    private var rating: Double?
    private var ribbon: String?
    private var ribbonColor: SemanticColor = .primary
    private var badge: String?
    private var tags: [String] = []
    private var favorite: Binding<Bool>?
    private var aspect: CGFloat = 4.0 / 3.0
    private var overlayTitle = false
    private var onTap: (() -> Void)?
    private var mediaSlot: AnyView?
    private var overlaySlot: AnyView?
    private var footerSlot: AnyView?
    private var elevation: CardElevation = .soft

    public init(_ title: String, image url: URL? = nil) {   // R1 — content
        self.title = title
        self.imageURL = url
    }

    /// Explicit `price(_:currencyCode:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        let card = cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: .box))

        if let onTap {
            Button(action: onTap) { card }.buttonStyle(.plain)
        } else {
            card
        }
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            mediaSection
            infoSection
        }
    }

    // MARK: Media

    private var mediaSection: some View {
        mediaContent
            .frame(maxWidth: .infinity)
            .clipped()
            // Custom overlay sits above the media, below the ribbon/heart/title bar.
            .overlay { if let overlaySlot { overlaySlot } }
            .overlay(alignment: .topLeading) { if let ribbon { ribbonTag(ribbon) } }
            .overlay(alignment: .topTrailing) { if let favorite { heartButton(favorite) } }
            .overlay(alignment: .bottomLeading) { if overlayTitle { overlayTitleBar } }
    }

    @ViewBuilder private var mediaContent: some View {
        if let mediaSlot {
            mediaSlot
        } else if let imageURL {
            RemoteImage(imageURL).ratio(aspect).contentMode(.fill)
        } else {
            ZStack {
                Rectangle().fill(theme.background(.bgSecondary))
                Image(systemName: "photo").font(.largeTitle).foregroundStyle(theme.text(.textTertiary))
            }
            .aspectRatio(aspect, contentMode: .fit)
        }
    }

    private func ribbonTag(_ text: String) -> some View {
        Text(text)
            .textStyle(.labelSm700)
            .foregroundStyle(theme.resolve(ribbonColor).onSolid)
            .padding(.horizontal, Theme.SpacingKey.sm.value)
            .padding(.vertical, 4)
            .background(theme.resolve(ribbonColor).solid, in: Capsule())
            .padding(Theme.SpacingKey.sm.value)
            .themeShadow(.soft)
    }

    private func heartButton(_ fav: Binding<Bool>) -> some View {
        Button { fav.wrappedValue.toggle() } label: {
            Image(systemName: fav.wrappedValue ? "heart.fill" : "heart")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(fav.wrappedValue ? theme.foreground(.systemcolorsFgError) : theme.text(.textSecondaryInverse))
                .symbolEffect(.bounce, value: fav.wrappedValue)
                .frame(width: 32, height: 32)
                .background(MediaScrim.solid, in: Circle())
                .padding(Theme.SpacingKey.sm.value)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(fav.wrappedValue ? String(themeKit: "Remove from favourites") : String(themeKit: "Add to favourites"))
    }

    private var overlayTitleBar: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).textStyle(.labelMd700).foregroundStyle(theme.text(.textSecondaryInverse))
            if let subtitle {
                Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondaryInverse).opacity(0.9))
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(MediaScrim.gradient)
    }

    // MARK: Info

    private var infoSection: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            if !overlayTitle {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    Text(title).textStyle(.labelBase600).foregroundStyle(theme.text(.textPrimary)).lineLimit(2)
                    if let badge { Badge(badge).badgeStyle(.info).variant(.soft).size(.small) }
                }
                if let subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
            }
            if !tags.isEmpty {
                HStack(spacing: Theme.SpacingKey.xs.value) {
                    ForEach(tags, id: \.self) { Tag($0).variant(.soft) }
                }
            }
            if price != nil || rating != nil || footerSlot != nil {
                HStack(alignment: .center) {
                    if let price { PriceTag(price, currencyCode: resolvedCurrency).emphasis(.hero) }
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if let rating { ScoreBadge(rating) }
                }
            }
            if let footerSlot { footerSlot }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension DestinationCard {
    /// Surface fill (background token key, default `.bgBase`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// A location / description line under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }
    /// The price, rendered as a hero `PriceTag` in the footer row.
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    /// A 0–5 review score, rendered as a `ScoreBadge`.
    func rating(_ value: Double?) -> Self { copy { $0.rating = value } }
    /// A corner ribbon, e.g. "Top #1".
    func ribbon(_ text: String?, color: SemanticColor = .primary) -> Self { copy { $0.ribbon = text; $0.ribbonColor = color } }
    /// An inline badge next to the title.
    func badge(_ text: String?) -> Self { copy { $0.badge = text } }
    /// Tag chips under the title (Beach, Culture…).
    func tags(_ list: [String]) -> Self { copy { $0.tags = list } }
    /// A favourite heart bound to a flag, top-trailing on the media.
    func favorite(_ isFavorite: Binding<Bool>) -> Self { copy { $0.favorite = isFavorite } }
    /// Media aspect ratio (width ÷ height, default 4:3).
    func aspect(_ ratio: CGFloat) -> Self { copy { $0.aspect = max(0.2, ratio) } }
    /// Draw the title over the media (with a scrim) instead of below it.
    func overlayTitle(_ on: Bool = true) -> Self { copy { $0.overlayTitle = on } }
    /// Tap handler for the whole card.
    func onTap(_ action: (() -> Void)?) -> Self { copy { $0.onTap = action } }
    /// Replace the media with custom content (a carousel, a map…).
    func media<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.mediaSlot = AnyView(content()) } }
    /// Layer custom content over the media section. The ribbon, favourite heart and
    /// overlay title bar keep their position above it.
    func overlay<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.overlaySlot = AnyView(content()) } }
    /// A footer slot under the price row — a CTA, an amenity strip…
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }
    /// Surface elevation: none / soft / elevated.
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @State var fav = true
    PreviewMatrix("DestinationCard") {
        PreviewCase("Default · ribbon + price + rating + favourite") {
            DestinationCard("Bali & Unforgettable 3-Days")
                .subtitle("Indonesia").ribbon("Top #1")
                .price(1_450).rating(4.8).favorite($fav)
                .tags(["Beach", "Culture"])
        }
        PreviewCase("Inline badge") {
            DestinationCard("Santorini Sunset Trail")
                .subtitle("Greece")
                .badge("New")
                .price(2_300).rating(4.6)
        }
        PreviewCase("Overlay title (scrim over media)") {
            DestinationCard("Lisbon City Break")
                .subtitle("Portugal")
                .overlayTitle()
                .price(980).rating(4.4)
        }
    }
}

#Preview("Outlined style + overlay slot") {
    @Previewable @Environment(\.theme) var theme
    ScrollView {
        DestinationCard("Cappadocia Balloon Escape")
            .media {
                LinearGradient(colors: [theme.background(.bgHero), theme.background(.bgTurquoise)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .aspectRatio(4.0 / 3.0, contentMode: .fit)
            }
            .overlay {
                Text("Members only").textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textSecondaryInverse))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(MediaScrim.solid, in: Capsule())
            }
            .subtitle("Turkey").rating(4.9).price(9_800)
            .tags(["Adventure"])
            .cardStyle(.outlined)
            .padding()
    }
}
