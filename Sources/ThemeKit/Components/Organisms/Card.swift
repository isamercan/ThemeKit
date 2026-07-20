//
//  Card.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum CardElevation {
    case none, soft, elevated
}

/// Where a ``Card`` renders its `cover(_:)` media.
public enum CardCoverPlacement {
    /// Full-bleed media above the header/body — the image bleeds to the card
    /// edges and is clipped to the top corners (HeroUI "with image" cards).
    case top
    /// Media fills the whole card as a background; the header floats at the top
    /// and the footer at the bottom, over the image (HeroUI cover cards). The
    /// `content` body is omitted in this mode — drive the card from cover + slots.
    case fill
}

// Demand-minted spacing tokens Card reads from the active theme. The naming
// grammar is `<component>-<slot>-padding` (umbrella `<component>-padding`),
// resolving down to `Theme.SpacingRole.box`, then `.md` (16). Private on
// purpose — consumers use the modifiers below; themes/CSS declare these names
// (`--card-padding`, `--card-header-padding`, …).
private let cardPaddingToken = "card-padding"
private let cardHeaderPaddingToken = "card-header-padding"
private let cardBodyPaddingToken = "card-body-padding"
private let cardFooterPaddingToken = "card-footer-padding"

/// Organism. A surface container with token padding / radius / elevation. An
/// optional header (title / subtitle + a trailing `extra` action, divided from
/// the body) and an `isLoading` skeleton bring it toward Ant Card.
///
/// **Padding contract.** Each slot's inner padding resolves through one chain
/// (first hit wins):
///
///     instance modifier (.headerPadding / .footerPadding / .contentPadding)
///       → deprecated raw CGFloat escape hatch
///       → slot theme token   ("card-header-padding" / "card-body-padding" / "card-footer-padding")
///       → umbrella theme token ("card-padding" — CSS `--card-padding`)
///       → spacing role       (`Theme.SpacingRole.box`, default 16)
///       → `Theme.SpacingKey.md` (16, bundled themes)
///
/// The `sm` (8) gaps between a slot and its divider are deliberately NOT part
/// of this contract — they are fixed chrome, not themeable padding.
public struct Card<Content: View>: View {
    private let title: String?
    private let action: (() -> Void)?
    private let content: () -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var elevation: CardElevation = .soft
    /// Raw padding (deprecated escape hatch); `paddingKey` wins when set.
    /// `nil` by default so the theme tokens / spacing role decide.
    private var padding: CGFloat?
    /// Token padding (`contentPadding(_ key:)`) — resolved against the
    /// environment theme so it re-skins with a spacing-scale change.
    private var paddingKey: Theme.SpacingKey?
    /// Per-slot token padding (`headerPadding(_:)` / `footerPadding(_:)`).
    private var headerPaddingKey: Theme.SpacingKey?
    private var footerPaddingKey: Theme.SpacingKey?

    /// General (umbrella) padding — see the padding contract in the type doc.
    private var resolvedPadding: CGFloat {
        paddingKey.map { theme.spacing($0) }
            ?? padding
            ?? theme.spacing(token: cardPaddingToken)
            ?? theme.spacing(.box)
    }
    private var resolvedHeaderPadding: CGFloat {
        headerPaddingKey.map { theme.spacing($0) }
            ?? theme.spacing(token: cardHeaderPaddingToken)
            ?? resolvedPadding
    }
    private var resolvedBodyPadding: CGFloat {
        paddingKey.map { theme.spacing($0) }
            ?? padding
            ?? theme.spacing(token: cardBodyPaddingToken)
            ?? theme.spacing(token: cardPaddingToken)
            ?? theme.spacing(.box)
    }
    private var resolvedFooterPadding: CGFloat {
        footerPaddingKey.map { theme.spacing($0) }
            ?? theme.spacing(token: cardFooterPaddingToken)
            ?? resolvedPadding
    }
    private var subtitle: String?
    private var extraTitle: String?
    private var onExtra: (() -> Void)?
    private var isLoading = false
    private var customHeader: SlotContent?
    private var footerContent: SlotContent?
    private var coverContent: SlotContent?
    private var coverPlacement: CardCoverPlacement = .top
    private var overlineText: String?
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var radius: Theme.RadiusRole = .box   // corner size axis (threaded into CardStyle)
    private var isSelected = false                // selection state → hero border in the default style

    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle

