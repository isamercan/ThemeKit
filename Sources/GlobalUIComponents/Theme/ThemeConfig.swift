//
//  ThemeConfig.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  The portable "recipe" for a theme — the exact inputs the Theme Configurator
//  produces. A `Codable`, `Sendable` value: serialize it to JSON, ship it as an
//  app resource, and apply it at launch with `Theme.shared.apply(config)`. The
//  full token set is regenerated on-device from these few numbers (no Python, no
//  baked palette files needed). See `ThemeGenerator` / `Theme.apply(_:)`.
//

import Foundation

public struct ThemeConfig: Codable, Equatable, Sendable {
    /// Accent / primary color as a 6-digit RRGGBB hex (no `#`). Drives the whole
    /// palette: primary + info + the neutral ramp tint toward it.
    public var primaryHex: String
    /// 0…0.25 — how strongly the accent bleeds into neutrals / surfaces.
    public var tint: Double
    /// Dark variant.
    public var dark: Bool
    /// Font family: `"Montserrat"` (bundled) or `"System"` / `"SystemRounded"` /
    /// `"SystemSerif"` / `"SystemMono"`, or any custom family registered by the host.
    public var font: String
    /// Multipliers on the base metric ramps.
    public var fontScale: Double
    public var radiusScale: Double
    public var spacingScale: Double
    public var shadowScale: Double

    public init(
        primaryHex: String = "056bfd",
        tint: Double = 0.06,
        dark: Bool = false,
        font: String = "Montserrat",
        fontScale: Double = 1,
        radiusScale: Double = 1,
        spacingScale: Double = 1,
        shadowScale: Double = 1
    ) {
        self.primaryHex = ThemeConfig.normalizeHex(primaryHex)
        self.tint = tint
        self.dark = dark
        self.font = font
        self.fontScale = fontScale
        self.radiusScale = radiusScale
        self.spacingScale = spacingScale
        self.shadowScale = shadowScale
    }

    public static let `default` = ThemeConfig()

    // MARK: JSON portability

    /// Encodes this config to pretty JSON — the artifact the configurator exports.
    public func jsonData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(self)
    }

    /// Decodes a config previously produced by `jsonData()`.
    public init(jsonData: Data) throws {
        self = try JSONDecoder().decode(ThemeConfig.self, from: jsonData)
    }

    private static func normalizeHex(_ hex: String) -> String {
        let s = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        return s.lowercased()
    }
}
