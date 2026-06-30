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
                    .foregroundStyle(side == .incoming ? theme.text(.textPrimary) : theme.foreground(.fgSecondary))
                    .padding(.horizontal, Theme.SpacingKey.md.value)
                    .padding(.vertical, Theme.SpacingKey.sm.value)
                    .background(side == .incoming ? theme.background(.bgElevatorTertiary) : theme.background(.bgHero),
                               in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            }

            if side == .incoming { Spacer(minLength: Theme.SpacingKey.xl4.value) }
            if side == .outgoing { avatar }
        }
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

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubble("Hello! Your reservation is confirmed.", author: "Support", time: "09:24").side(.incoming).icon("person.fill")
        ChatBubble("Thanks, great!", time: "09:25").side(.outgoing).icon("person.fill")
    }
    .padding()
}
