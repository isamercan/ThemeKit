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
    private var imageMaxHeight: CGFloat = 160
    private var iconForeground: Color?
    private var iconBackground: Color?
    private var iconCircleSize: CGFloat = 88
    private var buttonTitle: String?
    private var action: (() -> Void)?
    private var secondaryTitle: String?
    private var onSecondary: (() -> Void)?

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
                        .fill(iconBackground ?? theme.background(.bgElevatorTertiary))
                        .frame(width: iconCircleSize, height: iconCircleSize)
                    Image(systemName: systemImage)
                        .font(.system(size: iconCircleSize * 0.36))
                        .foregroundStyle(iconForeground ?? theme.foreground(.fgHero))
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
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            if buttonTitle != nil || secondaryTitle != nil {
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

    /// Max height of the custom/animated illustration.
    func imageMaxHeight(_ h: CGFloat) -> Self { copy { $0.imageMaxHeight = h } }

    /// Override the icon glyph color (defaults to the `.fgHero` token, R4).
    func iconForeground(_ c: Color?) -> Self { copy { $0.iconForeground = c } }

    /// Override the icon circle fill (defaults to the `.bgElevatorTertiary` token, R4).
    func iconBackground(_ c: Color?) -> Self { copy { $0.iconBackground = c } }

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

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    EmptyState("No results found")
        .icon("magnifyingglass")
        .message("Try adjusting your search or filters to find what you're looking for.")
        .primaryAction("Clear filters") {}
        .padding()
}
