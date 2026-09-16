//
//  Callout.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum CalloutType {
    case neutral, info, success, warning, error
    /// Brand-primary emphasis (HeroUI Alert `accent` status).
    case accent

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
    func soft(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgBase)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        case .accent: return theme.resolve(.primary).soft
        }
    }
    var systemImage: String {
        switch self {
        case .neutral, .info, .accent: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
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
}

public enum CalloutStyle {
    case plain   // transparent, colored icon + text
    case soft    // light tinted surface
}

/// Organism. Inline status text with a leading icon. More compact than
/// InfoBanner — used to highlight a single line of information.
/// Figma: success / error / info / warning / neutral; plain or soft style.
///
/// The chrome is drawn by the active ``CalloutChromeStyle`` when one is set
/// with `.calloutChromeStyle(_:)` on the callout or an ancestor; the callout
/// keeps its content, wired buttons, link routing and status label either way.
public struct Callout: View {
    @Environment(\.theme) private var theme
    @Environment(\.calloutChromeStyle) private var chromeStyle
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.openURL) private var surroundingOpenURL

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var type: CalloutType = .info
    private var style: CalloutStyle = .plain
    private var showIcon = true
    private var iconOverride: String?
    private var leadingView: AnyView?
    private var trailingView: AnyView?
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var onClose: (() -> Void)?
    private var alignment: VerticalAlignment = .firstTextBaseline
    private var isFullWidth = false
    private var statusLabel: String?

    private let text: String
    private var links: [(substring: String, action: () -> Void)] = []

    public init(_ text: String) {   // R1
        self.text = text
    }

    private var hasAction: Bool { actionTitle != nil && onAction != nil }
    private var hasTrailing: Bool { hasAction || onClose != nil || trailingView != nil }

    public var body: some View {
        if chromeStyle.isDefault {
            HStack(alignment: alignment, spacing: Theme.SpacingKey.xs.value) {
                // Leading indicator: a custom view replaces the stock status icon
                // entirely (the InfoBanner slot pair, D3); otherwise the glyph,
                // optionally overridden per-instance via `icon(_:)`.
                if let leadingView {
                    labelledLeading(leadingView)
                } else if showIcon {
                    stockIcon
                }
                Group {
                    if links.isEmpty {
                        Text(text).textStyle(.bodySm400)
                    } else {
                        // InlineText paints its own base colour; hand it the tone
                        // so linked text matches plain text.
                        InlineText(text, links: links).inlineStyle(.bodySm400).baseColorOverride(type.accent(theme))
                    }
                }
                if hasTrailing {
                    Spacer(minLength: Theme.SpacingKey.sm.value)
                    if let trailingView {
                        trailingView
                    }
                    if hasAction {
                        stockActionButton
                    }
                    if onClose != nil {
                        stockCloseButton
                    }
                }
            }
            .modifier(CalloutWidth(isFullWidth: isFullWidth))
            .foregroundStyle(type.accent(theme))
            .padding(.horizontal, style == .soft ? Theme.SpacingKey.sm.value : 0)
            .padding(.vertical, style == .soft ? Theme.SpacingKey.xs.value : 0)
            .background {
                if style == .soft {
                    RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous).fill(type.soft(theme))
                }
            }
        } else {
            // The style draws; the callout keeps routing its link taps, and any
            // other URL opened in the style's body goes to the surrounding action.
            chromeStyle.makeBody(configuration: configuration)
                .environment(\.openURL, InlineText.linkRouting(links, fallback: surroundingOpenURL))
        }
    }

    // MARK: Stock pieces (shared by the default chrome and the configuration)

    private var stockIcon: some View {
        Image(systemName: iconOverride ?? type.systemImage)
            .font(.system(size: 14))
            .accessibilityLabel(statusLabel ?? type.accessibilityLabel)
    }

    /// A custom leading view keeps its own accessibility unless a status label
    /// was set, which then names it.
    @ViewBuilder private func labelledLeading(_ leading: AnyView) -> some View {
        if let statusLabel {
            leading
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(statusLabel)
        } else {
            leading
        }
    }

    @ViewBuilder private var stockActionButton: some View {
        if let actionTitle, let onAction {
            Button(action: onAction) {
                Text(actionTitle).textStyle(.labelSm600)
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder private var stockCloseButton: some View {
        if let onClose {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(themeKit: "Dismiss"))
        }
    }

    // MARK: Style path

    private var configuration: CalloutChromeStyleConfiguration {
        let usesStockIcon = leadingView == nil && showIcon
        let unpainted = unpaintedText
        return CalloutChromeStyleConfiguration(
            text: text,
            links: links,
            // No font and no colour of its own; link runs marked (the style
            // path's routing resolves their taps).
            content: links.isEmpty ? AnyView(Text(text)) : AnyView(Text(unpainted)),
            attributedText: unpainted,
            leading: leadingView.map { AnyView(labelledLeading($0)) } ?? (usesStockIcon ? AnyView(stockIcon) : nil),
            leadingSystemImage: usesStockIcon ? (iconOverride ?? type.systemImage) : nil,
            trailing: trailingView,
            actionButton: hasAction ? AnyView(stockActionButton) : nil,
            closeButton: onClose == nil ? nil : AnyView(stockCloseButton),
            actionTitle: hasAction ? actionTitle : nil,
            onAction: hasAction ? onAction : nil,
            onClose: onClose,
            tone: type,
            calloutStyle: style,
            showsIcon: showIcon,
            statusLabel: statusLabel ?? (usesStockIcon ? type.accessibilityLabel : nil),
            alignment: alignment,
            isFullWidth: isFullWidth,
            isEnabled: isEnabled)
    }

    /// The text as unpainted runs, link runs marked — `InlineText`'s own shape.
    private var unpaintedText: AttributedString {
        InlineText.attributedString(text, links: links, font: nil, baseColor: nil, linkColor: theme.text(.textHero))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Callout {
    /// Semantic status: neutral / info / success / warning / error / accent (drives accent + icon).
    func variant(_ t: CalloutType) -> Self { copy { $0.type = t } }

    /// Turn substrings of the body into inline tappable links (rendered via
    /// `InlineText`) — API symmetry with `InfoBanner`, which already supports it.
    /// The text keeps the variant's accent colour; the links take the link colour.
    func links(_ links: [(substring: String, action: () -> Void)]) -> Self { copy { $0.links = links } }

    /// Surface treatment: plain (transparent) or soft (light tinted surface).
    func calloutStyle(_ s: CalloutStyle) -> Self { copy { $0.style = s } }

    /// Show or hide the leading status icon.
    func showsIcon(_ on: Bool = true) -> Self { copy { $0.showIcon = on } }

    /// Override the leading status glyph (otherwise derived from the variant);
    /// `nil` restores the variant's default.
    func icon(_ systemName: String?) -> Self { copy { $0.iconOverride = systemName } }

    /// Replace the stock status icon with a custom leading view — e.g. a
    /// `Spinner` for an in-progress note (mirrors `InfoBanner.leading`, D3).
    /// Wins over `icon(_:)` and `showsIcon(_:)`; inherits the variant's accent
    /// foreground, so plain glyphs tint correctly with zero configuration.
    /// Pair it with `statusLabel(_:)` so VoiceOver still reads the status.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.leadingView = AnyView(content()) }
    }

    /// Custom trailing accessory rendered before the text-link action and the
    /// dismiss button — e.g. a `Badge` or a small `ThemeButton` (mirrors
    /// `InfoBanner.trailing`, D3).
    func trailing<V: View>(@ViewBuilder _ content: () -> V) -> Self {
        copy { $0.trailingView = AnyView(content()) }
    }

    /// Trailing inline action button (title + handler).
    func action(_ title: String, onAction: @escaping () -> Void) -> Self {
        copy { $0.actionTitle = title; $0.onAction = onAction }
    }

    /// Trailing dismiss (×) button handler.
    func onClose(_ action: (() -> Void)?) -> Self { copy { $0.onClose = action } }

    /// Vertical alignment of the icon, text and trailing accessories —
    /// `.firstTextBaseline` by default; `.center` centres a larger icon or a
    /// button against the text.
    func alignment(_ a: VerticalAlignment) -> Self { copy { $0.alignment = a } }

    /// Stretch the callout to the offered width, keeping its surface, with the
    /// content leading-aligned. Off by default: the callout hugs its content
    /// unless a trailing accessory pushes it wide.
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.isFullWidth = on } }

    /// What VoiceOver reads for the leading indicator, before the text. By
    /// default the stock icon reads the variant's status ("Warning") and a
    /// custom `leading { }` view keeps its own label; set this to name either
    /// (a custom view is then read as one element with this label). `nil`
    /// restores the default. With no indicator shown there is nothing to name.
    func statusLabel(_ label: String?) -> Self { copy { $0.statusLabel = label } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Callout") {
        PreviewCase("Success") { Callout("Lorem ipsum placeholder text.").variant(.success) }
        PreviewCase("Error") { Callout("Lorem ipsum placeholder text.").variant(.error) }
        PreviewCase("Info") { Callout("Lorem ipsum placeholder text.").variant(.info) }
        PreviewCase("Warning soft") { Callout("Lorem ipsum placeholder text.").variant(.warning).calloutStyle(.soft) }
        PreviewCase("Neutral soft") { Callout("Lorem ipsum placeholder text.").variant(.neutral).calloutStyle(.soft) }
        PreviewCase("Accent soft") { Callout("Brand-primary emphasis.").variant(.accent).calloutStyle(.soft) }
        PreviewCase("Icon override") { Callout("Custom glyph via icon override.").variant(.info).icon("bell.badge") }
        PreviewCase("Links keep the tone") {
            Callout("Check the fare rules before booking.").variant(.warning).links([("fare rules", {})])
        }
        // D3 — slot pair mirroring InfoBanner.
        PreviewCase("Leading slot") {
            Callout("Checking availability…").variant(.accent).calloutStyle(.soft)
                .leading { Spinner().size(14).lineWidth(2).accent(.primary) }
                .statusLabel("Loading")
        }
        PreviewCase("Trailing slot + close") {
            Callout("Fare updated a moment ago.").variant(.info).calloutStyle(.soft)
                .trailing { Badge("New").badgeStyle(.info).size(.small) }
                .onClose {}
        }
        PreviewCase("Centred, full width") {
            Callout("Seats are filling up.").variant(.warning).calloutStyle(.soft)
                .leading { Image(systemName: "flame").font(.system(size: 20)) }
                .statusLabel("Warning")
                .alignment(.center)
                .fullWidth()
        }
        PreviewCase("Custom chrome style") {
            Callout("Prices may change until you book.").variant(.warning)
                .action("Details") {}
                .fullWidth()
                .calloutChromeStyle(PreviewCalloutChrome())
        }
    }
}

