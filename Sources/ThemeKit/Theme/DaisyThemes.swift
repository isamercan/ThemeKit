//
//  DaisyThemes.swift
//  ThemeKit
//  Created by İsa Mercan on 29.06.2026.
//
//  A catalog of themes ported from daisyUI (https://daisyui.com/docs/themes/).
//  Each entry carries daisyUI's signature swatch colors — primary / secondary /
//  accent / base — for previewing, plus a `ThemeConfig` that drives ThemeKit's
//  on-device `ThemeGenerator`: the primary recolors the whole Ant-style palette
//  and the `base` becomes the surface "paper" tone (so cupcake stays cream,
//  cyberpunk stays yellow, dracula stays slate). Apply any of them live with
//  `Theme.shared.apply(daisyTheme.config)`.
//

import SwiftUI

/// A single daisyUI-derived theme: its identity, four signature swatches and the
/// `ThemeConfig` recipe that reproduces it through `ThemeGenerator`.
public struct DaisyTheme: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    /// daisyUI swatch hexes (RRGGBB, no `#`) — shown in the picker.
    public let primary: String
    public let secondary: String
    public let accent: String
    public let base: String
    public let isDark: Bool
    /// How strongly the accent bleeds into neutrals (0 for grayscale themes).
    public let tint: Double

    public init(_ id: String, _ name: String, primary: String, secondary: String,
                accent: String, base: String, dark: Bool = false, tint: Double = 0.05) {
        self.id = id; self.name = name
        self.primary = primary; self.secondary = secondary; self.accent = accent; self.base = base
        self.isDark = dark; self.tint = tint
    }

    /// The recipe that recreates this theme through `ThemeGenerator` — apply it
    /// with `Theme.shared.apply(_:)`.
    public var config: ThemeConfig {
        ThemeConfig(primaryHex: primary, baseHex: base, secondaryHex: secondary,
                    accentHex: accent, tint: tint, dark: isDark)
    }

    /// SwiftUI colors for the four signature swatches (primary, secondary, accent, base).
    public var swatches: [Color] { [primary, secondary, accent, base].map { Color(hex: $0) } }
    public var primaryColor: Color { Color(hex: primary) }
    public var baseColor: Color { Color(hex: base) }

    /// Applies this theme to a `Theme` instance (the shared one by default).
    public func apply(to theme: Theme = .shared) { theme.apply(config) }
}

public extension DaisyTheme {
    /// The full daisyUI theme set, in daisyUI's own order.
    static let all: [DaisyTheme] = [
        .init("light",     "Light",     primary: "422ad5", secondary: "009689", accent: "00d3bb", base: "ffffff"),
        .init("dark",      "Dark",      primary: "605dff", secondary: "f43098", accent: "00d3bb", base: "1d232a", dark: true),
        .init("cupcake",   "Cupcake",   primary: "65c3c8", secondary: "ef9fbc", accent: "eeaf3a", base: "faf7f5", tint: 0.07),
        .init("bumblebee", "Bumblebee", primary: "e0a82e", secondary: "f9d72f", accent: "181830", base: "fffbeb", tint: 0.08),
        .init("emerald",   "Emerald",   primary: "66cc8a", secondary: "377cfb", accent: "ea5234", base: "ffffff"),
        .init("corporate", "Corporate", primary: "4b6bfb", secondary: "7b92b2", accent: "67cba0", base: "ffffff", tint: 0.03),
        .init("synthwave", "Synthwave", primary: "e779c1", secondary: "58c7f3", accent: "f3cc30", base: "1a103c", dark: true, tint: 0.1),
        .init("retro",     "Retro",     primary: "ef9995", secondary: "a4cbb4", accent: "dc8850", base: "ece3ca", tint: 0.1),
        .init("cyberpunk",  "Cyberpunk", primary: "ff7598", secondary: "75d1f0", accent: "c07eec", base: "fff248", tint: 0.06),
        .init("valentine", "Valentine", primary: "e96d7b", secondary: "a991f7", accent: "88dbdd", base: "fae7f4", tint: 0.08),
        .init("halloween", "Halloween", primary: "f28c18", secondary: "6d3a9c", accent: "51a800", base: "212121", dark: true, tint: 0.08),
        .init("garden",    "Garden",    primary: "5c7f67", secondary: "5a5b9f", accent: "ef9fbc", base: "e9e7e7", tint: 0.05),
        .init("forest",    "Forest",    primary: "1eb854", secondary: "1db990", accent: "1db98a", base: "171212", dark: true, tint: 0.08),
        .init("aqua",      "Aqua",      primary: "09ecf3", secondary: "966fb3", accent: "ffe999", base: "345da7", dark: true, tint: 0.1),
        .init("lofi",      "Lo-Fi",     primary: "0d0d0d", secondary: "1a1919", accent: "262626", base: "ffffff", tint: 0),
        .init("pastel",    "Pastel",    primary: "d1c1d7", secondary: "f6cbd1", accent: "b4e9d6", base: "ffffff", tint: 0.06),
        .init("fantasy",   "Fantasy",   primary: "6e0b75", secondary: "0075be", accent: "ff8d05", base: "ffffff", tint: 0.04),
        .init("wireframe", "Wireframe", primary: "b8b8b8", secondary: "b8b8b8", accent: "b8b8b8", base: "ffffff", tint: 0),
        .init("black",     "Black",     primary: "373737", secondary: "373737", accent: "373737", base: "000000", dark: true, tint: 0),
        .init("luxury",    "Luxury",    primary: "d4af37", secondary: "152747", accent: "513448", base: "09090b", dark: true, tint: 0.06),
        .init("dracula",   "Dracula",   primary: "ff79c6", secondary: "bd93f9", accent: "ffb86c", base: "282a36", dark: true, tint: 0.07),
        .init("cmyk",      "CMYK",      primary: "45aeee", secondary: "e8488a", accent: "fff232", base: "ffffff", tint: 0.05),
        .init("autumn",    "Autumn",    primary: "8c0327", secondary: "d85251", accent: "d59b6a", base: "f1f1f1", tint: 0.05),
        .init("business",  "Business",  primary: "1c4e80", secondary: "7c909a", accent: "ea6947", base: "202020", dark: true, tint: 0.06),
        .init("acid",      "Acid",      primary: "ff00f4", secondary: "ff7400", accent: "cbfd03", base: "fafafa", tint: 0.05),
        .init("lemonade",  "Lemonade",  primary: "519903", secondary: "e9e92f", accent: "f7fd03", base: "ffffff", tint: 0.06),
        .init("night",     "Night",     primary: "38bdf8", secondary: "818cf8", accent: "f471b5", base: "0f172a", dark: true, tint: 0.07),
        .init("coffee",    "Coffee",    primary: "db924b", secondary: "6f4e37", accent: "10576d", base: "20161f", dark: true, tint: 0.08),
        .init("winter",    "Winter",    primary: "047aff", secondary: "463aa2", accent: "c148ac", base: "ffffff", tint: 0.04),
        .init("dim",       "Dim",       primary: "9fe88d", secondary: "ff7d5c", accent: "c792e9", base: "2a303c", dark: true, tint: 0.07),
        .init("nord",      "Nord",      primary: "5e81ac", secondary: "81a1c1", accent: "88c0d0", base: "eceff4", tint: 0.06),
        .init("sunset",    "Sunset",    primary: "ff865b", secondary: "fd6f9c", accent: "b387fa", base: "1a1626", dark: true, tint: 0.08),
    ]

    /// Looks up a theme by `id` (e.g. "dracula").
    static func named(_ id: String) -> DaisyTheme? { all.first { $0.id == id } }
}
