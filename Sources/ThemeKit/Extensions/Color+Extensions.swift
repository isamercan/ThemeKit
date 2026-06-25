//
//  Color+Extensions.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public extension Color {
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