/// A preview-only custom chrome: centred row, primary body text on the tone's
/// light surface, a 1pt tone stroke, and the action in the tone colour.
private struct PreviewCalloutChrome: CalloutChromeStyle {
    func makeBody(configuration: CalloutChromeStyleConfiguration) -> some View {
        PreviewCalloutChromeBody(configuration: configuration)
    }
}

private struct PreviewCalloutChromeBody: View {
    let configuration: CalloutChromeStyleConfiguration
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(alignment: .center, spacing: Theme.SpacingKey.sm.value) {
            if let symbol = configuration.leadingSystemImage {
                Image(systemName: symbol)
                    .font(.system(size: 18))
                    .accessibilityLabel(configuration.statusLabel ?? "")
            } else {
                configuration.leading
            }
            configuration.content
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .frame(maxWidth: configuration.isFullWidth ? .infinity : nil, alignment: .leading)
            configuration.trailing
            if let title = configuration.actionTitle, let onAction = configuration.onAction {
                Button(title, action: onAction)
                    .buttonStyle(.plain)
                    .font(TextStyle.linkSm.font)
                    .frame(minHeight: 44)
            }
            configuration.closeButton
        }
        .foregroundStyle(configuration.tone.accent(theme))
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .padding(.vertical, Theme.SpacingKey.sm.value)
        .background(configuration.tone.soft(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .strokeBorder(configuration.tone.accent(theme), lineWidth: 1)
        )
    }
}
