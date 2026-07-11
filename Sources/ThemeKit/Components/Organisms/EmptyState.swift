//
//  EmptyState.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Improved, token-bound rewrite of the reference EmptyCardView. An SF Symbol in
/// a faded circle, title, message and an optional primary action. (Lottie /
/// AppIcon dependencies dropped.) Per the modifier-based architecture
/// (COMPONENT_REFACTOR_RULES R1–R7) the init takes only its `title`; the media
/// variant (SF Symbol / custom `Image` / animated `URL`) selects an overload, and
/// every other axis (message, primary/secondary actions, icon styling) is a
/// chainable, order-free modifier.
///
///     EmptyState("No results found")
///         .icon("magnifyingglass")
///         .message("Try adjusting your search or filters.")
///         .primaryAction("Clear filters") { reset() }
public struct EmptyState: View {
    @Environment(\.theme) private var theme

    private enum Media { case symbol(String), image(Image), animated(URL?) }

    private var media: Media
    private let title: String?

    // Appearance/content/actions — mutated only through the modifiers below (R2).
    private var message: String?
    private var messageLinks: [(substring: String, action: () -> Void)] = []
    private var imageMaxHeight: CGFloat = 160
    private var iconForeground: Color?
    private var iconBackground: Color?
    private var iconForegroundKey: Theme.ForegroundColorKey?
    private var iconBackgroundKey: Theme.BackgroundColorKey?
    private var iconCircleSize: CGFloat = 88
    private var buttonTitle: String?
    private var action: (() -> Void)?
    private var secondaryTitle: String?
    private var onSecondary: (() -> Void)?
    /// Custom actions slot (`.actions { }`); replaces the stock buttons.
    private var actionsSlot: SlotContent?

    public init(_ title: String? = nil) {   // R1 — content; default SF Symbol media
        self.media = .symbol("tray")
        self.title = title
    }

    /// Custom illustration instead of the SF Symbol badge. Pass any `Image`
    /// (asset, rendered illustration, etc.). (Reference EmptyCardView parity.)
    public init(image: Image, title: String? = nil) {
        self.media = .image(image)
        self.title = title
    }

    /// Animated illustration (GIF / APNG) via the native `AnimatedImage` — the
    /// dependency-free stand-in for the reference's Lottie `.media` empty state.
    public init(animatedURL: URL?, title: String? = nil) {
        self.media = .animated(animatedURL)
        self.title = title
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            switch media {
            case .animated(let url):
                AnimatedImage(url)
                    .contentMode(.fit)
                    .frame(maxHeight: imageMaxHeight)
            case .image(let image):
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: imageMaxHeight)
            case .symbol(let systemImage):
                ZStack {
                    Circle()
                        .fill(iconBackground ?? iconBackgroundKey.map { theme.background($0) } ?? theme.background(.bgElevatorTertiary))
                        .frame(width: iconCircleSize, height: iconCircleSize)
                    Image(systemName: systemImage)
                        .font(.system(size: iconCircleSize * 0.36))
                        .foregroundStyle(iconForeground ?? iconForegroundKey.map { theme.foreground($0) } ?? theme.foreground(.fgHero))
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let title {
                    Text(title)
                        .textStyle(.headingBase)
                        .foregroundStyle(theme.text(.textPrimary))
                        .multilineTextAlignment(.center)
                }
                if let message {
                    Group {
                        if messageLinks.isEmpty {
                            Text(message)
                                .textStyle(.bodyBase400)
                                .foregroundStyle(theme.text(.textSecondary))
                        } else {
                            InlineText(message, links: messageLinks)
                                .inlineStyle(.bodyBase400)   // base color defaults to textSecondary
                        }
                    }
                    .multilineTextAlignment(.center)
                }
            }

            if let actionsSlot {
                // Custom actions replace the stock button stack (D4).
                actionsSlot
            } else if buttonTitle != nil || secondaryTitle != nil {
                VStack(spacing: Theme.SpacingKey.sm.value) {
                    if let buttonTitle, let action {
                        PrimaryButton(buttonTitle, action: action)
                    }
                    if let secondaryTitle, let onSecondary {
                        SecondaryButton(secondaryTitle, action: onSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension EmptyState {
    /// Leading SF Symbol shown in the faded circle (symbol-media only).
    func icon(_ systemImage: String) -> Self { copy { $0.media = .symbol(systemImage) } }

    /// Secondary message under the title.
    func message(_ s: String?) -> Self { copy { $0.message = s } }

    /// Message with inline tappable links (rendered via `InlineText`) — e.g.
    /// `.message("Read the docs.", links: [("docs", openDocs)])`.
    func message(_ s: String?, links: [(substring: String, action: () -> Void)]) -> Self {
        copy { $0.message = s; $0.messageLinks = links }
    }

    /// Max height of the custom/animated illustration.
    func imageMaxHeight(_ h: CGFloat) -> Self { copy { $0.imageMaxHeight = h } }

    /// Raw glyph-color override (back-compat); prefer the token-bound overload.
    @available(*, deprecated, message: "Use iconForeground(_: Theme.ForegroundColorKey) — the token-bound overload.")
    func iconForeground(_ c: Color?) -> Self { copy { $0.iconForeground = c } }

    /// Token-bound overload — glyph uses a theme foreground key, resolved against the environment theme.
    func iconForeground(_ key: Theme.ForegroundColorKey) -> Self { copy { $0.iconForegroundKey = key } }

    /// Raw circle-fill override (back-compat); prefer the token-bound overload.
    @available(*, deprecated, message: "Use iconBackground(_: Theme.BackgroundColorKey) — the token-bound overload.")
    func iconBackground(_ c: Color?) -> Self { copy { $0.iconBackground = c } }

    /// Token-bound overload — circle fill uses a theme background key, resolved against the environment theme.
    func iconBackground(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.iconBackgroundKey = key } }

    /// Diameter of the icon circle.
    func iconCircleSize(_ size: CGFloat) -> Self { copy { $0.iconCircleSize = size } }

    /// Primary call-to-action button (title + handler).
    func primaryAction(_ title: String?, action: (() -> Void)?) -> Self {
        copy { $0.buttonTitle = title; $0.action = action }
    }

    /// Secondary call-to-action button (title + handler).
    func secondaryAction(_ title: String?, action: (() -> Void)?) -> Self {
        copy { $0.secondaryTitle = title; $0.onSecondary = action }
    }

    /// Custom actions slot (the `ResultView.actions` precedent) — arbitrary
    /// content (a `ButtonGroup`, a link row…) rendered where the stock
    /// primary/secondary buttons go; when set it replaces them.
    func actions<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.actionsSlot = SlotContent(content) }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 48) {
            EmptyState("No results found")
                .icon("magnifyingglass")
                .message("Try adjusting your search or filters to find what you're looking for.")
                .primaryAction("Clear filters") {}

            // D4 — custom `.actions { }` slot replaces the stock buttons.
            EmptyState("Your trips will appear here")
                .icon("airplane")
                .message("Plan your first trip to get started.")
                .actions {
                    HStack(spacing: Theme.SpacingKey.sm.value) {
                        ThemeButton("Search flights") {}.size(.small)
                        ThemeButton("Explore deals") {}.variant(.ghost).size(.small)
                    }
                }
        }
        .padding()
    }
}
