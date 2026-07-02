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
/// vertical full-width CTA stack, give the buttons `.fullWidth()`.
///
/// A horizontal group **wraps**: each button keeps its single-line label at its
/// natural width and overflowing buttons flow to the next line, instead of being
/// squeezed until the text wraps onto two lines.
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
            // FlowLayout (not HStack) so buttons wrap to the next line rather than
            // compressing — hugs content when it fits, wraps when it doesn't.
            FlowLayout(spacing: spacing, lineSpacing: spacing) { content() }
        }
    }
}

#Preview {
    VStack(spacing: 24) {
        ButtonGroup {   // vertical CTA stack → full-width
            PrimaryButton("Continue") {}.fullWidth()
            SecondaryButton("Not now") {}.fullWidth()
        }
        ButtonGroup(.horizontal) {   // side-by-side → content-width (default)
            SecondaryButton("Cancel") {}
            PrimaryButton("Confirm") {}
        }
    }
    .padding()
}
