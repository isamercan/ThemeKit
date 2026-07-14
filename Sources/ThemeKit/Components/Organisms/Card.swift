//
//  Card.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum CardElevation {
    case none, soft, elevated
}

/// Organism. A surface container with token padding / radius / elevation. An
/// optional header (title / subtitle + a trailing `extra` action, divided from
/// the body) and an `isLoading` skeleton bring it toward Ant Card.
public struct Card<Content: View>: View {
    private let title: String?
    private let action: (() -> Void)?
    private let content: () -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var elevation: CardElevation = .soft
    /// Raw padding (deprecated escape hatch); `paddingKey` wins when set.
    private var padding: CGFloat = 16
    /// Token padding (`contentPadding(_ key:)`) — resolved against the
    /// environment theme so it re-skins with a spacing-scale change.
    private var paddingKey: Theme.SpacingKey?

    private var resolvedPadding: CGFloat { paddingKey.map { theme.spacing($0) } ?? padding }
    private var subtitle: String?
    private var extraTitle: String?
    private var onExtra: (() -> Void)?
    private var isLoading = false
    private var customHeader: SlotContent?
    private var footerContent: SlotContent?
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
        customHeader != nil || title != nil || subtitle != nil || (extraTitle != nil && onExtra != nil)
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
        .padding(.horizontal, resolvedPadding)
        .padding(.top, resolvedPadding)
        .padding(.bottom, Theme.SpacingKey.sm.value)
    }

    @ViewBuilder
    private var titleHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
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
                .padding(.horizontal, resolvedPadding)
                .padding(.top, Theme.SpacingKey.sm.value)
                .padding(.bottom, resolvedPadding)
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

    /// The composed content (header + body, padded) — the surface chrome around it
    /// is supplied by the active ``CardStyle``.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                DividerView().size(.small)
            }
            Group {
                if isLoading { loadingPlaceholder } else { content() }
            }
            .padding(resolvedPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            if footerContent != nil {
                DividerView().size(.small)
                footer
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
    func contentPadding(_ key: Theme.SpacingKey) -> Self {
        copy { $0.paddingKey = key }
    }

    /// Raw inner content padding (back-compat); prefer the token-bound overload.
    @available(*, deprecated, message: "Use contentPadding(_: Theme.SpacingKey) — the token-bound overload.")
    func contentPadding(_ padding: CGFloat) -> Self {
        copy { $0.padding = padding; $0.paddingKey = nil }
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
    @Previewable @Environment(\.theme) var theme
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
    }
}
