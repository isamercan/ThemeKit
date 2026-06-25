//
//  EmptyState.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference EmptyCardView. An SF Symbol in
//  a faded circle, title, message and an optional primary action. (Lottie /
//  AppIcon dependencies dropped.)
//

import SwiftUI

public struct EmptyState: View {
    private let systemImage: String
    private let image: Image?
    private let animatedURL: URL?
    private let imageMaxHeight: CGFloat
    private let iconForeground: Color?
    private let iconBackground: Color?
    private let iconCircleSize: CGFloat
    private let title: String?
    private let message: String?
    private let buttonTitle: String?
    private let action: (() -> Void)?

    public init(
        systemImage: String = "tray",
        iconForeground: Color? = nil,
        iconBackground: Color? = nil,
        iconCircleSize: CGFloat = 88,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = systemImage
        self.image = nil
        self.animatedURL = nil
        self.imageMaxHeight = 160
        self.iconForeground = iconForeground
        self.iconBackground = iconBackground
        self.iconCircleSize = iconCircleSize
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    /// Custom illustration instead of the SF Symbol badge. Pass any `Image`
    /// (asset, rendered illustration, etc.). (Reference EmptyCardView parity.)
    public init(
        image: Image,
        imageMaxHeight: CGFloat = 160,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = "tray"
        self.image = image
        self.animatedURL = nil
        self.imageMaxHeight = imageMaxHeight
        self.iconForeground = nil
        self.iconBackground = nil
        self.iconCircleSize = 88
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    /// Animated illustration (GIF / APNG) via the native `AnimatedImage` — the
    /// dependency-free stand-in for the reference's Lottie `.media` empty state.
    public init(
        animatedURL: URL?,
        imageMaxHeight: CGFloat = 160,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.systemImage = "tray"
        self.image = nil
        self.animatedURL = animatedURL
        self.imageMaxHeight = imageMaxHeight
        self.iconForeground = nil
        self.iconBackground = nil
        self.iconCircleSize = 88
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            if let animatedURL {
                AnimatedImage(animatedURL, contentMode: .fit)
                    .frame(maxHeight: imageMaxHeight)
            } else if let image {
                image
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: imageMaxHeight)
            } else {
                ZStack {
                    Circle()
                        .fill(iconBackground ?? Theme.shared.background(.bgElevatorTertiary))
                        .frame(width: iconCircleSize, height: iconCircleSize)
                    Image(systemName: systemImage)
                        .font(.system(size: iconCircleSize * 0.36))
                        .foregroundStyle(iconForeground ?? Theme.shared.foreground(.fgHero))
                }
            }

            VStack(spacing: Theme.SpacingKey.sm.value) {
                if let title {
                    Text(title)
                        .textStyle(.headingBase)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                        .multilineTextAlignment(.center)
                }
                if let message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            if let buttonTitle, let action {
                PrimaryButton(buttonTitle, action: action)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EmptyState(
        systemImage: "magnifyingglass",
        title: "No results found",
        message: "Try adjusting your search or filters to find what you're looking for.",
        buttonTitle: "Clear filters",
        action: {}
    )
    .padding()
}
