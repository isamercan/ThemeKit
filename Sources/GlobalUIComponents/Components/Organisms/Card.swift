//
//  Card.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. A surface container with token padding / radius / elevation.
//

import SwiftUI

public enum CardElevation {
    case none, soft, elevated
}

public struct Card<Content: View>: View {
    private let elevation: CardElevation
    private let padding: CGFloat
    private let action: (() -> Void)?
    private let content: () -> Content

    public init(
        elevation: CardElevation = .soft,
        padding: CGFloat = 16,
        action: (() -> Void)? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.elevation = elevation
        self.padding = padding
        self.action = action
        self.content = content
    }

    private var surface: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.shared.background(.bgWhite),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.md.value, style: .continuous)
                    .strokeBorder(Theme.shared.border(.borderPrimary), lineWidth: elevation == .none ? 1 : 0)
            )
            .modifier(CardShadow(elevation: elevation))
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

private struct CardShadow: ViewModifier {
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
