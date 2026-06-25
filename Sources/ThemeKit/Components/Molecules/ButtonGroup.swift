//
//  ButtonGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Molecule. Lays out related buttons in a vertical stack or an equal-width
//  horizontal row. Pass buttons with `isContentWidth: true`.
//

import SwiftUI

public enum ButtonGroupAxis {
    case vertical, horizontal
}

public struct ButtonGroup<Content: View>: View {
    private let axis: ButtonGroupAxis
    private let spacing: CGFloat
    private let content: () -> Content

    public init(_ axis: ButtonGroupAxis = .vertical, @ViewBuilder content: @escaping () -> Content) {
        self.axis = axis
        self.spacing = Theme.SpacingKey.sm.value
        self.content = content
    }

    public var body: some View {
        switch axis {
        case .vertical:
            VStack(spacing: spacing) { content() }
        case .horizontal:
            HStack(spacing: spacing) { content() }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ButtonGroup {
            PrimaryButton("Continue", isContentWidth: true) {}
            SecondaryButton("Not now", isContentWidth: true) {}
        }
        ButtonGroup(.horizontal) {
            SecondaryButton("Cancel", isContentWidth: true) {}
            PrimaryButton("Confirm", isContentWidth: true) {}
        }
    }
    .padding()
}