    public init(_ title: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {   // R1
        self.title = title
        self.action = action
        self.content = content
    }

    private var hasHeader: Bool {
        customHeader != nil || overlineText != nil || title != nil || subtitle != nil || (extraTitle != nil && onExtra != nil)
    }

    /// A custom header slot replaces the string title/subtitle header entirely;
    /// both get the same padding treatment and divider below.
    @ViewBuilder
    private var header: some View {
        Group {
            if let customHeader {
                customHeader
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                titleHeader
            }
        }
        .padding(.horizontal, resolvedHeaderPadding)
        .padding(.top, resolvedHeaderPadding)
        .padding(.bottom, Theme.SpacingKey.sm.value)
    }

    @ViewBuilder
    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
                if let overlineText {
                    Text(overlineText).textCase(.uppercase).textStyle(.labelSm600)
                        .foregroundStyle(theme.text(.textSecondary))
                }
                if let title {
                    Text(title).textStyle(.labelLg600).foregroundStyle(theme.text(.textPrimary))
                }
                if let subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            if let extraTitle, let onExtra {
                Button(action: onExtra) {
                    Text(extraTitle).textStyle(.labelSm600).foregroundStyle(theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// Footer slot below the body — divided from it, mirroring the header
    /// treatment (same horizontal padding, `sm` gap to the divider).
    @ViewBuilder
    private var footer: some View {
        if let footerContent {
            footerContent
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, resolvedFooterPadding)
                .padding(.top, Theme.SpacingKey.sm.value)
                .padding(.bottom, resolvedFooterPadding)
        }
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Skeleton(.capsule).size(height: 12).frame(maxWidth: 180)
            Skeleton(.capsule).size(height: 12)
            Skeleton(.capsule).size(height: 12).frame(maxWidth: 240)
        }
    }

    /// True when the caller supplied a real body (not `EmptyView()`), so a
    /// cover / slot-only card doesn't reserve an empty padded body region.
    private var hasBody: Bool { Content.self != EmptyView.self }

    /// The composed content — the surface chrome around it is supplied by the
    /// active ``CardStyle``. Layout depends on `cover(_:)`: a `.top` cover sits
    /// full-bleed above the header/body; a `.fill` cover becomes the background
    /// with the header/footer floating over it. Non-cover cards keep the classic
    /// divided header / body / footer chrome; a cover drops the dividers (the
    /// HeroUI look).
    @ViewBuilder
    private var cardContent: some View {
        if coverPlacement == .fill, let coverContent {
            coverContent
                .frame(maxWidth: .infinity)
                .overlay(alignment: .top) { if hasHeader { header } }
                .overlay(alignment: .bottom) { if footerContent != nil { footer } }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                if let coverContent {
                    coverContent.frame(maxWidth: .infinity)   // full-bleed, clipped to the top corners
                }
                if hasHeader {
                    header
                    if coverContent == nil { DividerView().size(.small) }
                }
                if isLoading {
                    loadingPlaceholder
                        .padding(resolvedBodyPadding).frame(maxWidth: .infinity, alignment: .leading)
                } else if hasBody {
                    content()
                        .padding(resolvedBodyPadding).frame(maxWidth: .infinity, alignment: .leading)
                }
                if footerContent != nil {
                    if coverContent == nil { DividerView().size(.small) }
                    footer
                }
            }
        }
    }

    private var styledSurface: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: isSelected,
            surfaceKey: surfaceKey,
            radius: radius
        ))
    }

    public var body: some View {
        if let action {
            Button(action: action) { styledSurface }
                .buttonStyle(PressFeedbackStyle())
        } else {
            styledSurface
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Card {
    /// Secondary line under the title in the card header.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Surface elevation: none / soft / elevated.
    func elevation(_ elevation: CardElevation) -> Self { copy { $0.elevation = elevation } }

    /// Inner content padding by spacing token (named so it doesn't shadow the
    /// native `.padding`; the `SurfaceView`/`TicketStub` twin) — resolved
    /// against the environment theme, so it re-skins with a spacing change.
    /// This is the *general* override; `headerPadding(_:)` / `footerPadding(_:)`
    /// tune single slots. Unset, the theme decides (`--card-padding` /
    /// `Theme.SpacingRole.box`, default 16).
    func contentPadding(_ key: Theme.SpacingKey) -> Self {
        copy { $0.paddingKey = key }
    }

    /// Raw inner content padding (back-compat); prefer the token-bound overload.
    @available(*, deprecated, message: "Use contentPadding(_: Theme.SpacingKey) — the token-bound overload.")
    func contentPadding(_ padding: CGFloat) -> Self {
        copy { $0.padding = padding; $0.paddingKey = nil }
    }

    /// Header-slot padding by spacing token — overrides the general
    /// `contentPadding(_:)` / theme padding for the header area only
    /// (theme twin: `--card-header-padding`).
    func headerPadding(_ key: Theme.SpacingKey) -> Self {
        copy { $0.headerPaddingKey = key }
    }

    /// Footer-slot padding by spacing token — overrides the general
    /// `contentPadding(_:)` / theme padding for the footer area only
    /// (theme twin: `--card-footer-padding`).
    func footerPadding(_ key: Theme.SpacingKey) -> Self {
        copy { $0.footerPaddingKey = key }
    }

    /// Trailing header action (Ant `extra`) — renders when both title and action are set.
    func extraAction(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.extraTitle = title; $0.onExtra = action }
    }

    /// Replace the body with a skeleton placeholder while content loads.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Custom header slot (HeroUI `Card.Header`) — arbitrary content (icon,
    /// badge, media…) rendered above the body with the same padding and divider
    /// as the string header. When set it replaces the title/subtitle/extra header.
    func header<H: View>(@ViewBuilder _ header: () -> H) -> Self {
        copy { $0.customHeader = SlotContent(header) }
    }

    /// Footer slot (HeroUI `Card.Footer`) — bottom-aligned content such as
    /// actions, rendered below the body inside the card chrome and divided from
    /// it, mirroring the header treatment.
    func footer<F: View>(@ViewBuilder _ footer: () -> F) -> Self {
        copy { $0.footerContent = SlotContent(footer) }
    }

    /// A small eyebrow/overline label above the title (HeroUI "NEW" tag) —
    /// uppercased in a muted label style. Part of the string header, so it also
    /// works when only a `title`/`subtitle` is set.
    func overline(_ text: String?) -> Self { copy { $0.overlineText = text } }

    /// Full-bleed cover media (the HeroUI "with image" cards). `.top` (default)
    /// renders it above the header/body, edge-to-edge and clipped to the card's
    /// top corners; `.fill` makes it the card background with the header floating
    /// at the top and the footer at the bottom, over the image. A cover drops the
    /// header/footer dividers. Size the media yourself, e.g.
    /// `Image(…).resizable().aspectRatio(contentMode: .fill).frame(height: 180)`.
    func cover<C: View>(_ placement: CardCoverPlacement = .top, @ViewBuilder _ content: () -> C) -> Self {
        copy { $0.coverContent = SlotContent(content); $0.coverPlacement = placement }
    }

    /// Surface fill by background token, threaded into the active ``CardStyle``'s
    /// configuration (HeroUI `Card` `variant`): default → `.bgWhite`,
    /// `secondary` → `.bgSecondaryLight`, `tertiary` → `.bgTertiary`;
    /// HeroUI `transparent` ≈ `.cardStyle(.outlined)` instead.
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }

    /// Corner-radius role — the card "size" axis: `.box` (default, 16),
    /// `.field` (8), or `.selector` (6). Threaded into the active ``CardStyle``,
    /// so custom styles honor it too.
    func radius(_ role: Theme.RadiusRole) -> Self { copy { $0.radius = role } }

    /// Marks the card as selected — the default / outlined styles promote the
    /// border to the hero token (HeroUI `isSelected`).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

struct CardShadow: ViewModifier {
    let elevation: CardElevation
    func body(content: Content) -> some View {
        switch elevation {
        case .none: content
        case .soft: content.themeShadow(.soft)
        case .elevated: content.themeShadow(.elevated)
        }
    }
}

public extension View {
    /// Applies token-bound elevation — a themed drop shadow — to **any** view, using
    /// the same `.none / .soft / .elevated` ladder ThemeKit's surface components use.
    /// Lift your own view to a design-system elevation without hand-rolling a raw
    /// `.shadow(...)`, so it re-skins with the theme (and dark mode) for free:
    ///
    ///     myPanel.elevation(.soft)
    ///
    /// ThemeKit's own surfaces (``Card``, ``SurfaceView``, …) expose an
    /// `.elevation(_:)` returning `Self`; on those the component's own modifier wins,
    /// so this never changes their behaviour.
    func elevation(_ elevation: CardElevation) -> some View {
        modifier(CardShadow(elevation: elevation))
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("Card") {
                PreviewCase("Basic") {
                    Card {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Card title").textStyle(.headingSm)
                            Text("Supporting body text inside a card surface.").textStyle(.bodyBase400)
                                .foregroundStyle(theme.text(.textSecondary))
                        }
                    }
                }
                PreviewCase("Elevated") {
                    Card {
                        Text("Elevated card").textStyle(.labelMd600)
                    }
                    .elevation(.elevated)
                }
                // Footer slot: bottom-aligned actions below a divider.
                PreviewCase("Footer slot") {
                    Card("Living room sofa") {
                        Text("Perfect for modern tropical spaces.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .subtitle("Collection 2026")
                    .footer {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            ThemeButton("Buy now") {}.size(.small)
                            ThemeButton("Add to cart") {}.variant(.ghost).size(.small)
                        }
                    }
                }
                // Custom header slot: icon + badge replace the string header.
                PreviewCase("Custom header slot") {
                    Card {
                        Text("Custom header replaces the title/subtitle row.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .header {
                        HStack(spacing: Theme.SpacingKey.sm.value) {
                            Icon(systemName: "sparkles")
                            Text("Featured").textStyle(.labelLg600)
                                .foregroundStyle(theme.text(.textPrimary))
                            Spacer(minLength: 0)
                            Badge("New").badgeStyle(.success)
                        }
                    }
                }
                // Surface-fill variant (HeroUI `secondary`).
                PreviewCase("Secondary surface") {
                    Card("Secondary surface") {
                        Text("Card filled with the secondary background token.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .surface(.bgSecondaryLight)
                }
                // Theme-driven padding: a CSS theme minting `--card-padding` /
                // `--card-header-padding`, scoped to this subtree via `.theme(_:)`.
                PreviewCase("CSS-padded theme") {
                    let cssTheme: Theme = {
                        let t = Theme()
                        t.setTheme(css: """
                            :root {
                              --accent: #056bfd;
                              --card-padding: 24px;
                              --card-header-padding: 8px;
                            }
                            """)
                        return t
                    }()
                    Card("CSS-padded") {
                        Text("24pt body from `--card-padding`; 8pt header from `--card-header-padding`.")
                            .textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .theme(cssTheme)
                }
                // Per-slot instance overrides: header/footer tokens beat the general padding.
                PreviewCase("Slot padding overrides") {
                    Card("Slot overrides") {
                        Text("Header at `.base` (24), footer at `.sm` (8), body default.")
                            .textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .headerPadding(.base)
                    .footerPadding(.sm)
                    .footer {
                        Text("Tight footer").textStyle(.labelSm600)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                }
                // Token content padding (G5): the SpacingKey overload.
                PreviewCase("Compact padding") {
                    Card("Compact padding") {
                        Text("Inner padding from the `.sm` spacing token.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .contentPadding(.sm)
                }
                PreviewCase("Loading skeleton") {
                    Card("Loading") {
                        Text("Replaced by the skeleton while loading.").textStyle(.bodyBase400)
                    }
                    .loading()
                }
                // Style-protocol case — the outlined `CardStyle` from the environment.
                PreviewCase("Outlined style") {
                    Card("Outlined") {
                        Text("Chrome drawn by the outlined card style.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .cardStyle(.outlined)
                }
                // Flat variant (HeroUI `flat`) — surface fill, no border, no shadow.
                PreviewCase("Flat style") {
                    Card("Flat") {
                        Text("Surface fill with no border or shadow.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .surface(.bgSecondaryLight)   // Card modifier — before the style env modifier
                    .cardStyle(.flat)
                }
                // Size axis — a tighter corner-radius role.
                PreviewCase("Compact radius") {
                    Card("Field radius") {
                        Text("Corner from the `.field` radius role (8).").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .radius(.field)
                }
                // Selection state — hero border.
                PreviewCase("Selected") {
                    Card("Selected") {
                        Text("Promoted to the hero border while selected.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .selected()
                }
                // Overline eyebrow above the title.
                PreviewCase("Overline") {
                    Card("Home Robot") {
                        Text("An eyebrow label sits above the title.").textStyle(.bodyBase400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    .overline("New")
                    .subtitle("Available soon")
                }
                // With image (HeroUI): full-bleed cover on top + a meta footer, no body.
                PreviewCase("With image (cover)") {
                    Card { EmptyView() }
                        .cover {
                            LinearGradient(colors: [.pink.opacity(0.55), .orange.opacity(0.55)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                                .frame(height: 130)
                                .overlay(Image(systemName: "photo").font(.title).foregroundStyle(.white))
                        }
                        .footer {
                            HStack {
                                Text("Fruits").textStyle(.labelMd600).foregroundStyle(theme.text(.textPrimary))
                                Spacer(minLength: 0)
                                Text("18 pictures").textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                            }
                        }
                        .frame(width: 200)
                }
                // Cover overlay (HeroUI): media fills the card, header + footer float over it.
                PreviewCase("Cover overlay") {
                    Card { EmptyView() }
                        .cover(.fill) {
                            LinearGradient(colors: [.blue.opacity(0.65), .black.opacity(0.55)],
                                           startPoint: .top, endPoint: .bottom)
                                .frame(width: 220, height: 260)
                        }
                        .header {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("NEO").textStyle(.labelSm600).foregroundStyle(.white.opacity(0.85))
                                Text("Home Robot").textStyle(.labelLg600).foregroundStyle(.white)
                            }
                        }
                        .footer {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("Available soon").textStyle(.labelMd600).foregroundStyle(.white)
                                    Text("Get notified").textStyle(.bodySm400).foregroundStyle(.white.opacity(0.85))
                                }
                                Spacer(minLength: 0)
                                ThemeButton("Notify me") {}.size(.small)
                            }
                        }
                }
                // Card as a form container (HeroUI "with form"): custom content = fields.
                PreviewCase("With form") {
                    Card("Log in") {
                        VStack(spacing: Theme.SpacingKey.sm.value) {
                            TextInput("Email", text: .constant(""))
                            TextInput("Password", text: .constant(""))
                            ThemeButton("Sign in") {}.fullWidth()
                        }
                    }
                    .subtitle("Welcome back")
                    .frame(width: 260)
                }
            }
        }
    }
    return Demo()
}
