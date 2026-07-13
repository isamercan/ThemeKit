//
//  HotelResultCard.swift
//  ThemeKit
//
//  Organism. A rich hotel/property search-result card — an image carousel with a
//  favourite heart and optional corner badge, the name + location, a score/review
//  block, feature tags, scrollable promo chips, and a price block (stay descriptor,
//  discount badge, struck-through original, price, an extra-discount line and a CTA).
//  Token-bound; reuses RemoteImage, ScoreBadge, PriceTag, Badge. Every part is a
//  modifier so a developer composes exactly what they need.
//
//  The outer shell (surface fill, corner clipping, elevation shadow/border) is drawn
//  by the active `CardStyle` from the environment — the `.surface()/.cornerRadius()/
//  .elevation()` modifiers feed the `CardStyleConfiguration`, so the default look is
//  unchanged while `.cardStyle(_:)` can swap in a completely different shell.
//  `.media {}` replaces the built-in gallery; `.overlay {}` layers content over it.
//

import SwiftUI

public struct HotelResultCard: View {
    @Environment(\.theme) private var theme
    @Environment(\.componentDensity) private var density
    @Environment(\.cardStyle) private var cardStyle
    @Environment(\.formatDefaults) private var formatDefaults
    @Environment(\.locale) private var locale

    private let name: String
    // Content — mutated only through the modifiers below (R2).
    private var images: [URL] = []
    private var locationText: String?
    private var locationIcon = "mappin.and.ellipse"
    private var score: Double?
    private var scoreLabel: String?
    private var reviews: Int?
    private var reviewsSuffixOverride: String?
    /// Render-time default — re-resolves through the localization chain on
    /// every body pass, so a live language switch is never frozen at init.
    private var reviewsSuffix: String { reviewsSuffixOverride ?? String(themeKit: "reviews") }
    private var features: [String] = []
    private var promos: [String] = []
    private var price: Decimal?
    private var currencyCode: String?
    private var originalPrice: Decimal?
    private var discountText: String?
    private var stayText: String?
    private var extraDiscountLabel: String?
    private var extraDiscountAmount: Decimal?
    private var cornerBadge: String?
    private var favorite: Binding<Bool>?
    private var onSelect: (() -> Void)?
    private var footerSlot: AnyView?
    private var mediaSlot: AnyView?
    private var overlaySlot: AnyView?
    // Styling — token-fed.
    private var accent: SemanticColor?
    private var imageHeight: CGFloat = 200
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .soft
    private var surfaceKey: Theme.BackgroundColorKey = .bgBase
    private var showsPageDots = true

    @State private var page = 0

    public init(name: String) { self.name = name }   // R1

