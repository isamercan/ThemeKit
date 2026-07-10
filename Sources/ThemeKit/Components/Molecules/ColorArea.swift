//
//  ColorArea.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The 2D saturation × brightness plane for the bound color's hue — the piece
//  between `ColorSlider` and a full picker. (HeroUI "Color Area" / `color-area`.)
//  Rendered as two layered gradients (white → hue horizontal, transparent →
//  black vertical), so no per-pixel canvas work. Controlled-only value editor.
//

import SwiftUI

/// Molecule. Drag anywhere on the plane to set the bound color's saturation
/// (horizontal) and brightness (vertical); hue and alpha are read, not changed.
///
///     @State private var working = HSBAColor(hue: 0.08, saturation: 0.9, brightness: 0.95)
///     ColorArea(color: $working).cornerRadius(.box)
///     ColorSlider(.hue, color: $working)
public struct ColorArea: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding private var color: HSBAColor

    // Appearance/config — mutated only through the modifiers below (R2).
    private var cornerRole: Theme.RadiusRole = .field

    @GestureState private var isDragging = false

    private let thumbDiameter: CGFloat = 28
    private var thumbRadius: CGFloat { thumbDiameter / 2 }

    public init(color: Binding<HSBAColor>) {   // R1 — content + binding
        self._color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let shape = RoundedRectangle(cornerRadius: cornerRole.value(cappedFor: size.height), style: .continuous)
            ZStack {
                plane
                thumb
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .position(thumbCenter(in: size))
                    .animation(motion, value: isDragging)
            }
            .clipShape(shape)
            .overlay(shape.strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { update(at: $0.location, in: size) }
            )
        }
        .aspectRatio(4.0 / 3.0, contentMode: .fit)
        .accessibilityElement()
        .accessibilityLabel(Text(String(themeKit: "Saturation and brightness")))
        .accessibilityValue(Text(valueDescription))
        // The vertical (brightness) axis is the adjustable one; saturation gets
        // two named actions — the shape VoiceOver users get on system color panes.
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: color.brightness += 0.05
            case .decrement: color.brightness -= 0.05
            @unknown default: break
            }
        }
        .accessibilityAction(named: Text(String(themeKit: "Increase saturation"))) { color.saturation += 0.05 }
        .accessibilityAction(named: Text(String(themeKit: "Decrease saturation"))) { color.saturation -= 0.05 }
    }

    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    /// Full-hue base, washed white horizontally (saturation) and black
    /// vertically (brightness), composited as one group so dark-mode blending
    /// doesn't shift the rendered color.
    private var plane: some View {
        ZStack {
            color.pureHue
            LinearGradient(colors: [.white, .white.opacity(0)], startPoint: saturationStart, endPoint: saturationEnd)
            LinearGradient(colors: [.black.opacity(0), .black], startPoint: .top, endPoint: .bottom)
        }
        .compositingGroup()
    }

    private var thumb: some View {
        Circle()
            .fill(color.color)
            .frame(width: thumbDiameter, height: thumbDiameter)
            .overlay(Circle().stroke(theme.background(.bgWhite), lineWidth: 2))
            .overlay(Circle().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    // MARK: - Geometry (absolute coords; saturation flips under RTL, brightness never)

    private var isRTL: Bool { layoutDirection == .rightToLeft }
    private var saturationStart: UnitPoint { isRTL ? .trailing : .leading }
    private var saturationEnd: UnitPoint { isRTL ? .leading : .trailing }

    private func thumbCenter(in size: CGSize) -> CGPoint {
        let usableW = max(size.width - thumbDiameter, 1)
        let usableH = max(size.height - thumbDiameter, 1)
        let ltrX = thumbRadius + CGFloat(color.saturation) * usableW
        let x = isRTL ? size.width - ltrX : ltrX
        let y = thumbRadius + CGFloat(1 - color.brightness) * usableH   // top = bright
        return CGPoint(x: x, y: y)
    }

    private func update(at point: CGPoint, in size: CGSize) {
        let usableW = max(size.width - thumbDiameter, 1)
        let usableH = max(size.height - thumbDiameter, 1)
        let ltrX = Double((point.x - thumbRadius) / usableW)
        color.saturation = HSBAColor.clampUnit(isRTL ? 1 - ltrX : ltrX)
        let normalizedY = Double((point.y - thumbRadius) / usableH)
        color.brightness = HSBAColor.clampUnit(1 - normalizedY)
    }

    private var valueDescription: String {
        let s = Int((color.saturation * 100).rounded())
        let b = Int((color.brightness * 100).rounded())
        return String(themeKit: "\(s)% saturation, \(b)% brightness")
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorArea {
    /// Corner rounding, token-typed — default `.field`; capped to the plane
    /// height so a large role never over-rounds a short area.
    func cornerRadius(_ role: Theme.RadiusRole) -> Self { copy { $0.cornerRole = role } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var working = HSBAColor(hue: 0.08, saturation: 0.9, brightness: 0.95)
        var body: some View {
            VStack(spacing: Theme.SpacingKey.md.value) {
                ColorArea(color: $working).cornerRadius(.box)
                ColorSlider(.hue, color: $working)
                RoundedRectangle(cornerRadius: 12).fill(working.color).frame(height: 44)
            }
            .padding()
        }
    }
    return Demo()
}
