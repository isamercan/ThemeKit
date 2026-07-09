//
//  ThemeModel.swift
//  ThemeKit
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

    /// Semantic radius *roles* (daisyUI parity: `--radius-box / -field / -selector`).
    /// Name a corner by the component's *role* instead of a fixed size, so a theme
    /// can re-round a whole category at once — every box, every field, every
    /// selector — from one token. A theme that omits the role token falls back to
    /// the matching size key (so existing/bundled themes are unaffected).
    public enum RadiusRole: String, CaseIterable {
        /// Cards, modals, sheets, alerts — the large container corner.
        case box = "radius-box"
        /// Buttons, inputs, selects, tabs — the medium control corner.
        case field = "radius-field"
        /// Checkboxes, toggles, badges, small chips — the tight corner.
        case selector = "radius-selector"

        /// Size key used when a theme doesn't define this role token.
        public var fallback: RadiusKey {
            switch self {
            case .box: return .md          // 16
            case .field: return .sm        // 8
            case .selector: return .xs     // 6
            }
        }

        /// Resolved radius from the active theme (role token, else the fallback size).
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
