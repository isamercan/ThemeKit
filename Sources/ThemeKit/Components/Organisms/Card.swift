//
//  Card.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum CardElevation {
    case none, soft, elevated
}

/// Organism. A surface container with token padding / radius / elevation. An
/// optional header (title / subtitle + a trailing `extra` action, divided from
/// the body) and an `isLoading` skeleton bring it toward Ant Card.
public struct Card<Content: View>: View {
    private let title: String?
    private let action: (() -> Void)?
    private let content: () -> Content

    // Appearance/config — mutated only through the modifiers below (R2).
    private var elevation: CardElevation = .soft
    private var padding: CGFloat = 16
    private var subtitle: String?
    private var extraTitle: String?
    private var onExtra: (() -> Void)?
    private var isLoading = false

    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle

    public init(_ title: String? = nil, action: (() -> Void)? = nil, @ViewBuilder content: @escaping () -> Content) {   // R1
        self.title = title
        self.action = action
        self.content = content
    }

    private var hasHeader: Bool { title != nil || subtitle != nil || (extraTitle != nil && onExtra != nil) }

    @ViewBuilder
    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.sm.value) {
            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title).textStyle(.labelLg600).foregroundStyle(theme.text(.textPrimary))
                }
                if let subtitle {
                    Text(subtitle).textStyle(.bodySm400).foregroundStyle(theme.text(.textSecondary))
                }
            }
            Spacer(minLength: 0)
            if let extraTitle, let onExtra {
                Button(action: onExtra) {
                    Text(extraTitle).textStyle(.labelSm600).foregroundStyle(theme.foreground(.fgHero))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, padding)
        .padding(.top, padding)
        .padding(.bottom, Theme.SpacingKey.sm.value)
    }

    @ViewBuilder
    private var loadingPlaceholder: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.sm.value) {
            Skeleton(.capsule).size(height: 12).frame(maxWidth: 180)
            Skeleton(.capsule).size(height: 12)
            Skeleton(.capsule).size(height: 12).frame(maxWidth: 240)
        }
    }

    /// The composed content (header + body, padded) — the surface chrome around it
    /// is supplied by the active ``CardStyle``.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                DividerView().size(.small)
            }
            Group {
                if isLoading { loadingPlaceholder } else { content() }
            }
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var surface: some View {
        cardStyle.makeBody(configuration: CardStyleConfiguration(content: AnyView(cardContent), elevation: elevation))
    }

    public var body: some View {
        if let action {
            Button(action: action) { surface }
                .buttonStyle(PressFeedbackStyle())
        } else {
            surface
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Card {
    /// Secondary line under the title in the card header.
    func subtitle(_ text: String?) -> Self { copy { $0.subtitle = text } }

    /// Surface elevation: none / soft / elevated.
    func elevation(_ elevation: CardElevation) -> Self { copy { $0.elevation = elevation } }

    /// Inner content padding (named so it doesn't shadow the native `.padding`).
    func contentPadding(_ padding: CGFloat) -> Self { copy { $0.padding = padding } }

    /// Trailing header action (Ant `extra`) — renders when both title and action are set.
    func extraAction(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.extraTitle = title; $0.onExtra = action }
    }

    /// Replace the body with a skeleton placeholder while content loads.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

struct CardShadow: ViewModifier {
    let elevation: CardElevation
    func body(content: Content) -> some View {
        switch elevation {
        case .none: content
        case .soft: content.themeShadow(.soft)
        case .elevated: content.themeShadow(.elevated)
        }
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    VStack(spacing: 16) {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card title").textStyle(.headingSm)
                Text("Supporting body text inside a card surface.").textStyle(.bodyBase400)
                    .foregroundStyle(theme.text(.textSecondary))
            }
        }
        Card {
            Text("Elevated card").textStyle(.labelMd600)
        }
        .elevation(.elevated)
    }
    .padding()
    .background(theme.background(.bgBase))
}
