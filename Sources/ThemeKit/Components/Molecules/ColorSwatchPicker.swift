//
//  ColorSwatchPicker.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  A grid of `ColorSwatch`es that drives a single selection. (HeroUI "Color
//  Swatch Picker".) Selection keys off a stable `id`, never off `Color`
//  equality — `Color` compares unreliably across color spaces, which is why
//  the item type carries an identity.
//

import SwiftUI

/// One entry in a `ColorSwatchPicker`: a color, its spoken `label`, and a
/// stable `id` (defaults to the label) used for selection identity.
public struct ColorSwatchItem: Identifiable, Equatable, Sendable {
    public let id: String
    public let color: Color
    public let label: String

    public init(_ color: Color, label: String, id: String? = nil) {
        self.color = color
        self.label = label
        self.id = id ?? label
    }
}

/// Molecule. A preset-palette picker. Wraps by default (a `FlowLayout`); pass
/// `.columns(n)` for a fixed `LazyVGrid`.
///
///     @State private var brand: ColorSwatchItem?
///     ColorSwatchPicker(palette, selection: $brand).columns(6).swatchShape(.circle)
public struct ColorSwatchPicker: View {
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    // `Layout.placeSubviews` computes absolute x that does NOT auto-mirror, so
    // the container reads the direction and hands it to the layout.
    @Environment(\.layoutDirection) private var layoutDirection

    private let items: [ColorSwatchItem]
    @Binding private var selection: ColorSwatchItem?

    // Appearance/config — mutated only through the modifiers below (R2).
    private var columns: Int?
    private var swatchShape: ColorSwatchShape = .square
    private var swatchSize: ColorSwatchSize = .medium

    public init(_ items: [ColorSwatchItem], selection: Binding<ColorSwatchItem?>) {   // R1 — content + binding
        self.items = items
        self._selection = selection
    }

    public var body: some View {
        layout
            .animation(MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion), value: selection)
    }

    @ViewBuilder private var layout: some View {
        let spacing = Theme.SpacingKey.sm.value
        if let columns {
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: max(columns, 1)),
                spacing: spacing
            ) {
                ForEach(items) { swatchButton($0) }
            }
        } else {
            FlowLayout(spacing: spacing, lineSpacing: spacing, layoutDirection: layoutDirection) {
                ForEach(items) { swatchButton($0) }
            }
        }
    }

    private func swatchButton(_ item: ColorSwatchItem) -> some View {
        let isSelected = selection?.id == item.id
        return Button {
            selection = item
        } label: {
            ColorSwatch(item.color, label: item.label)
                .shape(swatchShape)
                .size(swatchSize)
                .selected(isSelected)
                .accessibilityHidden(true)                 // the Button is the a11y element
                .frame(minWidth: 44, minHeight: 44)        // ≥44pt tap target (chip stays sized)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(item.label))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorSwatchPicker {
    /// Fixed column count (a `LazyVGrid`); `nil` (default) wraps with a
    /// `FlowLayout` sized to the container width.
    func columns(_ n: Int?) -> Self { copy { $0.columns = n } }

    /// Shape of every swatch (default `.square`).
    func swatchShape(_ s: ColorSwatchShape) -> Self { copy { $0.swatchShape = s } }

    /// Size of every swatch (default `.medium`).
    func swatchSize(_ s: ColorSwatchSize) -> Self { copy { $0.swatchSize = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var wrap: ColorSwatchItem?
        @State var grid: ColorSwatchItem?
        var body: some View {
            let palette: [ColorSwatchItem] = [
                .init(.red, label: "Red"), .init(.orange, label: "Orange"),
                .init(.yellow, label: "Yellow"), .init(.green, label: "Green"),
                .init(.blue, label: "Blue"), .init(.indigo, label: "Indigo"),
                .init(.purple, label: "Purple"), .init(.pink, label: "Pink"),
            ]
            // Interactive picker — each cell shows one representative frame; tap swatches
            // in the live preview to drive the selection ring.
            PreviewMatrix("ColorSwatchPicker") {
                PreviewCase("Wrapping · circle") {
                    ColorSwatchPicker(palette, selection: $wrap).swatchShape(.circle)
                }
                PreviewCase("4 columns · large") {
                    ColorSwatchPicker(palette, selection: $grid).columns(4).swatchSize(.large)
                }
            }
        }
    }
    return Demo()
}
