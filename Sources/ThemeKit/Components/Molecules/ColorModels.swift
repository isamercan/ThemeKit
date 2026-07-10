//
//  ColorModels.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  The working currency of the custom color components (ColorSlider, ColorArea,
//  ColorPickerPanel). SwiftUI's `Color` can't be decomposed portably, so the
//  kit carries its own hue/saturation/brightness/alpha value and bridges to
//  `Color` at the edges.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

/// Hue / saturation / brightness / alpha, each in `0…1`. All four channels are
/// clamped on assignment; hue is additionally kept below `1.0` so a full turn
/// doesn't wrap the thumb back to red. Bridge to `Color` via `color`, and from
/// a `Color` via `init(_:)`.
public struct HSBAColor: Equatable, Sendable {
    public var hue: Double { didSet { hue = Self.clampHue(hue) } }
    public var saturation: Double { didSet { saturation = Self.clampUnit(saturation) } }
    public var brightness: Double { didSet { brightness = Self.clampUnit(brightness) } }
    public var alpha: Double { didSet { alpha = Self.clampUnit(alpha) } }

    public init(hue: Double, saturation: Double, brightness: Double, alpha: Double = 1) {
        self.hue = Self.clampHue(hue)
        self.saturation = Self.clampUnit(saturation)
        self.brightness = Self.clampUnit(brightness)
        self.alpha = Self.clampUnit(alpha)
    }

    /// Decomposes a `Color` into HSBA via the platform color. Dynamic/catalog
    /// colors that can't be resolved to RGB fall back to opaque white rather
    /// than trapping (`getHue` returns `false` and the defaults stand).
    public init(_ color: Color) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 1, a: CGFloat = 1
        #if canImport(UIKit)
        UIColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        #elseif canImport(AppKit)
        // Catalog colors trap in `getHue` unless converted to an RGB space first.
        if let rgb = NSColor(color).usingColorSpace(.deviceRGB) {
            rgb.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        }
        #endif
        self.init(hue: Double(h), saturation: Double(s), brightness: Double(b), alpha: Double(a))
    }

    /// The SwiftUI color for these channels.
    public var color: Color {
        Color(hue: hue, saturation: saturation, brightness: brightness, opacity: alpha)
    }

    /// The fully-opaque, full-value hue — the pure spectral color used as the
    /// base of saturation/brightness surfaces.
    public var pureHue: Color { Color(hue: hue, saturation: 1, brightness: 1) }

    static func clampUnit(_ v: Double) -> Double { min(max(v, 0), 1) }
    static func clampHue(_ v: Double) -> Double { min(max(v, 0), 0.9999) }
}

/// The four editable channels of an `HSBAColor`.
public enum ColorChannel: CaseIterable, Sendable {
    case hue, saturation, brightness, alpha

    /// Spoken/display name.
    public var title: String {
        switch self {
        case .hue: return String(themeKit: "Hue")
        case .saturation: return String(themeKit: "Saturation")
        case .brightness: return String(themeKit: "Brightness")
        case .alpha: return String(themeKit: "Opacity")
        }
    }
}

/// The alpha-indicator checkerboard shared by the color components: fixed 4pt
/// cells (genuine geometry) drawn as one path of the "on" cells, painted over a
/// white underlay so translucent colors read as translucent.
struct CheckerboardPattern: Shape {
    var cell: CGFloat = 4
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let cols = Int(ceil(rect.width / cell))
        let rows = Int(ceil(rect.height / cell))
        for row in 0..<max(rows, 0) {
            for col in 0..<max(cols, 0) where (row + col).isMultiple(of: 2) {
                path.addRect(CGRect(x: CGFloat(col) * cell, y: CGFloat(row) * cell, width: cell, height: cell))
            }
        }
        return path
    }
}
