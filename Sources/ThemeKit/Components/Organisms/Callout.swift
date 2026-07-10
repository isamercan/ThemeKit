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
        case .accent: return SemanticColor.primary.base
        }
    }
    func soft(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgBase)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        case .accent: return SemanticColor.primary.soft
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
public struct Callout: View {
    @Environment(\.theme) private var theme

    // Appearance/content/state — mutated only through the modifiers below (R2).
    private var type: CalloutType = .info
    private var style: CalloutStyle = .plain
    private var showIcon = true
    private var iconOverride: String?
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var onClose: (() -> Void)?

    private let text: String
    private var links: [(substring: String, action: () -> Void)] = []

    public init(_ text: String) {   // R1
        self.text = text
    }

    private var hasAction: Bool { actionTitle != nil && onAction != nil }
    private var hasTrailing: Bool { hasAction || onClose != nil }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            if showIcon {
                Image(systemName: iconOverride ?? type.systemImage)
                    .font(.system(size: 14))
                    .accessibilityLabel(type.accessibilityLabel)
            }
            Group {
                if links.isEmpty {
                    Text(text).textStyle(.bodySm400)
                } else {
                    InlineText(text, links: links).inlineStyle(.bodySm400)
                }
            }
            if hasTrailing {
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let actionTitle, let onAction {
                    Button(action: onAction) {
                        Text(actionTitle).textStyle(.labelSm600)
                    }
                    .buttonStyle(.plain)
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(themeKit: "Dismiss"))
                }
            }
        }
        .foregroundStyle(type.accent(theme))
        .padding(.horizontal, style == .soft ? Theme.SpacingKey.sm.value : 0)
        .padding(.vertical, style == .soft ? Theme.SpacingKey.xs.value : 0)
        .background {
            if style == .soft {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous).fill(type.soft(theme))
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Callout {
    /// Semantic status: neutral / info / success / warning / error / accent (drives accent + icon).
    func variant(_ t: CalloutType) -> Self { copy { $0.type = t } }

    /// Turn substrings of the body into inline tappable links (rendered via
    /// `InlineText`) — API symmetry with `InfoBanner`, which already supports it.
    func links(_ links: [(substring: String, action: () -> Void)]) -> Self { copy { $0.links = links } }

    /// Surface treatment: plain (transparent) or soft (light tinted surface).
    func calloutStyle(_ s: CalloutStyle) -> Self { copy { $0.style = s } }

    /// Show or hide the leading status icon.
    func showsIcon(_ on: Bool = true) -> Self { copy { $0.showIcon = on } }

    /// Override the leading status glyph (otherwise derived from the variant);
    /// `nil` restores the variant's default.
    func icon(_ systemName: String?) -> Self { copy { $0.iconOverride = systemName } }

    /// Trailing inline action button (title + handler).
    func action(_ title: String, onAction: @escaping () -> Void) -> Self {
        copy { $0.actionTitle = title; $0.onAction = onAction }
    }

    /// Trailing dismiss (×) button handler.
    func onClose(_ action: (() -> Void)?) -> Self { copy { $0.onClose = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Callout("Lorem ipsum placeholder text.").variant(.success)
        Callout("Lorem ipsum placeholder text.").variant(.error)
        Callout("Lorem ipsum placeholder text.").variant(.info)
        Callout("Lorem ipsum placeholder text.").variant(.warning).calloutStyle(.soft)
        Callout("Lorem ipsum placeholder text.").variant(.neutral).calloutStyle(.soft)
        Callout("Brand-primary emphasis.").variant(.accent).calloutStyle(.soft)
        Callout("Custom glyph via icon override.").variant(.info).icon("bell.badge")
    }
    .padding()
}
