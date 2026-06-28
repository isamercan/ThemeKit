//
//  Card.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A surface container with token padding / radius / elevation. An
//  optional header (title / subtitle + a trailing `extra` action, divided from
//  the body) and an `isLoading` skeleton bring it toward Ant Card.
//

import SwiftUI

public enum CardElevation {
    case none, soft, elevated
}

public struct Card<Content: View>: View {
    private let elevation: CardElevation
    private let padding: CGFloat
    private let title: String?
    private let subtitle: String?
    private let extraTitle: String?
    private let onExtra: (() -> Void)?
    private let isLoading: Bool
    private let action: (() -> Void)?
    private let content: () -> Content

    @Environment(\.theme) private var theme
    @Environment(\.cardStyle) private var cardStyle

    public init(
        elevation: CardElevation = .soft,
        padding: CGFloat = 16,
        title: String? = nil,
        subtitle: String? = nil,
        extraTitle: String? = nil,
        onExtra: (() -> Void)? = nil,
        isLoading: Bool = false,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.elevation = elevation
        self.padding = padding
        self.title = title
        self.subtitle = subtitle
        self.extraTitle = extraTitle
        self.onExtra = onExtra
        self.isLoading = isLoading
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
            Skeleton(.capsule, height: 12).frame(maxWidth: 180)
            Skeleton(.capsule, height: 12)
            Skeleton(.capsule, height: 12).frame(maxWidth: 240)
        }
    }

    /// The composed content (header + body, padded) — the surface chrome around it
    /// is supplied by the active ``CardStyle``.
    private var cardContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if hasHeader {
                header
                DividerView(size: .small)
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
    VStack(spacing: 16) {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Card title").textStyle(.headingSm)
                Text("Supporting body text inside a card surface.").textStyle(.bodyBase400)
                    .foregroundStyle(Theme.shared.text(.textSecondary))
            }
        }
        Card(elevation: .elevated) {
            Text("Elevated card").textStyle(.labelMd600)
        }
    }
    .padding()
    .background(Theme.shared.background(.bgElevatorPrimary))
}
