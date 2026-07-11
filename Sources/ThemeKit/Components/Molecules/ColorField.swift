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
    @Environment(\.fieldDefaults) private var fieldDefaults
    @Environment(\.isEnabled) private var isEnabled   // R3 — set natively by `.disabled(_:)`
    /// Read-only subtree axis (set with `.readOnly(_:)`) — normal chrome, no editing.
    @Environment(\.isReadOnly) private var isReadOnly

    private let label: String
    @Binding private var selection: Color

    // Appearance — mutated only through the modifiers below (R2).
    private var supportsOpacity: Bool = true
    /// Explicit `.size(_:)` preset — wins over the subtree `FieldDefaults.size`.
    private var explicitSize: TextInputSize?

    public init(_ label: String, selection: Binding<Color>) {   // R1 — content + binding
        self.label = label
        self._selection = selection
    }

    /// Explicit `.size(_:)` → subtree `FieldDefaults.size` → the classic 52pt.
    private var effectiveSize: TextInputSize? { explicitSize ?? fieldDefaults.size }

    /// The field chrome is delegated to the active ``FieldStyle``. Mapping: the
    /// system color well never drives keyboard focus, so `isFocused` is always
    /// `false`; there is no validation axis, so `hasError`/`hasWarning` are
    /// `false`. With no explicit `.size(_:)` and no subtree `FieldDefaults.size`
    /// the row keeps its classic scaled 52pt height (nominal `.medium`).
    public var body: some View {
        fieldStyle.makeBody(configuration: FieldStyleConfiguration(
            content: AnyView(row),
            isFocused: false,
            isEnabled: isEnabled,
            hasError: false,
            hasWarning: false,
            size: effectiveSize ?? .medium
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
                // Read-only keeps the swatch + normal chrome but never opens
                // the system picker (E1 — distinct from `.disabled`).
                .allowsHitTesting(!isReadOnly)
                .accessibilityLabel(label)
        }
        .padding(.horizontal, Theme.SpacingKey.md.value)
        // Scales with Dynamic Type (G2); a size preset remaps the height (C1).
        .scaledControlHeight(effectiveSize?.height ?? 52)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorField {
    /// Whether the color well lets the user adjust opacity (defaults to true).
    func supportsOpacity(_ on: Bool = true) -> Self { copy { $0.supportsOpacity = on } }

    /// Control-height preset. An explicit size wins over the subtree
    /// `FieldDefaults.size` default (`explicit ?? fieldDefaults.size ?? 52pt`).
    func size(_ s: TextInputSize) -> Self { copy { $0.explicitSize = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    // The system color well opens an interactive panel; each cell shows the
    // field chrome as a single static frame.
    PreviewMatrix("ColorField") {
        PreviewCase("Default") { ColorField("Brand color", selection: .constant(.blue)) }
        // Swapped chrome: underlined field, same behavior.
        PreviewCase("Underlined chrome") { ColorField("Accent color", selection: .constant(.blue)).fieldStyle(.underlined) }
        // Size ramp — explicit `.size(_:)` wins over `FieldDefaults.size`.
        PreviewCase("Small") { ColorField("Small", selection: .constant(.blue)).size(.small) }
        PreviewCase("Large") { ColorField("Large", selection: .constant(.blue)).size(.large) }
        // Read-only: swatch + normal chrome, picker suppressed (E1).
        PreviewCase("Read-only") { ColorField("Theme color (read-only)", selection: .constant(.blue)).readOnly() }
        PreviewCase("Disabled") { ColorField("Disabled", selection: .constant(.blue)).disabled(true) }
    }
}
