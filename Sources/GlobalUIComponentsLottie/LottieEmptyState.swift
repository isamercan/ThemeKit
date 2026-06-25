//
//  LottieEmptyState.swift
//  GlobalUIComponentsLottie
//  Created by İsa Mercan on 23.06.2026.
//
//  An empty-state with a Lottie illustration — the vector-animation counterpart
//  of the core `EmptyState` (which natively supports SF Symbols, custom images,
//  and GIF/APNG via `AnimatedImage`). Reuses the core's `Theme` / `TextStyle` /
//  `PrimaryButton` so it matches the design system exactly; the core itself stays
//  free of any Lottie dependency. Accepts a bundled or remote animation.
//

import SwiftUI
import GlobalUIComponents

public struct LottieEmptyState: View {
    private let illustration: LottieIllustration
    private let animationHeight: CGFloat
    private let title: String?
    private let message: String?
    private let buttonTitle: String?
    private let action: (() -> Void)?

    /// Empty state with a pre-built Lottie illustration (bundled or remote).
    public init(
        illustration: LottieIllustration,
        animationHeight: CGFloat = 160,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.illustration = illustration
        self.animationHeight = animationHeight
        self.title = title
        self.message = message
        self.buttonTitle = buttonTitle
        self.action = action
    }

    /// Empty state with a bundled `<name>.json` animation.
    public init(
        animationName: String,
        bundle: Bundle = .main,
        loop: Bool = true,
        animationHeight: CGFloat = 160,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(illustration: LottieIllustration(animationName, bundle: bundle, loop: loop),
                  animationHeight: animationHeight, title: title, message: message,
                  buttonTitle: buttonTitle, action: action)
    }

    /// Empty state with a remote JSON animation loaded from `url`.
    public init(
        animationURL: URL,
        loop: Bool = true,
        animationHeight: CGFloat = 160,
        title: String? = nil,
        message: String? = nil,
        buttonTitle: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.init(illustration: LottieIllustration(url: animationURL, loop: loop),
                  animationHeight: animationHeight, title: title, message: message,
                  buttonTitle: buttonTitle, action: action)
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            illustration
                .frame(maxHeight: animationHeight)

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
