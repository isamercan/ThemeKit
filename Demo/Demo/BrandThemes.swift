//
//  BrandThemes.swift
//  Demo
//
//  Brand themes distilled from the exported Figma *component token* files
//  (💠 Component Tokens/ETS.tokens.json, UB.tokens.json). Each file's `modeName`
//  becomes a theme whose brand seeds, font family and card radius drive ThemeKit's
//  on-device `ThemeGenerator`.
//
//  Why a full `ThemeConfig` (and not just a `ThemePreset`)? A `ThemePreset` only
//  carries the four brand swatches — it can't express the token files' `Font`
//  (Poppins / Outfit) or their `Card Radius` (16 → box default, 24 → 1.5×). So we
//  keep a `ThemePreset` purely for the picker swatch card, and apply the richer
//  `ThemeConfig` on tap via `DemoThemeStore.applyGenerated(_:)`.
//
//  Note: the token families (Poppins, Outfit) are NOT bundled/registered by the
//  demo, so SwiftUI falls back to the system font for the type ramp — the color +
//  radius identity still applies. Register the .ttf + `UIAppFonts` in the host to
//  render the real families.
//

import Foundation
import ThemeKit

/// A brand theme sourced from a Figma component-token export: a `ThemePreset`
/// for the picker swatch, plus the full `ThemeConfig` recipe (brand seeds + font
/// + radius) that actually re-skins the app.
struct BrandTheme: Identifiable {
    /// Swatch/identity card shown in the `ThemePicker` grid.
    let preset: ThemePreset
    /// The full recipe applied on tap (captures font + radiusScale too).
    let config: ThemeConfig
    var id: String { preset.id }
    var name: String { preset.name }
}

extension BrandTheme {
    /// ETS — from `ETS.tokens.json` (`modeName: "ETS"`).
    /// Hero blue #056BFD on a white surface, Poppins, 16pt card radius (= box default).
    static let ets = BrandTheme(
        preset: ThemePreset(
            "ets", "Etstur (ETS)",
            primary: "056bfd",   // Button/Background/Primary-Default · bg-hero
            secondary: "3789fd", // Primary-Hover · bg-hero-hover
            accent: "0561e6",    // Primary-Pressed · bg-hero-pressing
            base: "ffffff",      // Tertiary-Default · white surface
            tint: 0.06
        ),
        config: ThemeConfig(
            primaryHex: "056bfd",
            baseHex: "ffffff",
            secondaryHex: "3789fd",
            accentHex: "0561e6",
            tint: 0.06,
            dark: false,
            font: "Poppins",     // Font/Family/Etstur Font
            radiusScale: 1.0     // Card Radius 16 == box default (rd-md)
        )
    )

    /// UB — from `UB.tokens.json` (`modeName: "UB"`).
    /// Near-black brand #00121C with a #008CFF link accent on white, Outfit,
    /// 24pt card radius (= 1.5× the 16pt box default).
    static let ub = BrandTheme(
        preset: ThemePreset(
            "ub", "UB",
            primary: "00121c",   // Button/Background/Primary-Default
            secondary: "334d5c", // Primary-Hover · slate
            accent: "008cff",    // Button/Text/Tertiary-Default · link
            base: "ffffff",      // Secondary-Default · white surface
            tint: 0.05
        ),
        config: ThemeConfig(
            primaryHex: "00121c",
            baseHex: "ffffff",
            secondaryHex: "334d5c",
            accentHex: "008cff",
            tint: 0.05,
            dark: false,
            font: "Outfit",      // Font/Family/UB Font
            radiusScale: 1.5     // Card Radius 24 / box default 16
        )
    )

    /// All brand themes, in the order they appear in the picker.
    static let all: [BrandTheme] = [.ets, .ub]

    /// The `ThemePreset` swatch cards for the picker grid.
    static var presets: [ThemePreset] { all.map(\.preset) }

    /// Looks up a brand theme whose recipe matches an active `ThemeConfig`
    /// (used to highlight the selected card after apply / relaunch).
    static func matching(_ config: ThemeConfig?) -> BrandTheme? {
        guard let config else { return nil }
        return all.first { $0.config == config }
    }
}
