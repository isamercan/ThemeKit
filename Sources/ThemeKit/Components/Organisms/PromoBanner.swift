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

    // Appearance/content — mutated only through the modifiers below (R2).
    private var subtitle: String?
    private var systemImage: String?
    private var ctaTitle: String?
    private var tint: PromoBannerTint = .blue

    private let title: String
    private let action: (() -> Void)?

    public init(_ title: String, action: (() -> Void)? = nil) {   // R1 — content + primary action
        self.title = title
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

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension PromoBanner {
    /// Secondary line under the title.
    func subtitle(_ s: String?) -> Self { copy { $0.subtitle = s } }

    /// Leading SF Symbol visual.
    func icon(_ systemImage: String?) -> Self { copy { $0.systemImage = systemImage } }

    /// Trailing call-to-action button title (renders only when paired with the init `action`).
    func ctaTitle(_ title: String?) -> Self { copy { $0.ctaTitle = title } }

    /// Banner tint treatment: blue / dark / turquoise (R4 token-bound).
    /// Standard accent vocabulary (flexibility audit §6). No `SemanticColor`
    /// overload: `PromoBannerTint` is already token-bound and a second `.turquoise`
    /// case would make call sites ambiguous.
    func accent(_ tint: PromoBannerTint) -> Self { copy { $0.tint = tint } }

    /// Banner tint treatment: blue / dark / turquoise.
    @available(*, deprecated, message: "Use accent(_:).")
    func color(_ tint: PromoBannerTint) -> Self { accent(tint) }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        PromoBanner("Early booking", action: {})
            .subtitle("Save up to 30% on summer").icon("sun.max.fill").ctaTitle("Explore")
        PromoBanner("Plus", action: {})
            .subtitle("Members get exclusive deals").icon("star.circle.fill").ctaTitle("Join").accent(.dark)
    }
    .padding()
}
