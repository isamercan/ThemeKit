//
//  PromoBanner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum PromoBannerTint {
    case blue, dark, turquoise

    func background(_ theme: Theme) -> Color {
        switch self {
        case .blue: return theme.background(.bgElevatorTertiary)
        case .dark: return theme.background(.bgTertiary)
        case .turquoise: return theme.background(.bgTurquoiseLight)
        }
    }
    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .blue, .turquoise: return theme.text(.textPrimary)
        case .dark: return theme.foreground(.fgSecondary)
        }
    }
    func secondaryForeground(_ theme: Theme) -> Color {
        switch self {
        case .blue, .turquoise: return theme.text(.textSecondary)
        case .dark: return theme.text(.textSecondaryInverse)
        }
    }
}

/// Organism. A promotional banner (campaign / offer). Distinct from InfoBanner
/// (status). Leading visual + title + subtitle + optional CTA, on a tinted card.
public struct PromoBanner: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let subtitle: String?
    private let systemImage: String?
    private let ctaTitle: String?
    private let tint: PromoBannerTint
    private let action: (() -> Void)?

    public init(
        title: String,
        subtitle: String? = nil,
        systemImage: String? = nil,
        ctaTitle: String? = nil,
        tint: PromoBannerTint = .blue,
        action: (() -> Void)? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self.systemImage = systemImage
        self.ctaTitle = ctaTitle
        self.tint = tint
        self.action = action
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.md.value) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.system(size: 28))
                    .foregroundStyle(tint.foreground(theme))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .textStyle(.labelMd700)
                    .foregroundStyle(tint.foreground(theme))
                if let subtitle {
                    Text(subtitle)
                        .textStyle(.bodySm400)
                        .foregroundStyle(tint.secondaryForeground(theme))
                }
            }
            Spacer(minLength: Theme.SpacingKey.sm.value)
            if let ctaTitle, let action {
                Button(action: action) {
                    Text(ctaTitle)
                        .textStyle(.labelSm700)
                        .foregroundStyle(theme.foreground(.fgSecondary))
                        .padding(.horizontal, Theme.SpacingKey.md.value)
                        .frame(height: 36)
                        .background(theme.background(.bgHero), in: Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.background(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        PromoBanner(title: "Early booking", subtitle: "Save up to 30% on summer", systemImage: "sun.max.fill", ctaTitle: "Explore", action: {})
        PromoBanner(title: "Plus", subtitle: "Members get exclusive deals", systemImage: "star.circle.fill", ctaTitle: "Join", tint: .dark, action: {})
    }
    .padding()
}
