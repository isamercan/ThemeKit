//
//  Color+Extensions.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

public extension Color {
    /// Linearly blends this color toward `other` by `fraction` (0…1) in sRGB.
    /// Lets a component derive an intermediate surface from two existing theme
    /// tokens (e.g. a tinted card-surface = white blended with the page tint)
    /// without introducing a new global token — the result still re-skins,
    /// because both endpoints are theme tokens.
    func blended(with other: Color, by fraction: Double) -> Color {
        let f = min(max(fraction, 0), 1)
        let a = sRGBAComponents, b = other.sRGBAComponents
        return Color(.sRGB,
                     red: a.r + (b.r - a.r) * f,
                     green: a.g + (b.g - a.g) * f,
                     blue: a.b + (b.b - a.b) * f,
                     opacity: a.o + (b.o - a.o) * f)
    }

    /// sRGB components (0…1). Resolves the color on the current platform.
    private var sRGBAComponents: (r: Double, g: Double, b: Double, o: Double) {
        #if canImport(UIKit)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, o: CGFloat = 0
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o)
        return (Double(r), Double(g), Double(b), Double(o))
        #elseif canImport(AppKit)
        let c = NSColor(self).usingColorSpace(.sRGB) ?? .clear
        return (Double(c.redComponent), Double(c.greenComponent), Double(c.blueComponent), Double(c.alphaComponent))
        #else
        return (0, 0, 0, 1)
        #endif
    }

    /// Creates a color from a hex string (with or without a leading `#`).
    /// Supports `RRGGBB` (6 digits) and `RRGGBBAA` (8 digits, trailing alpha).
    /// Invalid input resolves to `.clear`.
    init(hex: String, opacity: Double? = nil) {
        var hex = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex

        // RRGGBBAA → pull alpha out, keep RRGGBB.
        var parsedAlpha: Double?
        if hex.count == 8, let value = UInt64(hex, radix: 16) {
            parsedAlpha = Double(value & 0x0000_00FF) / 255.0
            hex = String(format: "%06X", (value & 0xFFFF_FF00) >> 8)
        }

        guard hex.count == 6, let rgb = UInt64(hex, radix: 16) else {
            self.init(.clear)
            return
        }

        let red = Double((rgb & 0xFF0000) >> 16) / 255.0
        let green = Double((rgb & 0x00FF00) >> 8) / 255.0
        let blue = Double(rgb & 0x0000FF) / 255.0

        self.init(red: red, green: green, blue: blue, opacity: opacity ?? parsedAlpha ?? 1.0)
    }
}
