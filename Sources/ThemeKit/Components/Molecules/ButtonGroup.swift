//
//  ButtonGroup.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ButtonGroupAxis {
    case vertical, horizontal
}

/// Molecule. Lays out related buttons in a vertical stack or a side-by-side row.
/// Buttons are content-width by default (ideal for a horizontal row); for a
/// vertical full-width CTA stack, pass the buttons `block: true`.
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
        ButtonGroup {   // vertical CTA stack → full-width
            PrimaryButton("Continue", block: true) {}
            SecondaryButton("Not now", block: true) {}
        }
        ButtonGroup(.horizontal) {   // side-by-side → content-width (default)
            SecondaryButton("Cancel") {}
            PrimaryButton("Confirm") {}
        }
    }
    .padding()
}
