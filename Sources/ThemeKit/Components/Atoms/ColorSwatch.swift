//
//  ColorSwatch.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A single color chip — the color painted over an alpha checkerboard, a
//  hairline border, and an optional hero selection ring. (HeroUI "Color
//  Swatch".) The chip's `color` is *content*, not chrome, so a raw `Color` in
//  the init is correct here (the `ColorField` precedent). Pair many of them in
//  `ColorSwatchPicker`.
//

import SwiftUI

public enum ColorSwatchShape: CaseIterable, Sendable { case square, circle }

public enum ColorSwatchSize: CaseIterable, Sendable {
    case small, medium, large
    var dimension: CGFloat { switch self { case .small: 20; case .medium: 28; case .large: 36 } }
}

/// Atom. Renders one color as a chip. `label` is required because a bare color
/// is invisible to VoiceOver — it is the color's spoken identity ("Crimson").
///
///     ColorSwatch(.red, label: "Crimson").shape(.circle).size(.large).selected()
public struct ColorSwatch: View {
    @Environment(\.theme) private var theme
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let color: Color
    private let label: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var shape: ColorSwatchShape = .square
    private var size: ColorSwatchSize = .medium
    private var isSelected = false

    public init(_ color: Color, label: String) {   // R1 — content + identity
        self.color = color
        self.label = label
    }

    public var body: some View {
        ZStack {
            theme.background(.bgWhite)
            CheckerboardPattern().fill(theme.background(.bgSecondaryLight))
            color
        }
        .frame(width: size.dimension, height: size.dimension)
        .clipShape(swatchShape)
        .overlay { swatchShape.strokeBorder(theme.border(.borderPrimary), lineWidth: 1) }
        .overlay { selectionRing }
        .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: isSelected)
        .accessibilityElement()
        .accessibilityLabel(Text(label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// A hero ring on the edge with a 1pt inner light gap, so the selection
    /// reads on both pale and dark swatches without changing the chip's size.
    @ViewBuilder private var selectionRing: some View {
        if isSelected {
            ZStack {
                swatchShape.strokeBorder(theme.border(.borderHero), lineWidth: 2)
                swatchShape.strokeBorder(theme.background(.bgWhite), lineWidth: 1).padding(2)
            }
        }
    }

    /// A circle is a fully-rounded square (the frame is square), so one
    /// insettable shape drives clip, border and ring uniformly.
    private var cornerRadius: CGFloat {
        shape == .circle ? size.dimension / 2 : Theme.RadiusRole.selector.value
    }
    private var swatchShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorSwatch {
    /// `.square` (default, `RadiusRole.selector` corners) or `.circle`.
    func shape(_ s: ColorSwatchShape) -> Self { copy { $0.shape = s } }

    /// Chip dimension — `.small` 20 / `.medium` 28 (default) / `.large` 36pt.
    func size(_ s: ColorSwatchSize) -> Self { copy { $0.size = s } }

    /// Draw the hero selection ring (default off).
    func selected(_ on: Bool = true) -> Self { copy { $0.isSelected = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ColorSwatch") {
        PreviewCase("Size ramp") {
            HStack(spacing: 12) {
                ForEach(ColorSwatchSize.allCases, id: \.self) { size in
                    ColorSwatch(.blue, label: "Blue").size(size)
                }
            }
        }
        PreviewCase("Selected (square / circle)") {
            HStack(spacing: 12) {
                ColorSwatch(.red, label: "Red").selected()
                ColorSwatch(.green, label: "Green").shape(.circle).selected()
            }
        }
        PreviewCase("Circle / alpha checkerboard") {
            HStack(spacing: 12) {
                ColorSwatch(.black, label: "Ink").shape(.circle)
                ColorSwatch(.purple.opacity(0.4), label: "Faded purple")  // alpha → checkerboard
            }
        }
    }
}
