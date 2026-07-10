//
//  ColorSlider.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  An in-canvas single-channel color slider: a token-ringed thumb over a track
//  whose gradient is computed from the bound color. (HeroUI "Color Slider" /
//  `color-slider`.) Unlike `ColorField`, which wraps the *system* color panel,
//  this edits one HSBA channel inline. Controlled-only — it is a value editor.
//

import SwiftUI

public enum ColorSliderTrackHeight: CaseIterable, Sendable {
    case regular, compact
    var value: CGFloat { self == .regular ? 28 : 16 }
}

/// Molecule. Drag the thumb to set one channel of the bound `HSBAColor`.
///
///     @State private var working = HSBAColor(hue: 0.6, saturation: 0.8, brightness: 0.9)
///     ColorSlider(.hue, color: $working)
///     ColorSlider(.alpha, color: $working).trackHeight(.compact)
public struct ColorSlider: View {
    @Environment(\.theme) private var theme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.microAnimations) private var micro
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let channel: ColorChannel
    @Binding private var color: HSBAColor

    // Appearance/config — mutated only through the modifiers below (R2).
    private var trackHeight: ColorSliderTrackHeight = .regular

    @GestureState private var isDragging = false

    private let thumbDiameter: CGFloat = 28
    private var thumbRadius: CGFloat { thumbDiameter / 2 }

    public init(_ channel: ColorChannel, color: Binding<HSBAColor>) {   // R1 — content + binding
        self.channel = channel
        self._color = color
    }

    public var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            ZStack {
                track
                thumb
                    .scaleEffect(isDragging ? 1.15 : 1)
                    .position(x: centerX(for: value, width: width), y: geo.size.height / 2)
                    .animation(motion, value: isDragging)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isDragging) { _, state, _ in state = true }
                    .onChanged { setValue(value(atX: $0.location.x, width: width)) }
            )
        }
        .frame(height: 44)   // A11y: generous hit row; the thumb stays 28pt
        .accessibilityElement()
        .accessibilityLabel(Text(channel.title))
        .accessibilityValue(Text(percentString))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: setValue(value + 0.05)
            case .decrement: setValue(value - 0.05)
            @unknown default: break
            }
        }
    }

    private var motion: Animation? { MicroMotion.animation(.fast, enabled: micro, reduceMotion: reduceMotion) }

    private var track: some View {
        ZStack {
            if channel == .alpha {
                CheckerboardPattern().fill(theme.background(.bgSecondaryLight))
                    .background(theme.background(.bgWhite))
            }
            LinearGradient(colors: trackStops, startPoint: gradientStart, endPoint: gradientEnd)
        }
        .frame(height: trackHeight.value)
        .clipShape(Capsule())
        .overlay(Capsule().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    private var thumb: some View {
        Circle()
            .fill(color.color)
            .frame(width: thumbDiameter, height: thumbDiameter)
            .overlay(Circle().stroke(theme.background(.bgWhite), lineWidth: 2))
            .overlay(Circle().strokeBorder(theme.border(.borderPrimary), lineWidth: 1))
    }

    // MARK: - Channel value plumbing

    private var value: Double {
        switch channel {
        case .hue: return color.hue
        case .saturation: return color.saturation
        case .brightness: return color.brightness
        case .alpha: return color.alpha
        }
    }

    private func setValue(_ raw: Double) {
        let v = HSBAColor.clampUnit(raw)
        switch channel {
        case .hue: color.hue = v
        case .saturation: color.saturation = v
        case .brightness: color.brightness = v
        case .alpha: color.alpha = v
        }
    }

    private var percentString: String { "\(Int((value * 100).rounded()))%" }

    // MARK: - Track gradient

    /// The stops for this channel, evaluated against the *rest* of the bound
    /// color so the track previews the real result of dragging.
    private var trackStops: [Color] {
        switch channel {
        case .hue:
            // Standard full-saturation rainbow (7 fixed stops — no per-pixel resample).
            return stride(from: 0.0, through: 1.0, by: 1.0 / 6.0).map {
                Color(hue: min($0, 0.9999), saturation: 1, brightness: 1)
            }
        case .saturation:
            return [Color(hue: color.hue, saturation: 0, brightness: color.brightness),
                    Color(hue: color.hue, saturation: 1, brightness: color.brightness)]
        case .brightness:
            return [.black, Color(hue: color.hue, saturation: color.saturation, brightness: 1)]
        case .alpha:
            let base = Color(hue: color.hue, saturation: color.saturation, brightness: color.brightness)
            return [base.opacity(0), base]
        }
    }

    // MARK: - Geometry (absolute coords; RTL flipped by hand so track + thumb agree)

    private var isRTL: Bool { layoutDirection == .rightToLeft }
    private var gradientStart: UnitPoint { isRTL ? .trailing : .leading }
    private var gradientEnd: UnitPoint { isRTL ? .leading : .trailing }

    private func centerX(for v: Double, width: CGFloat) -> CGFloat {
        let usable = max(width - thumbDiameter, 1)
        let ltr = thumbRadius + CGFloat(v) * usable
        return isRTL ? width - ltr : ltr
    }

    private func value(atX x: CGFloat, width: CGFloat) -> Double {
        let usable = max(width - thumbDiameter, 1)
        let ltr = Double((x - thumbRadius) / usable)
        return HSBAColor.clampUnit(isRTL ? 1 - ltr : ltr)
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ColorSlider {
    /// Track thickness — `.regular` (28pt, default) or `.compact` (16pt).
    func trackHeight(_ h: ColorSliderTrackHeight) -> Self { copy { $0.trackHeight = h } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    struct Demo: View {
        @State var working = HSBAColor(hue: 0.6, saturation: 0.8, brightness: 0.9)
        var body: some View {
            VStack(spacing: Theme.SpacingKey.md.value) {
                RoundedRectangle(cornerRadius: 12).fill(working.color).frame(height: 60)
                ColorSlider(.hue, color: $working)
                ColorSlider(.saturation, color: $working)
                ColorSlider(.brightness, color: $working)
                ColorSlider(.alpha, color: $working).trackHeight(.compact)
            }
            .padding()
        }
    }
    return Demo()
}
