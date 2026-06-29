//
//  NotificationCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A notification surface: bell icon, optional unread dot + timestamp,
/// title, message and optional actions.
public struct NotificationCard<Actions: View>: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let message: String?
    private let date: String?
    private let isUnread: Bool
    private let type: FeedbackKind?
    private let onClose: (() -> Void)?
    private let actions: Actions?

    public init(
        title: String,
        message: String? = nil,
        date: String? = nil,
        isUnread: Bool = false,
        type: FeedbackKind? = nil,
        onClose: (() -> Void)? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.title = title
        self.message = message
        self.date = date
        self.isUnread = isUnread
        self.type = type
        self.onClose = onClose
        self.actions = actions()
    }

    private var iconName: String { type?.systemImage ?? "bell" }
    private var iconColor: Color { type?.semanticColor.accent ?? theme.foreground(.fgHero) }

    public var body: some View {
        Card {
            HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
                Icon(systemName: iconName, size: .sm, color: iconColor)

                VStack(alignment: .leading, spacing: Theme.SpacingKey.xs.value) {
                    if let date {
                        HStack(spacing: Theme.SpacingKey.xs.value) {
                            if isUnread {
                                Circle().fill(theme.foreground(.systemcolorsFgError)).frame(width: 6, height: 6)
                            }
                            Text(date).textStyle(.overline400).foregroundStyle(theme.text(.textTertiary))
                        }
                    }
                    Text(title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.text(.textPrimary))
                    if let message {
                        Text(message)
                            .textStyle(.bodySm400)
                            .foregroundStyle(theme.text(.textSecondary))
                    }
                    if let actions {
                        actions.padding(.top, Theme.SpacingKey.xs.value)
                    }
                }
                Spacer(minLength: 0)
                if let onClose {
                    Button(action: onClose) {
                        Icon(systemName: "xmark", size: .xs, color: theme.text(.textTertiary))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(themeKit: "Dismiss"))
                }
            }
        }
    }
}

public extension NotificationCard where Actions == EmptyView {
    init(
        title: String,
        message: String? = nil,
        date: String? = nil,
        isUnread: Bool = false,
        type: FeedbackKind? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.init(title: title, message: message, date: date, isUnread: isUnread,
                  type: type, onClose: onClose) { EmptyView() }
    }
}

#Preview {
    VStack(spacing: 12) {
        NotificationCard(title: "We Have a Suggestion for Your Holiday",
                         message: "24 days left until your reservation at Hilton Istanbul.",
                         date: "Thursday, December 5, 2024", isUnread: true) {
            ButtonGroup(.horizontal) {
                SecondaryButton("Sec", size: .small) {}
                PrimaryButton("Pri", size: .small) {}
            }
        }
        NotificationCard(title: "7 days left until your holiday begins",
                         message: "Rixos Sungate", date: "November 28, 2024")
    }
    .padding()
}
