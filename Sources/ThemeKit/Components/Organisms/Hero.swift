//
//  Hero.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A prominent hero section: centered title + subtitle + optional CTA
/// over a color or custom background. (daisyUI "Hero".)
public struct Hero<Background: View>: View {
    @Environment(\.theme) private var theme

    private let title: String
    // Takes the resolved `dark` flag so the default `HeroSurface` (set via the
    // `where Background == HeroSurface` init below) tracks the `.dark()` modifier;
    // custom backgrounds ignore it.
    private let background: (_ dark: Bool) -> Background

    // Appearance/config — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var ctaTitle: String?
    private var dark = false
    private var action: (() -> Void)?

    public init(title: String, @ViewBuilder background: @escaping () -> Background) {   // R1
        self.title = title
        self.background = { _ in background() }
    }

    public var body: some View {
        ZStack {
            background(dark)
            if dark {
                theme.background(.bgTertiary).opacity(0.45)
            }
            VStack(spacing: Theme.SpacingKey.md.value) {
                Text(title)
                    .textStyle(.displaySm)
                    .foregroundStyle(titleColor)
                    .multilineTextAlignment(.center)
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodyMd400)
                        .foregroundStyle(subtitleColor)
                        .multilineTextAlignment(.center)
                }
                if let ctaTitle, let action {
                    PrimaryButton(ctaTitle, action: action)
                        .padding(.top, Theme.SpacingKey.xs.value)
                }
            }
            .padding(Theme.SpacingKey.xl.value)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
        .clipShape(RoundedRectangle(cornerRadius: Theme.RadiusKey.lg.value, style: .continuous))
    }

    private var titleColor: Color { dark ? theme.foreground(.fgSecondary) : theme.text(.textPrimary) }
    private var subtitleColor: Color { dark ? theme.text(.textSecondaryInverse) : theme.text(.textSecondary) }
}

/// The default `Hero` surface. A `View` (not a bare `Color`) so it can resolve the
/// injected `\.theme` — that's why the convenience `Hero(title:)` below defaults
/// `Background` to this type instead of `Color`.
public struct HeroSurface: View {
    let dark: Bool
    @Environment(\.theme) private var theme

    public var body: some View {
        dark ? theme.background(.bgTertiary) : theme.background(.bgElevatorTertiary)
    }
}

public extension Hero where Background == HeroSurface {
    init(title: String) {   // R1 — default themed surface
        self.title = title
        self.background = { HeroSurface(dark: $0) }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Hero {
    /// Supporting text under the title.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Call-to-action button — renders when both title and action are set.
    func cta(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.ctaTitle = title; $0.action = action }
    }

    /// Dark treatment: scrim overlay + inverted text (also darkens the default surface).
    func dark(_ on: Bool = true) -> Self { copy { $0.dark = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Hero") {
        PreviewCase("Default surface · CTA") {
            Hero(title: "Discover Istanbul")
                .subtitle("Hand-picked stays at the best prices.")
                .cta("Explore", action: {})
        }
        PreviewCase("Dark treatment (scrim + inverted text)") {
            Hero(title: "Summer Sale")
                .subtitle("Up to 30% off")
                .cta("Shop now", action: {})
                .dark()
        }
    }
}
