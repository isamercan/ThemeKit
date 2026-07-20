//
//  ColorPickerPanel.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The full custom color picker: `ColorArea` + hue/alpha `ColorSlider`s, an
//  optional preset-swatch row and a two-way hex field, on one surface. (HeroUI
//  `color-picker` / `color-input-group`.) Apps present it in a `.themePopover`
//  or `BottomSheet` themselves — this is the panel, not the trigger.
//

import SwiftUI

/// Organism. `ColorPickerPanel(color: $hsba)` binds an `HSBAColor`.
public struct ColorPickerPanel: View {
    @Environment(\.theme) private var theme

    @Binding private var color: HSBAColor

    // Appearance/config — mutated only through the modifiers below (R2).
    private var showsAlpha = true
    private var showsHexField = true
    private var swatches: [ColorSwatchItem] = []

    @State private var hexDraft = ""
    @State private var swatchSelection: ColorSwatchItem?

    public init(color: Binding<HSBAColor>) {   // R1 — content binding
        self._color = color
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: Theme.SpacingKey.md.value) {
            ColorArea(color: $color)
            ColorSlider(.hue, color: $color)
            if showsAlpha {
                ColorSlider(.alpha, color: $color).trackHeight(.compact)
            }
            if !swatches.isEmpty {
                ColorSwatchPicker(swatches, selection: $swatchSelection)
                    .onChange(of: swatchSelection) {
                        if let picked = swatchSelection { color = HSBAColor(picked.color) }
                    }
            }
            if showsHexField {
                hexRow
            }
        }
        .onAppear { hexDraft = HexColor.string(color) }
        .onChange(of: color) { hexDraft = HexColor.string(color) }
    }

    private var hexRow: some View {
        HStack(spacing: Theme.SpacingKey.sm.value) {
            ColorSwatch(color.color, label: String(themeKit: "Current color")).size(.medium)
            Text("#").textStyle(.labelBase600).foregroundStyle(theme.text(.textTertiary))
            TextField("RRGGBB", text: $hexDraft)
                .textStyle(.bodyBase400)
                .foregroundStyle(theme.text(.textPrimary))
                .autocorrectionDisabled()
                .onSubmit(commitHex)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .padding(.vertical, Theme.SpacingKey.xs.value)
        .background(theme.background(.bgSecondaryLight), in: RoundedRectangle(cornerRadius: Theme.RadiusRole.field.value, style: .continuous))
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text(String(themeKit: "Hex color")))
    }

    private func commitHex() {
        if let parsed = HexColor.hsba(fromHex: hexDraft, alpha: color.alpha) {
            color = parsed
        } else {
            hexDraft = HexColor.string(color)   // reject invalid input, restore
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorPickerPanel {
    /// Show the alpha slider (default on).
    func showsAlpha(_ on: Bool = true) -> Self { copy { $0.showsAlpha = on } }

    /// Show the two-way hex field (default on).
    func showsHexField(_ on: Bool = true) -> Self { copy { $0.showsHexField = on } }

    /// A preset-swatch row; tapping one sets the working color.
    func swatches(_ items: [ColorSwatchItem]) -> Self { copy { $0.swatches = items } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

// MARK: - HSB ↔ RGB ↔ hex (deterministic; no platform color round-trip)

/// Pure hex conversion for the panel's field — internal so it can be unit-tested
/// without a platform color round-trip.
enum HexColor {
    static func string(_ c: HSBAColor) -> String {
        let rgb = hsbToRGB(c)
        let r = Int((rgb.r * 255).rounded()), g = Int((rgb.g * 255).rounded()), b = Int((rgb.b * 255).rounded())
        return String(format: "%02X%02X%02X", r, g, b)
    }

    static func hsba(fromHex raw: String, alpha: Double) -> HSBAColor? {
        var hex = raw.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = Int(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        let hsb = rgbToHSB(r: r, g: g, b: b)
        return HSBAColor(hue: hsb.h, saturation: hsb.s, brightness: hsb.v, alpha: alpha)
    }

    private static func hsbToRGB(_ c: HSBAColor) -> (r: Double, g: Double, b: Double) {
        let s = c.saturation, v = c.brightness
        if s == 0 { return (v, v, v) }
        let h = (c.hue >= 1 ? 0 : c.hue) * 6
        let i = Int(h)
        let f = h - Double(i)
        let p = v * (1 - s)
        let q = v * (1 - s * f)
        let t = v * (1 - s * (1 - f))
        switch i {
        case 0: return (v, t, p)
        case 1: return (q, v, p)
        case 2: return (p, v, t)
        case 3: return (p, q, v)
        case 4: return (t, p, v)
        default: return (v, p, q)
        }
    }

    private static func rgbToHSB(r: Double, g: Double, b: Double) -> (h: Double, s: Double, v: Double) {
        let maxV = max(r, g, b), minV = min(r, g, b)
        let delta = maxV - minV
        var h = 0.0
        if delta != 0 {
            if maxV == r { h = ((g - b) / delta).truncatingRemainder(dividingBy: 6) }
            else if maxV == g { h = (b - r) / delta + 2 }
            else { h = (r - g) / delta + 4 }
            h /= 6
            if h < 0 { h += 1 }
        }
        let s = maxV == 0 ? 0 : delta / maxV
        return (h, s, maxV)
    }
}

#Preview {
    struct Demo: View {
        @State var color = HSBAColor(hue: 0.55, saturation: 0.8, brightness: 0.9)
        var body: some View {
            PreviewMatrix("ColorPickerPanel") {
                PreviewCase("Full (swatches + hex)") {
                    VStack(spacing: 24) {
                        ColorPickerPanel(color: $color)
                            .swatches([
                                .init(.red, label: "Red"), .init(.orange, label: "Orange"),
                                .init(.green, label: "Green"), .init(.blue, label: "Blue"),
                                .init(.purple, label: "Purple"), .init(.black, label: "Ink"),
                            ])
                        RoundedRectangle(cornerRadius: 12).fill(color.color).frame(height: 44)
                    }
                }
                PreviewCase("Minimal (no alpha, no hex)") {
                    ColorPickerPanel(color: $color)
                        .showsAlpha(false)
                        .showsHexField(false)
                }
            }
        }
    }
    return Demo()
}
