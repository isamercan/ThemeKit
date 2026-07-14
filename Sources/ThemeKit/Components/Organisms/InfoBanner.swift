//
//  InfoBanner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum InfoBannerType {
    case neutral, info, success, warning, error
    /// Brand-primary emphasis (HeroUI Alert `accent` status).
    case accent

    func background(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgBase)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        case .accent: return theme.resolve(.primary).soft
        }
    }

    func accent(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.text(.textSecondary)
        case .info: return theme.foreground(.systemcolorsFgInfo)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error: return theme.foreground(.systemcolorsFgError)
        case .accent: return theme.resolve(.primary).base
        }
    }

    func border(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.border(.borderPrimary)
        case .info: return theme.border(.systemcolorsBorderInfoLight)
        case .success: return theme.border(.systemcolorsBorderSuccessLight)
        case .warning: return theme.border(.systemcolorsBorderWarningLight)
        case .error: return theme.border(.systemcolorsBorderErrorLight)
        case .accent: return theme.resolve(.primary).border
        }
    }

    var systemImage: String {
        switch self {
        case .neutral, .info, .accent: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.octagon.fill"
        }
    }

    /// VoiceOver name for the stock status icon — the status itself, localized.
    var accessibilityLabel: String {
        switch self {
        case .neutral: return String(themeKit: "Note")
        case .info, .accent: return String(themeKit: "Information")
        case .success: return String(themeKit: "Success")
        case .warning: return String(themeKit: "Warning")
        case .error: return String(themeKit: "Error")
        }
    }

    /// The banner's status mapped to a `SemanticColor` — used to tint a
    /// first-class trailing action button so it matches the alert by default.
    var semanticColor: SemanticColor {
        switch self {
        case .neutral: return .neutral
        case .info: return .info
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        case .accent: return .primary
        }
    }
}

/// A first-class trailing action button for an `InfoBanner` / alert — a real
/// `ThemeButton` (label + variant + optional semantic color) whose tap handler
/// is captured as a stored closure. Mirrors HeroUI Native's trailing
/// `<Button variant onPress>`; richer than the lightweight text-link
/// `action(_:onAction:)`.
public struct AlertAction {
    public let title: String
    public let variant: ButtonVariant
    public let color: SemanticColor?
    public let size: ButtonSize
    public let handler: () -> Void

    /// - Parameters:
    ///   - title: Button label.
    ///   - variant: `ThemeButton` variant (default `.soft`).
    ///   - color: Semantic color; `nil` inherits the banner's status color.
    ///   - size: `ThemeButton` size (default `.small`, matching HeroUI `sm`).
    ///   - handler: Captured tap closure.
    public init(
        _ title: String,
        variant: ButtonVariant = .soft,
        color: SemanticColor? = nil,
        size: ButtonSize = .small,
        handler: @escaping () -> Void
    ) {
        self.title = title
        self.variant = variant
        self.color = color
        self.size = size
        self.handler = handler
    }
}

/// Improved, token-bound rewrite of the reference InfoMessage. Semantic types
/// drive a light-surface banner with a colored icon, optional title and an
/// optional dismiss action.
public struct InfoBanner: View {
    @Environment(\.theme) private var theme

    // Appearance/state — mutated only through the modifiers below (R2).
    private var type: InfoBannerType = .info
    private var showIcon = true
    private var banner = false
    private var iconOverride: String?
    private var leadingView: AnyView?
    private var trailingView: AnyView?
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var actionButton: AlertAction?
    private var onDismiss: (() -> Void)?

    private let message: String
    private let title: String?
    private let links: [(substring: String, action: () -> Void)]

    public init(
        _ message: String,
        title: String? = nil,
        links: [(substring: String, action: () -> Void)] = []
    ) {   // R1 — content + content/data
        self.message = message
        self.title = title
        self.links = links
    }

