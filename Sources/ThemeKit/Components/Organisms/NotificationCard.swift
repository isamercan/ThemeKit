//
//  NotificationCard.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Organism. A notification surface: bell icon, optional unread dot + timestamp,
/// title, message and optional actions.
///
/// The outer shell (surface fill, corner clipping, elevation shadow/border) is drawn
/// by the active `CardStyle` from the environment — `.surface()/.cornerRadius()/
/// .elevation()` feed the `CardStyleConfiguration`, so the default look (white
/// surface, box corner, soft shadow — the classic `Card` chrome) is unchanged while
/// `.cardStyle(_:)` can swap in a completely different shell. `.leading {}` replaces
/// the built-in icon; the unread dot is content emphasis and never touches the shell.
public struct NotificationCard<Actions: View>: View {
    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle

    private let title: String
    private let actions: Actions?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var message: String?
    private var date: String?
    private var isUnread = false
    private var type: FeedbackKind?
    private var onClose: (() -> Void)?
    private var leadingSlot: AnyView?
    // Inline CTA row (Ant notification `actions`; Callout/InfoBanner pattern).
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var secondaryActionTitle: String?
    private var onSecondaryAction: (() -> Void)?
    // Shell — token-fed; defaults match the previous `Card`-provided chrome.
    private var surfaceKey: Theme.BackgroundColorKey = .bgWhite
    private var radiusRole: Theme.RadiusRole = .box
    private var elevation: CardElevation = .soft

    public init(title: String, @ViewBuilder actions: () -> Actions) {   // R1
        self.title = title
        self.actions = actions()
    }

    private var iconName: String { type?.systemImage ?? "bell" }
    private var iconColor: Color { type?.semanticColor.accent ?? theme.foreground(.fgHero) }

    public var body: some View {
        // The shell (fill, corner clipping, border, shadow) is drawn by the active
        // `CardStyle` — the defaults reproduce the previous `Card` wrapper exactly.
        cardStyle.makeBody(configuration: CardStyleConfiguration(
            content: AnyView(cardContent),
            elevation: elevation,
            isSelected: false,
            isPressed: false,
            surfaceKey: surfaceKey,
            radius: radiusRole))
    }

    /// The card's inner layout — everything inside the shell. The 16pt padding and
    /// leading-aligned max-width frame match `Card`'s default content treatment.
    private var cardContent: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            leadingArea

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
                if actionTitle != nil || secondaryActionTitle != nil {
                    HStack(spacing: Theme.SpacingKey.md.value) {
                        if let actionTitle, let onAction {
                            Button(action: onAction) {
                                Text(actionTitle).textStyle(.labelSm600).foregroundStyle(theme.text(.textHero))
                            }
                            .buttonStyle(.plain)
                        }
                        if let secondaryActionTitle, let onSecondaryAction {
                            Button(action: onSecondaryAction) {
                                Text(secondaryActionTitle).textStyle(.labelSm600).foregroundStyle(theme.text(.textSecondary))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, Theme.SpacingKey.xs.value)
                }
            }
            Spacer(minLength: 0)
            if let onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark").size(.xs).colorOverride(theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(themeKit: "Dismiss"))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// The leading icon region: the `.leading {}` slot when set, else the
    /// variant-driven bell icon.
    @ViewBuilder private var leadingArea: some View {
        if let leadingSlot {
            leadingSlot
        } else {
            Icon(systemName: iconName).size(.sm).colorOverride(iconColor)
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

    /// Inline call-to-action under the message — e.g. "View" (Ant notification
    /// `actions`; the Callout/InfoBanner `action(_:onAction:)` pattern). For
    /// richer content, compose the `actions:` init slot instead.
    func action(_ title: String, onAction: @escaping () -> Void) -> Self {
        copy { $0.actionTitle = title; $0.onAction = onAction }
    }

    /// Optional secondary inline action rendered after the primary — e.g. "Undo".
    func secondaryAction(_ title: String, onAction: @escaping () -> Void) -> Self {
        copy { $0.secondaryActionTitle = title; $0.onSecondaryAction = onAction }
    }

    /// Replace the leading icon region with custom content — an avatar, a brand
    /// mark. Omit to keep the `variant(_:)`-driven bell icon.
    func leading<V: View>(@ViewBuilder _ content: () -> V) -> Self { copy { $0.leadingSlot = AnyView(content()) } }

    // Shell (token-fed, drawn by the active `CardStyle`).
    /// Surface fill (background token key, default `.bgWhite`).
    func surface(_ key: Theme.BackgroundColorKey) -> Self { copy { $0.surfaceKey = key } }
    /// Container corner radius role (default `.box`).
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.radiusRole = role } }
    /// Surface elevation (default `.soft` — the classic card shadow).
    func elevation(_ e: CardElevation) -> Self { copy { $0.elevation = e } }

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
                SecondaryButton("Sec") {}.size(.small)
                PrimaryButton("Pri") {}.size(.small)
            }
        }
        .message("24 days left until your reservation at Hilton Istanbul.")
        .date("Thursday, December 5, 2024")
        .unread()
        NotificationCard(title: "7 days left until your holiday begins")
            .message("Rixos Sungate")
            .date("November 28, 2024")
        // D6 — inline action row via the Callout/InfoBanner modifier pattern.
        NotificationCard(title: "Your price alert dropped")
            .message("The route you follow is now 12% cheaper.")
            .variant(.success)
            .action("View") {}
            .secondaryAction("Dismiss") {}
            .onClose {}
    }
    .padding()
}

#Preview("Outlined style + leading slot") {
    NotificationCard(title: "Ayşe replied to your review")
        .message("\"Thanks for the kind words — see you next summer!\"")
        .date("Today, 09:41")
        .unread()
        .leading { Avatar(.initials("AD")).size(.sm) }
        .cardStyle(.outlined)
        .padding()
}
