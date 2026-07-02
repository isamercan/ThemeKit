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
    private let actions: Actions?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var message: String?
    private var date: String?
    private var isUnread = false
    private var type: FeedbackKind?
    private var onClose: (() -> Void)?

    public init(title: String, @ViewBuilder actions: () -> Actions) {   // R1
        self.title = title
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
    init(title: String) {   // R1 — actionless convenience
        self.init(title: title) { EmptyView() }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension NotificationCard {
    /// Body text under the title.
    func message(_ text: String?) -> Self { copy { $0.message = text } }

    /// Timestamp line above the title.
    func date(_ text: String?) -> Self { copy { $0.date = text } }

    /// Show the unread dot next to the timestamp.
    func unread(_ on: Bool = true) -> Self { copy { $0.isUnread = on } }

    /// Semantic variant driving the leading icon and its color (nil = bell).
    func variant(_ kind: FeedbackKind?) -> Self { copy { $0.type = kind } }

    /// Show a trailing dismiss button invoking `action`.
    func onClose(_ action: (() -> Void)?) -> Self { copy { $0.onClose = action } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        NotificationCard(title: "We Have a Suggestion for Your Holiday") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Sec", size: .small) {}
                PrimaryButton("Pri", size: .small) {}
            }
        }
        .message("24 days left until your reservation at Hilton Istanbul.")
        .date("Thursday, December 5, 2024")
        .unread()
        NotificationCard(title: "7 days left until your holiday begins")
            .message("Rixos Sungate")
            .date("November 28, 2024")
    }
    .padding()
}
