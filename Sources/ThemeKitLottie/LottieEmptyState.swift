//
//  LottieEmptyState.swift
//  ThemeKitLottie
//  Created by İsa Mercan on 23.06.2026.
//
//  An empty-state with a Lottie illustration — the vector-animation counterpart
//  of the core `EmptyState` (which natively supports SF Symbols, custom images,
//  and GIF/APNG via `AnimatedImage`). Reuses the core's `Theme` / `TextStyle` /
//  `PrimaryButton` so it matches the design system exactly; the core itself stays
//  free of any Lottie dependency. Accepts a bundled or remote animation.
//

// Guarded on the "Lottie" package trait (see LottieIllustration.swift): compiles
// to nothing when lottie-ios is not resolved, keeping the core dependency-free.
#if canImport(Lottie)
import SwiftUI
import ThemeKit

/// Per the modifier-based architecture (COMPONENT_REFACTOR_RULES R1–R7) the init
/// takes only the media source and `title`; message, playback, sizing and the
/// call-to-action are chainable, order-free modifiers (mirrors `EmptyState`).
///
///     LottieEmptyState(animationName: "empty-box", title: "No results found")
///         .message("Try adjusting your search or filters.")
///         .primaryAction("Clear filters") { reset() }
public struct LottieEmptyState: View {
    private enum Media {
        case illustration(LottieIllustration)
        case named(String, Bundle)
        case url(URL)
    }

    private let media: Media
    private let title: String?

    // Appearance/content/actions — mutated only through the modifiers below (R2).
    private var loop = true
    private var animationHeight: CGFloat = 160
    private var message: String?
    private var buttonTitle: String?
    private var action: (() -> Void)?

    /// Empty state with a pre-built Lottie illustration (bundled or remote).
    public init(illustration: LottieIllustration, title: String? = nil) {   // R1
        self.media = .illustration(illustration)
        self.title = title
    }

    /// Empty state with a bundled `<name>.json` animation.
    public init(animationName: String, bundle: Bundle = .main, title: String? = nil) {   // R1
        self.media = .named(animationName, bundle)
        self.title = title
    }

    /// Empty state with a remote JSON animation loaded from `url`.
    public init(animationURL: URL, title: String? = nil) {   // R1
        self.media = .url(animationURL)
        self.title = title
    }

    // The pre-built variant plays as configured by the caller; the name/URL
    // variants apply this component's `loop` setting (default: looping).
    private var illustration: LottieIllustration {
        switch media {
        case .illustration(let illustration):
            return illustration
        case .named(let name, let bundle):
            return LottieIllustration(name, bundle: bundle).loop(loop)
        case .url(let url):
            return LottieIllustration(url: url).loop(loop)
        }
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension LottieEmptyState {
    /// Loop the animation forever (default); pass `false` to play it once (name/URL variants).
    func loop(_ on: Bool = true) -> Self { copy { $0.loop = on } }

    /// Max height of the Lottie illustration.
    func animationHeight(_ height: CGFloat) -> Self { copy { $0.animationHeight = height } }

    /// Secondary message under the title.
    func message(_ text: String?) -> Self { copy { $0.message = text } }

    /// Primary call-to-action button (title + handler).
    func primaryAction(_ title: String?, action: (() -> Void)?) -> Self {
        copy { $0.buttonTitle = title; $0.action = action }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
#endif
