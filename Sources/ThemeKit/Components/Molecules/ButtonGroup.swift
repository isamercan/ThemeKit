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
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection

    // Appearance — mutated only through the modifiers below.
    private var axis: ButtonGroupAxis
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
            FlowLayout(spacing: spacing, lineSpacing: spacing, layoutDirection: layoutDirection) { content() }
        }
    }
}

// MARK: - Modifiers (copy-on-write · single mutation point)

public extension ButtonGroup {
    /// Layout axis — a vertical stack or a wrapping side-by-side row.
    /// Preferred over the `axis:` init argument (orientation is a reskin, so it
    /// chains): `ButtonGroup { … }.axis(.horizontal)`.
    func axis(_ axis: ButtonGroupAxis) -> Self { copy { $0.axis = axis } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ButtonGroup") {
        PreviewCase("Vertical CTA stack (full-width)") {
            ButtonGroup {
                PrimaryButton("Continue") {}.fullWidth()
                SecondaryButton("Not now") {}.fullWidth()
            }
        }
        PreviewCase("Horizontal (content-width)") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Cancel") {}
                PrimaryButton("Confirm") {}
            }
        }
        PreviewCase("Horizontal overflow wraps") {
            ButtonGroup(.horizontal) {
                SecondaryButton("Back") {}
                SecondaryButton("Save draft") {}
                PrimaryButton("Continue to payment") {}
            }
        }
    }
}
