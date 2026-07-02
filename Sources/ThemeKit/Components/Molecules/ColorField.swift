//
//  ColorField.swift
//  ThemeKit
//

import SwiftUI

/// Molecule. A labelled color well wrapping SwiftUI `ColorPicker` in the kit's field
/// chrome — a bordered surface with the label on the leading edge and the system
/// color well on the trailing edge. (daisyUI "Color Picker".)
public struct ColorField: View {
    @Environment(\.theme) private var theme

    private let label: String
    @Binding private var selection: Color

    // Appearance — mutated only through the modifiers below (R2).
    private var supportsOpacity: Bool = true

    public init(_ label: String, selection: Binding<Color>) {   // R1 — content + binding
        self.label = label
        self._selection = selection
    }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Text(label)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
            Spacer(minLength: 0)
            ColorPicker("", selection: $selection, supportsOpacity: supportsOpacity)
                .labelsHidden()
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .frame(height: 52)
        .background(theme.background(.bgWhite),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous)
                .stroke(theme.border(.borderPrimary), lineWidth: 1)
        )
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorField {
    /// Whether the color well lets the user adjust opacity (defaults to true).
    func supportsOpacity(_ on: Bool = true) -> Self { copy { $0.supportsOpacity = on } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var color: Color = .blue
        var body: some View { ColorField("Brand color", selection: $color).padding() }
    }
    return Demo()
}
