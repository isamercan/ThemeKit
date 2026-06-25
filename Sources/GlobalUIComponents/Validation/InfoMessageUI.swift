//
//  InfoMessageUI.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  The UI layer for `InfoMessage`: the theme-bound severity color and the
//  `InfoMessageList` renderer. Kept separate from the pure validation logic so
//  `InfoMessage` / `ValidationRule` / `Validator` stay SwiftUI- and theme-free.
//

import SwiftUI

extension InfoMessage.Kind {
    /// Theme-bound severity color (UI layer — depends on the active `Theme`).
    var color: Color {
        switch self {
        case .info: return Theme.shared.text(.textTertiary)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        }
    }
}

/// Renders a list of `InfoMessage`s (icon + colored text) under a field.
public struct InfoMessageList: View {
    private let messages: [InfoMessage]
    public init(_ messages: [InfoMessage]) { self.messages = messages }

    public var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(messages) { message in
                HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
                    if let icon = message.resolvedSystemImage {
                        Image(systemName: icon).font(.system(size: 11)).foregroundStyle(message.kind.color)
                    }
                    if message.links.isEmpty {
                        Text(message.text).textStyle(.bodySm400).foregroundStyle(message.kind.color)
                    } else {
                        InlineText(message.text, links: message.links, baseColor: message.kind.color)
                    }
                }
            }
        }
    }
}
