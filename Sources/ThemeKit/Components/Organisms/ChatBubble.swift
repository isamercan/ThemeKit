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
    private let side: ChatSide
    private let author: String?
    private let time: String?
    private let avatarSystemImage: String?

    public init(_ text: String, side: ChatSide = .incoming, author: String? = nil, time: String? = nil, avatarSystemImage: String? = nil) {
        self.text = text
        self.side = side
        self.author = author
        self.time = time
        self.avatarSystemImage = avatarSystemImage
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
            Avatar(.icon(avatarSystemImage), size: .sm, background: side == .incoming ? .blue : .dark)
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ChatBubble("Merhaba! Rezervasyonunuz onaylandı.", side: .incoming, author: "Destek", time: "09:24", avatarSystemImage: "person.fill")
        ChatBubble("Teşekkürler, harika!", side: .outgoing, time: "09:25", avatarSystemImage: "person.fill")
    }
    .padding()
}
