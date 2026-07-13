//
//  ChatBubble.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ChatSide {
    case incoming, outgoing
}

/// Organism. A chat message bubble (incoming / outgoing) with optional avatar,
/// author and timestamp. (daisyUI "Chat bubble".)
public struct ChatBubble: View {
    @Environment(\.theme) private var theme

    private let text: String
    private let author: String?
    private let time: String?

    // Appearance — mutated only through the modifiers below (R2).
    private var side: ChatSide = .incoming
    private var avatarSystemImage: String?
    private var accent: SemanticColor?

    public init(_ text: String, author: String? = nil, time: String? = nil) {   // R1
        self.text = text
        self.author = author
        self.time = time
    }

    public var body: some View {
        HStack(alignment: .bottom, spacing: Theme.SpacingKey.sm.value) {
            if side == .incoming { avatar }
            if side == .outgoing { Spacer(minLength: Theme.SpacingKey.xl4.value) }

            VStack(alignment: side == .incoming ? .leading : .trailing, spacing: 2) {
                if author != nil || time != nil {
                    HStack(spacing: 4) {
                        if let author { Text(author).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary)) }
                        if let time { Text(time).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary)) }
                    }
                }
                Text(text)
                    .textStyle(.bodyBase400)
                    .foregroundStyle(bubbleForeground)
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
                    .background(bubbleFill,
                               in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            }

            if side == .incoming { Spacer(minLength: Theme.SpacingKey.xl4.value) }
            if side == .outgoing { avatar }
        }
    }

    /// Accent tint wins over the side defaults (daisyUI `chat-bubble-{color}`).
    private var bubbleFill: Color {
        if let accent { return theme.resolve(accent).solid }
        return side == .incoming ? theme.background(.bgElevatorTertiary) : theme.background(.bgHero)
    }
    private var bubbleForeground: Color {
        if let accent { return theme.resolve(accent).onSolid }
        return side == .incoming ? theme.text(.textPrimary) : theme.foreground(.fgSecondary)
    }

    @ViewBuilder
    private var avatar: some View {
        if let avatarSystemImage {
            Avatar(.icon(avatarSystemImage)).size(.sm).fillColor(side == .incoming ? .blue : .dark)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ChatBubble {
    /// Conversation side: incoming (leading) / outgoing (trailing).
    func side(_ s: ChatSide) -> Self { copy { $0.side = s } }

    /// Leading/trailing avatar SF Symbol (positioned by `side`).
    func icon(_ systemImage: String?) -> Self { copy { $0.avatarSystemImage = systemImage } }

    /// Semantic tint for the bubble fill (foreground auto-contrasts); `nil`
    /// (default) keeps the side-based look. (daisyUI `chat-bubble-{color}`.)
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ChatBubble") {
        PreviewCase("Incoming + avatar") {
            ChatBubble("Hello! Your reservation is confirmed.", author: "Support", time: "09:24").side(.incoming).icon("person.fill")
        }
        PreviewCase("Outgoing + avatar") {
            ChatBubble("Thanks, great!", time: "09:25").side(.outgoing).icon("person.fill")
        }
        PreviewCase("Accent success") {
            ChatBubble("Payment received.").side(.outgoing).accent(.success)
        }
        PreviewCase("Accent warning") {
            ChatBubble("Gate changed to B12.").side(.incoming).accent(.warning)
        }
    }
}
