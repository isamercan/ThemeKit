//
//  SwapButton.swift
//  ThemeKit
//
//  Atom. A circular icon button that flips / swaps two things — origin ⇄
//  destination, from ⇄ to, before ⇄ after. Action-only (not a toggle; see
//  ``Swap`` for the on/off variant). Token-bound.
//

import SwiftUI

public struct SwapButton: View {
    @Environment(\.theme) private var theme

    private let action: () -> Void
    // Appearance — mutated only through the modifiers below (R2).
    private var systemImage: String
    private var diameter: CGFloat = 34
    private var bordered = true

    public init(_ systemImage: String = "arrow.up.arrow.down", action: @escaping () -> Void) {   // R1
        self.systemImage = systemImage
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: diameter * 0.42, weight: .semibold))
                .foregroundStyle(theme.foreground(.fgHero))
                .frame(width: diameter, height: diameter)
                .background(theme.background(.bgBase), in: Circle())
                .overlay { if bordered { Circle().stroke(theme.border(.borderPrimary), lineWidth: 1) } }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(String(themeKit: "Swap"))
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SwapButton {
    /// Button diameter in points (default 34).
    func size(_ diameter: CGFloat) -> Self { copy { $0.diameter = max(24, diameter) } }
    /// Draw the 1pt border (default true).
    func bordered(_ on: Bool = true) -> Self { copy { $0.bordered = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var a = "IST"
        @State var b = "AYT"
        var body: some View {
            PreviewMatrix("SwapButton") {
                PreviewCase("In context (tap to swap)") {
                    HStack(spacing: 16) {
                        Text(a).textStyle(.headingSm)
                        SwapButton { swap(&a, &b) }
                        Text(b).textStyle(.headingSm)
                    }
                }
                PreviewCase("Borderless") { SwapButton(action: {}).bordered(false) }
                PreviewCase("Large · custom glyph") { SwapButton("arrow.left.arrow.right", action: {}).size(44) }
            }
        }
    }
    return Demo()
}