    private var radius: CGFloat { banner ? 0 : Theme.RadiusKey.md.value }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            // Leading indicator: a custom view replaces the stock icon entirely
            // (HeroUI Alert.Indicator children); otherwise the status glyph,
            // optionally overridden per-instance via `icon(_:)`.
            if let leadingView {
                leadingView
            } else if showIcon {
                Icon(systemName: iconOverride ?? type.systemImage)
                    .size(.sm)
                    .colorOverride(type.accent(theme))
                    .accessibilityLabel(type.accessibilityLabel)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                if links.isEmpty {
                    Text(message)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                } else {
                    InlineText(message, links: links).color(theme.text(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Custom trailing accessory (e.g. a small ThemeButton) — the fully
            // open escape hatch, richer than the options below.
            if let trailingView {
                trailingView
            }

            // First-class action button wins over the lightweight text-link;
            // its color defaults to the banner's status when unspecified.
            if let actionButton {
                ThemeButton(actionButton.title, action: actionButton.handler)
                    .variant(actionButton.variant)
                    .color(actionButton.color ?? type.semanticColor)
                    .size(actionButton.size)
            } else if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle).textStyle(.labelSm600).foregroundStyle(type.accent(theme))
                }
                .buttonStyle(.plain)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Icon(systemName: "xmark").size(.xs).color(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: banner ? .infinity : nil, alignment: .leading)
        .background(type.background(theme), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(type.border(theme), lineWidth: banner ? 0 : 1)
        )
        // One VoiceOver element: "<status>, <title>, <message>"; child button
        // actions surface as custom accessibility actions.
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    PreviewMatrix("InfoBanner") {
        PreviewCase("Info · title") {
            InfoBanner("This is an informational message.", title: "Heads up").variant(.info)
        }
        PreviewCase("Success") { InfoBanner("Your changes were saved.").variant(.success) }
        PreviewCase("Warning") { InfoBanner("Please double-check this field.").variant(.warning) }
        PreviewCase("Error · dismissible") { InfoBanner("Something went wrong.").variant(.error).onDismiss {} }
        PreviewCase("Neutral") { InfoBanner("A neutral note.").variant(.neutral) }
        PreviewCase("Accent") { InfoBanner("Brand-primary emphasis.", title: "New feature").variant(.accent) }
        PreviewCase("Icon override") { InfoBanner("Custom glyph via icon override.").variant(.info).icon("bell.badge") }
        PreviewCase("Leading spinner") {
            InfoBanner("Uploading your document…", title: "Processing")
                .variant(.accent)
                .leading { Spinner().size(IconSize.sm.value).lineWidth(2).accent(.primary) }
        }
        PreviewCase("Trailing action") {
            InfoBanner("A new version is available.", title: "Update")
                .variant(.info)
                .trailing { ThemeButton("Install") {}.size(.small).color(.info) }
        }
        // First-class action button — captured closure, HeroUI Alert parity.
        PreviewCase("Action button") {
            InfoBanner("A new version of the app is available.", title: "Update available")
                .variant(.accent)
                .actionButton(AlertAction("Refresh", variant: .solid) {})
        }
        PreviewCase("Action button · retry") {
            InfoBanner("Check your internet connection and try again.", title: "Unable to connect")
                .variant(.error)
                .actionButton(AlertAction("Retry") {})
        }
        PreviewCase("Full-width banner") {
            InfoBanner("Scheduled maintenance tonight.").variant(.warning).fullWidth()
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InfoBanner {
    /// Semantic type: neutral / info / success / warning / error / accent —
    /// drives the surface, accent, border and leading icon.
    func variant(_ t: InfoBannerType) -> Self { copy { $0.type = t } }

    /// Show or hide the type's leading icon.
    func showsIcon(_ on: Bool = true) -> Self { copy { $0.showIcon = on } }

    /// Override the leading status glyph (otherwise derived from the variant);
    /// `nil` restores the variant's default.
    func icon(_ systemName: String?) -> Self { copy { $0.iconOverride = systemName } }

    /// Replace the stock status icon with a custom leading view — e.g. a
    /// `Spinner` for an in-progress alert (HeroUI `Alert.Indicator` children).
    /// Wins over `icon(_:)` and `showsIcon(_:)`.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingView = AnyView(content()) }
    }

    /// Custom trailing accessory rendered after the text block — e.g. a small
    /// `ThemeButton`. The lightweight `action(_:onAction:)` text link stays the
    /// default for simple cases.
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingView = AnyView(content()) }
    }

    /// Edge-to-edge banner treatment: stretch to full width and drop the
    /// rounded corners / border (Ant Alert `banner`).
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.banner = on } }

    /// Trailing inline action as a lightweight text link: its label + handler.
    func action(_ title: String?, onAction: (() -> Void)? = nil) -> Self {
        copy { $0.actionTitle = title; $0.onAction = onAction }
    }

    /// A first-class trailing action button (real `ThemeButton`) whose tap
    /// handler is captured on the `AlertAction`. Matches HeroUI Native's
    /// trailing `<Button variant onPress>`; wins over the text-link
    /// `action(_:onAction:)`.
    func actionButton(_ action: AlertAction?) -> Self { copy { $0.actionButton = action } }

    /// Trailing dismiss (×) button handler.
    func onDismiss(_ handler: (() -> Void)?) -> Self { copy { $0.onDismiss = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
