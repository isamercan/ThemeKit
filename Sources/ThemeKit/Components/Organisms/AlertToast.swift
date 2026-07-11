//
//  AlertToast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum AlertToastType {
    case success, warning, danger, info
    /// Low-emphasis message on a muted surface (HeroUI's "default" variant).
    case neutral
    /// Brand-tinted toast fed by `SemanticColor.primary` (HeroUI's "accent").
    case accent

    func background(_ theme: Theme) -> Color {
        switch self {
        case .success: return theme.background(.systemcolorsBgSuccess)
        case .warning: return theme.background(.systemcolorsBgWarning)
        case .danger: return theme.background(.systemcolorsBgError)
        case .info: return theme.background(.systemcolorsBgInfo)
        case .neutral: return theme.background(.bgTertiary)
        case .accent: return SemanticColor.primary.solid
        }
    }

    /// Warning uses dark text for contrast on the bright amber fill; accent
    /// auto-contrasts against whatever the brand's solid primary resolves to.
    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .warning: return theme.text(.textPrimary)
        case .success, .danger, .info, .neutral: return theme.foreground(.fgSecondary)
        case .accent: return SemanticColor.primary.onSolid
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        case .info: return "info.circle.fill"
        case .neutral: return "bell.fill"
        case .accent: return "sparkles"
        }
    }

    /// Localized VoiceOver label for the status icon — the variant's meaning
    /// is otherwise carried only by glyph + fill color.
    var accessibilityLabel: String {
        switch self {
        case .success: return String(themeKit: "Success")
        case .warning: return String(themeKit: "Warning")
        case .danger: return String(themeKit: "Error")
        case .info, .accent: return String(themeKit: "Information")
        case .neutral: return String(themeKit: "Note")
        }
    }
}

/// An optional tappable action rendered inline in a toast (e.g. "Undo"). Its
/// label inherits the toast's foreground color so it reads on the solid fill.
public struct ToastAction {
    public let title: String
    public let handler: () -> Void

