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
    /// The field chrome (fill + border), swappable via `.fieldStyle(_:)`.
    @Environment(\.fieldStyle) private var fieldStyle
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`

    private let label: String
    @Binding private var selection: Color

    // Appearance — mutated only through the modifiers below (R2).
    private var supportsOpacity: Bool = true

    public init(_ label: String, selection: Binding<Color>) {   // R1 — content + binding
        self.label = label
        self._selection = selection
    }

    /// The field chrome is delegated to the active ``FieldStyle``. Mapping: the
    /// system color well never drives keyboard focus, so `isFocused` is always
    /// `false`; there is no validation axis, so `hasError`/`hasWarning` are
    /// `false`; `size` is `.medium` — ColorField has no `TextInputSize` axis
    /// (the row keeps its fixed 52pt height in the content).
    public var body: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(row),
            isFocused: false,
            isEnabled: isEnabled,
            hasError: false,
            hasWarning: false,
            size: .medium
        ))
    }

    /// The label + color-well row, sized — everything the ``FieldStyle``
    /// receives as `configuration.content`.
    private var row: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            Text(label)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
            Spacer(minLength: 0)
            ColorPicker("", selection: $selection, supportsOpacity: supportsOpacity)
                .labelsHidden()
                .accessibilityLabel(label)
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .frame(height: 52)
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
        var body: some View {
            VStack(spacing: 16) {
                ColorField("Brand color", selection: $color)
                // Swapped chrome: underlined field, same behavior.
                ColorField("Accent color", selection: $color).fieldStyle(.underlined)
            }
            .padding()
        }
    }
    return Demo()
}
