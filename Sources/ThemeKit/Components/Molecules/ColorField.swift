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
    private let supportsOpacity: Bool

    public init(_ label: String, selection: Binding<Color>, supportsOpacity: Bool = true) {
        self.label = label
        self._selection = selection
        self.supportsOpacity = supportsOpacity
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

#Preview {
    struct Demo: View {
        @State var color: Color = .blue
        var body: some View { ColorField("Brand color", selection: $color).padding() }
    }
    return Demo()
}