    public init(_ title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

/// Improved, token-bound rewrite of the reference AlertView — a solid-fill
/// status banner (complements the light-surface InfoBanner).
public struct AlertToast: View {
    @Environment(\.theme) private var theme
    @Environment(\.toastStyle) private var style

    private let title: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var message: String?
    /// Tappable substrings of `message` (rendered via `InlineText` when non-empty).
    private var links: [(substring: String, action: () -> Void)] = []
    private var type: AlertToastType = .info
    private var systemImage: String?
    private var isLoading: Bool = false
    private var action: ToastAction?
    private var onClose: (() -> Void)?

    public init(_ title: String) {   // R1 — content only
        self.title = title
    }

    public var body: some View {
        presentation
            // VoiceOver gets no signal that a toast surfaced, so announce its
            // content when it appears. Uses the cross-platform SwiftUI API
            // (no UIKit `UIAccessibility.post`) so the macOS build stays green.
            .onAppear { AccessibilityNotification.Announcement(announcementText).post() }
    }

    /// The composed shell. Chrome is delegated to the active `ToastStyle`. When
    /// no `.toastStyle(_:)` is set anywhere up the tree we keep the original
    /// inline shell, so the stock look stays pixel-identical by construction;
    /// an explicitly set style (including `.default`) routes through `makeBody`
    /// with the pre-composed content row.
    @ViewBuilder
    private var presentation: some View {
        if style.isDefault {
            row
                .foregroundStyle(type.foreground(theme))
                .padding(.vertical, 12)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .background(type.background(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        } else {
            style.makeBody(configuration: ToastStyleConfiguration(
                content: AnyView(row), variant: type, isLoading: isLoading
            ))
        }
    }

    /// What VoiceOver reads aloud when the toast surfaces — the title, plus the
    /// secondary line when present.
    private var announcementText: String {
        if let message { return "\(title), \(message)" }
        return title
    }

    /// The content row a style receives: leading icon/spinner, title + message,
    /// and the trailing action/close block. Chrome-free — the shell (tint, fill,
    /// padding, shape) is the style's job.
    private var row: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            // Leading accessory: an activity spinner while loading, otherwise the
            // status icon (a caller override falls back to the type's default).
            if isLoading {
                Spinner().size(IconSize.sm.value).lineWidth(2).color(type.foreground(theme))
            } else {
                Icon(systemName: systemImage ?? type.systemImage).size(.sm).color(type.foreground(theme))
                    .accessibilityLabel(type.accessibilityLabel)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.labelBase600)
                if let message {
                    if links.isEmpty {
                        Text(message).textStyle(.bodySm400).opacity(0.9)
                    } else {
                        InlineText(message, links: links).inlineStyle(.bodySm400)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let action {
                Button(action: action.handler) {
                    Text(action.title).textStyle(.labelBase700).underline()
                }
                .buttonStyle(.plain)
            }

            if let onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark").size(.xs).color(type.foreground(theme))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Close"))
            }
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AlertToast {
    /// Secondary line under the title.
    func message(_ text: String?) -> Self { copy { $0.message = text; $0.links = [] } }

    /// Secondary line with tappable inline substrings, rendered via `InlineText`
    /// (the shipped links idiom — API symmetry with `Callout.links` /
    /// `HelperText.links`). `InlineText` draws its own body/link tints, so this
    /// reads best on the light-surface `.neutral` variant or a soft custom
    /// `ToastStyle`; the trailing `action(_:)` title is unaffected.
    func message(_ text: String, links: [(substring: String, action: () -> Void)]) -> Self {
        copy { $0.message = text; $0.links = links }
    }

    /// Status treatment: success / warning / danger / info / neutral / accent
    /// (drives fill + icon).
    func variant(_ v: AlertToastType) -> Self { copy { $0.type = v } }

    /// Override the leading status glyph (otherwise derived from the variant).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }

    /// Swap the leading icon for an activity spinner while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Inline tappable action (e.g. "Undo"), rendered before the close button.
    func action(_ action: ToastAction?) -> Self { copy { $0.action = action } }

    /// Trailing dismiss button; the handler is invoked on tap.
    func onClose(_ handler: (() -> Void)?) -> Self { copy { $0.onClose = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        AlertToast("Saved successfully").variant(.success).onClose {}
        AlertToast("Check your input").message("One field needs attention.").variant(.warning)
        AlertToast("Something went wrong").variant(.danger).onClose {}
        AlertToast("New update available").variant(.info)
        AlertToast("Notifications paused").variant(.neutral).onClose {}
        AlertToast("Pro features unlocked").message("Enjoy the upgrade.").variant(.accent).onClose {}
        AlertToast("Message deleted").variant(.info).action(ToastAction("Undo") {}).onClose {}
        AlertToast("Uploading…").variant(.info).loading()
        AlertToast("Update available")
            .message("Read the release notes before installing.",
                     links: [("release notes", { print("notes") })])
            .variant(.neutral)
            .onClose {}
    }
    .padding()
}

#Preview("Toast styles") {
    /// A light-surface toast — an example custom `ToastStyle`.
    struct SoftToastStyle: ToastStyle {
        func makeBody(configuration: ToastStyleConfiguration) -> some View {
            configuration.content
                .padding(.vertical, 12)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .background(Theme.shared.background(.bgWhite), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .strokeBorder(configuration.variant.background(Theme.shared), lineWidth: 1.5))
        }
    }

    return VStack(spacing: 12) {
        AlertToast("Saved successfully").variant(.success).onClose {}
            .toastStyle(.capsule)
        AlertToast("Copied to clipboard").variant(.info)
            .toastStyle(.capsule)
        AlertToast("Something went wrong").message("Try again in a moment.").variant(.danger).onClose {}
            .toastStyle(SoftToastStyle())
    }
    .padding()
}
