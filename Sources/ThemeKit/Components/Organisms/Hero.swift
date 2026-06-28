//
//  Hero.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A prominent hero section: centered title + subtitle + optional CTA
/// over a color or custom background. (daisyUI "Hero".)
public struct Hero<Background: View>: View {
    private let title: String
    private let subtitle: String?
    private let ctaTitle: String?
    private let dark: Bool
    private let action: (() -> Void)?
    private let background: () -> Background

    public init(
        title: String,
        subtitle: String? = nil,
        ctaTitle: String? = nil,
        dark: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder background: @escaping () -> Background
    ) {
        self.title = title
        self.subtitle = subtitle
        self.ctaTitle = ctaTitle
        self.dark = dark
        self.action = action
        self.background = background
    }

    public var body: some View {
        ZStack {
            background()
            if dark {
                Theme.shared.background(.bgTertiary).opacity(0.45)
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

    private var titleColor: Color { dark ? Theme.shared.foreground(.fgSecondary) : Theme.shared.text(.textPrimary) }
    private var subtitleColor: Color { dark ? Theme.shared.text(.textSecondaryInverse) : Theme.shared.text(.textSecondary) }
}

public extension Hero where Background == Color {
    init(title: String, subtitle: String? = nil, ctaTitle: String? = nil, dark: Bool = false, action: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, ctaTitle: ctaTitle, dark: dark, action: action) {
            dark ? Theme.shared.background(.bgTertiary) : Theme.shared.background(.bgElevatorTertiary)
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        Hero(title: "Discover İstanbul", subtitle: "Hand-picked stays at the best prices.", ctaTitle: "Explore", action: {})
        Hero(title: "Summer Sale", subtitle: "Up to 30% off", ctaTitle: "Shop now", dark: true, action: {})
    }
    .padding()
}