    private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: radiusRole.value, style: .continuous) }
    private var accentColor: Color { accent.map { theme.resolve($0).base } ?? theme.foreground(.fgHero) }

    /// Explicit `price(_:currencyCode:)` > `\.formatDefaults` > locale currency > "USD" (§10).
    private var resolvedCurrency: String {
        currencyCode ?? formatDefaults.currencyCode ?? locale.currency?.identifier ?? "USD"
    }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — built-ins and custom styles go through the same gate.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
            .contentShape(shape)
            .accessibilityElement(children: .contain)
    }

    /// The card's inner layout — everything inside the shell.
    private var cardContent: some View {
        VStack(spacing: 0) {
            imageArea
            content
        }
    }

    // MARK: Image

    private var imageArea: some View {
        ZStack(alignment: .top) {
            media
            .frame(height: imageHeight)
            .frame(maxWidth: .infinity)
            .clipped()

            // Custom overlay sits above the media, below the badge/favourite row.
            if let overlaySlot { overlaySlot }

            HStack(alignment: .top) {
                if let cornerBadge {
                    Text(cornerBadge).textStyle(.labelSm700).foregroundStyle(accent.map { theme.resolve($0).onSolid } ?? theme.text(.textSecondaryInverse))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(accent.map { theme.resolve($0).solid } ?? theme.foreground(.fgHero), in: Capsule())
                }
                Spacer()
                if let favorite { heart(favorite) }
            }
            .padding(density.scale(Theme.SpacingKey.sm.value))
        }
        .frame(height: imageHeight)
    }

    /// The media section: the `.media {}` slot when set, else the built-in gallery.
    @ViewBuilder private var media: some View {
        if let mediaSlot { mediaSlot } else { carousel }
    }

    @ViewBuilder private var carousel: some View {
        #if os(iOS)
        if images.count > 1 {
            TabView(selection: $page) {
                ForEach(Array(images.enumerated()), id: \.offset) { i, url in
                    RemoteImage(url).contentMode(.fill).tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: showsPageDots ? .always : .never))
        } else {
            RemoteImage(images.first).contentMode(.fill)
        }
        #else
        RemoteImage(images.first).contentMode(.fill)
        #endif
    }

    private func heart(_ isFav: Binding<Bool>) -> some View {
        Button { isFav.wrappedValue.toggle() } label: {
            Image(systemName: isFav.wrappedValue ? "heart.fill" : "heart")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(isFav.wrappedValue ? theme.foreground(.systemcolorsFgError) : theme.text(.textSecondaryInverse))
                .frame(width: 40, height: 40)
                .background(MediaScrim.solid, in: Circle())
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKit: "Favourite"))
    }

    // MARK: Content

    private var content: some View {
        VStack(alignment: .leading, spacing: density.scale(Theme.SpacingKey.sm.value)) {
            Text(name).textStyle(.headingSm).foregroundStyle(theme.text(.textPrimary)).lineLimit(2)
            if let locationText {
                HStack(spacing: 4) {
                    Image(systemName: locationIcon).font(.system(size: 12)).foregroundStyle(theme.text(.textTertiary))
                    Text(locationText).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
                }
            }
            if let score { scoreRow(score) }
            if !features.isEmpty { featureRow }
            if !promos.isEmpty { promoRow }
            if price != nil || footerSlot != nil { priceBlock }
            if let footerSlot { footerSlot }
        }
        .padding(density.scale(Theme.SpacingKey.md.value))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scoreRow(_ value: Double) -> some View {
        HStack(spacing: 8) {
            ScoreBadge(value)
            if let scoreLabel { Text(scoreLabel).textStyle(.labelBase700).foregroundStyle(theme.text(.textPrimary)) }
            if let reviews { Text("\(reviews) \(reviewsSuffix)").textStyle(.bodySm400).foregroundStyle(theme.text(.textTertiary)) }
        }
    }

    private var featureRow: some View {
        HStack(spacing: 6) {
            ForEach(Array(features.prefix(3).enumerated()), id: \.offset) { i, feat in
                if i > 0 { Circle().fill(theme.text(.textTertiary)).frame(width: 3, height: 3) }
                Text(feat).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary)).lineLimit(1)
            }
        }
    }

    private var promoRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(promos.enumerated()), id: \.offset) { _, promo in
                    Text(promo).textStyle(.labelSm600).foregroundStyle(accentColor)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(accent.map { theme.resolve($0).bg } ?? theme.background(.bgElevatorTertiary),
                                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous).stroke(accentColor.opacity(0.5), lineWidth: 1))
                }
            }
        }
    }

    /// The reusable ``PriceBreakdown`` molecule, configured from this card's fields.
    private var priceBreakdown: PriceBreakdown? {
        guard let price else { return nil }
        var b = PriceBreakdown(price, currencyCode: resolvedCurrency).size(.large).emphasis(.standard)
        if let stayText { b = b.note(stayText) }
        if let originalPrice { b = b.original(originalPrice) }
        if let discountText { b = b.discountBadge(discountText) }
        if let extraDiscountLabel, let extraDiscountAmount { b = b.extra(extraDiscountLabel, extraDiscountAmount) }
        return b
    }

    private var priceBlock: some View {
        HStack(alignment: .bottom) {
            priceBreakdown
            Spacer()
            if let onSelect {
                Button(action: onSelect) {
                    Image(systemName: "arrow.right").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(accentColor).frame(width: 44, height: 44)
                        .overlay(Circle().stroke(accentColor, lineWidth: 1.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Select"))
            }
        }
        .padding(density.scale(Theme.SpacingKey.sm.value))
        .background(accent.map { theme.resolve($0).bg } ?? theme.background(.bgSecondary), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension HotelResultCard {
    func image(_ url: URL?) -> Self { copy { if let url { $0.images = [url] } } }
    func images(_ urls: [URL]) -> Self { copy { $0.images = urls } }
    func location(_ text: String?, icon: String = "mappin.and.ellipse") -> Self { copy { $0.locationText = text; $0.locationIcon = icon } }
    func score(_ value: Double?, label: String? = nil, reviews: Int? = nil) -> Self { copy { $0.score = value; $0.scoreLabel = label; $0.reviews = reviews } }
    /// Localise the "reviews" suffix (English default).
    func reviewsSuffix(_ text: String) -> Self { copy { $0.reviewsSuffixOverride = text } }
    func features(_ items: [String]) -> Self { copy { $0.features = items } }
    func promos(_ items: [String]) -> Self { copy { $0.promos = items } }
    func price(_ amount: Decimal?, currencyCode: String = "USD") -> Self { copy { $0.price = amount; $0.currencyCode = currencyCode } }
    /// Omitted-currency overload — the currency resolves from `\.formatDefaults`,
    /// then the locale's currency, then "USD".
    func price(_ amount: Decimal?) -> Self { copy { $0.price = amount } }
    func original(_ amount: Decimal?) -> Self { copy { $0.originalPrice = amount } }
    func discountBadge(_ text: String?) -> Self { copy { $0.discountText = text } }
    func stay(_ text: String?) -> Self { copy { $0.stayText = text } }
    func extraDiscount(_ label: String, _ amount: Decimal) -> Self { copy { $0.extraDiscountLabel = label; $0.extraDiscountAmount = amount } }
    func badge(_ text: String?) -> Self { copy { $0.cornerBadge = text } }
    func favorite(_ binding: Binding<Bool>) -> Self { copy { $0.favorite = binding } }
    func onSelect(_ action: @escaping () -> Void) -> Self { copy { $0.onSelect = action } }
    func footer<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.footerSlot = AnyView(content()) } }
    /// Replace the built-in image gallery with custom media content. The view is
    /// sized to the card's `imageHeight` and clipped; badge/favourite/overlay still
    /// layer on top. Omit to keep the default `image(_:)`/`images(_:)` gallery.
    func media<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.mediaSlot = AnyView(content()) } }
    /// Layer custom content over the media section (top-aligned in its ZStack).
    /// The corner badge and favourite button keep their position above it.
    func overlay<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.overlaySlot = AnyView(content()) } }
    // Styling (token-fed)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }
    func imageHeight(_ height: CGFloat) -> Self { copy { $0.imageHeight = max(80, height) } }
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    func showsPageDots(_ on: Bool) -> Self { copy { $0.showsPageDots = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("HotelResultCard") {
        PreviewCase("Full · deal, promos, extra discount") {
            HotelResultCard(name: "Mirage Park Resort")
                .location("Kemer, Antalya")
                .score(8.9, label: "Very good", reviews: 949)
                .features(["Premium All-inclusive", "Seafront"])
                .promos(["Special 7.500 TL MaxiPoint!", "50% deposit"])
                .stay("2 Rooms | 4 Nights")
                .original(248_000).discountBadge("-23%").price(190_960)
                .extraDiscount("Extra 8%", 175_683)
                .badge("Deal")
                .favorite(.constant(true))
                .onSelect { }
        }
        PreviewCase("Minimal · score + price, error accent") {
            HotelResultCard(name: "City Inn Express")
                .location("Downtown")
                .score(7.8, label: "Good", reviews: 120)
                .price(42_000)
                .accent(.error)
                .favorite(.constant(false))
        }
    }
}

#Preview("Outlined style + media slot") {
    @Previewable @Environment(\.theme) var theme
    ScrollView {
        HotelResultCard(name: "Fable Boutique Hotel")
            .media {
                LinearGradient(colors: [theme.background(.bgHero), theme.background(.bgTurquoise)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            .overlay {
                Text("Members only").textStyle(.labelSm700)
                    .foregroundStyle(theme.text(.textSecondaryInverse))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(MediaScrim.solid, in: Capsule())
                    .padding(Theme.SpacingKey.sm.value)
            }
            .location("Göcek, Muğla")
            .score(9.4, label: "Exceptional", reviews: 212)
            .features(["Adults only", "Private beach"])
            .price(84_500)
            .badge("New")
            .favorite(.constant(false))
            .cardStyle(.outlined)
            .padding()
    }
}
