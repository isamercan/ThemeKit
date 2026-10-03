//
//  InfoMessageUI.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The UI layer for `InfoMessage`: the theme-bound severity color and the
//  `InfoMessageList` renderer. Kept separate from the pure validation logic so
//  `InfoMessage` / `ValidationRule` / `Validator` stay SwiftUI- and theme-free.
//

import SwiftUI

extension InfoMessage.Kind {
    /// Theme-bound severity color (UI layer — resolved against the passed `Theme`,
    /// matching `StatusDot.Kind.color(_:)`). Value-type accessors can't read the
    /// SwiftUI environment, so the owning view hands its active theme in.
    func color(_ theme: Theme) -> Color {
        switch self {
        case .info: return theme.text(.textTertiary)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error: return theme.foreground(.systemcolorsFgError)
        }
    }
}

/// Renders a list of `InfoMessage`s (icon + colored text) under a field.
public struct InfoMessageList: View {
    @Environment(\.theme) private var theme
    @Environment(\.infoMessageIcons) private var showsIcons
    private let messages: [InfoMessage]
    public init(_ messages: [InfoMessage]) { self.messages = messages }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Keyed on content (kind + text), not the per-instance UUID id:
            // fields rebuild convenience messages every render, and a fresh
            // UUID would make ForEach remove+insert unchanged rows, replaying
            // the transition on lines that didn't change.
            ForEach(messages, id: \.diffIdentity) { message in
                HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
                    if showsIcons, let icon = message.resolvedSystemImage {
                        Image(systemName: icon).font(.system(size: 11)).foregroundStyle(message.kind.color(theme))
                    }
                    if message.links.isEmpty {
                        Text(message.text).textStyle(.bodySm400).foregroundStyle(message.kind.color(theme))
                    } else {
                        InlineText(message.text, links: message.links).color(message.kind.color(theme))
                    }
                }
                // Animated appearance/disappearance (HeroUI FieldError parity).
                // Plays only when the owning field animates the change — fields
                // key a `MicroMotion`-gated animation on their message list, so
                // `microAnimations(false)` / Reduce Motion snap instantly.
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Severity icons

private struct InfoMessageIconsKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Whether `InfoMessageList` draws each message's severity glyph. On unless
    /// `.infoMessageIcons(false)` turns it off up the tree.
    var infoMessageIcons: Bool {
        get { self[InfoMessageIconsKey.self] }
        set { self[InfoMessageIconsKey.self] = newValue }
    }
}

public extension View {
    /// Shows or hides the severity glyph before the messages under the fields in this view —
    /// an error's `exclamationmark.circle.fill`, a warning's triangle. On by default. A design
    /// system whose form errors are plain coloured text turns it off; the text, its colour
    /// and the field's error state are unchanged.
    func infoMessageIcons(_ on: Bool) -> some View {
        environment(\.infoMessageIcons, on)
    }
}
