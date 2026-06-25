//
//  ThemeModel.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Decodable token records + metric token keys. Color keys are generated in
//  ColorTokens.generated.swift. All names are semantic / brand-agnostic.
//

import SwiftUI

extension Theme {

    // MARK: - Decodable token records

    struct AppColor: Codable {
        let name: String
        let hex: String
    }

    struct AppRadius: Codable {
        let name: String
        let radius: CGFloat
    }

    struct AppSpacing: Codable {
        let name: String
        let spacing: CGFloat
    }

    struct AppTypography: Codable {
        let name: String        // matches a `TextStyle` raw value
        let font: String        // family, or "System" / "SystemRounded"
        let size: CGFloat
        let weight: String      // regular / medium / semibold / bold
        let lineHeight: CGFloat
    }

    /// A typography token resolved into a ready-to-use SwiftUI `Font`.
    public struct ResolvedTextStyle {
        public let font: Font
        public let lineSpacing: CGFloat
    }

    struct AppShadow: Codable {
        let name: String        // matches a `ShadowStyle` raw value
        let layers: [AppShadowLayer]
    }

    struct AppShadowLayer: Codable {
        let color: String       // 8-digit RRGGBBAA
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    /// A shadow layer resolved into a ready-to-use SwiftUI drop shadow.
    public struct ResolvedShadowLayer {
        public let color: Color
        public let radius: CGFloat
        public let x: CGFloat
        public let y: CGFloat
    }

    // MARK: - Radius scale

    public enum RadiusKey: String, CaseIterable {
        case none = "radius-none"
        case xs = "rd-xs"
        case sm = "rd-sm"
        case md = "rd-md"
        case base = "rd-base"
        case lg = "rd-lg"
        case xl = "rd-xl"
        case xl4 = "rd-4xl"

        /// Resolved radius from the active theme.
        public var value: CGFloat { Theme.shared.radius(self) }
    }

    // MARK: - Spacing scale

    public enum SpacingKey: String, CaseIterable {
        case none = "spacing-none"
        case xs = "sp-xs"
        case sm = "sp-sm"
        case md = "sp-md"
        case base = "sp-base"
        case lg = "sp-lg"
        case xl = "sp-xl"
        case xl4 = "sp-4xl"

        /// Resolved spacing from the active theme.
        public var value: CGFloat { Theme.shared.spacing(self) }
    }
}
