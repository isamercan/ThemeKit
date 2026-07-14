//
//  ButtonSize.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Button sizing driven by spacing + typography tokens. The scale is the kit's
//  single control-size token — shared by `ThemeButton`, the preset buttons and
//  `ButtonGroup` — so a size added here flows through every one of them. Two
//  density ramps: the default touch-optimized ramp and a compact web/HeroUI ramp.
//

import SwiftUI

/// Height/padding density of a button. `.regular` is the touch-optimized
/// default (44pt-friendly targets); `.compact` is the web/HeroUI density —
/// HeroUI `sm`/`md`/`lg` == compact `small`/`medium`/`large` — for dense
/// toolbars, tables, chips and inline actions.
public enum ButtonDensity: String, CaseIterable {
    case regular, compact
}

public enum ButtonSize: CaseIterable {
    case xxsmall
    case xsmall
    case small
    case medium
    case large
    case xlarge
    case xxlarge

    // MARK: - Regular (touch) ramp — the default.

    /// Control height — a fixed +8 pt ramp (32 … 80); the only genuine
    /// dimension with no single spacing token, so it stays an in-view constant.
    var height: CGFloat {
        switch self {
        case .xxsmall: return 32
        case .xsmall: return 40
        case .small: return 48
        case .medium: return 56
        case .large: return Theme.SpacingKey.xl4.value   // 64
        case .xlarge: return 72
        case .xxlarge: return 80
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .xxsmall: return Theme.SpacingKey.sm.value           // 8
        case .xsmall, .small: return Theme.SpacingKey.md.value    // 16
        case .medium, .large: return Theme.SpacingKey.base.value  // 24
        case .xlarge: return Theme.SpacingKey.lg.value            // 32
        case .xxlarge: return Theme.SpacingKey.xl.value           // 40
        }
    }

    var textStyle: TextStyle {
        switch self {
        case .xxsmall, .xsmall: return .labelSm600
        case .small: return .labelBase600
        case .medium, .large: return .labelMd600
        case .xlarge, .xxlarge: return .labelLg600
        }
    }

    /// SF Symbol point size for a leading/trailing glyph at this size.
    var fontSize: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return 12
        case .small: return 14
        case .medium, .large: return 16
        case .xlarge, .xxlarge: return 18
        }
    }

    // MARK: - Compact (web / HeroUI) ramp — 24 / 28 / 32 / 36 / 40 / 44 / 48.
    // HeroUI sm(32) · md(36) · lg(40) map to compact small · medium · large;
    // xxsmall/xsmall extend the ramp below the Figma's three sizes and
    // xlarge/xxlarge continue the +4 pt step above it.

    var compactHeight: CGFloat {
        switch self {
        case .xxsmall: return 24
        case .xsmall: return 28
        case .small: return 32   // HeroUI sm
        case .medium: return 36  // HeroUI md
        case .large: return 40   // HeroUI lg
        case .xlarge: return 44
        case .xxlarge: return 48
        }
    }

    var compactHorizontalPadding: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return Theme.SpacingKey.sm.value          // 8
        case .small, .medium, .large: return Theme.SpacingKey.md.value    // 16
        case .xlarge, .xxlarge: return Theme.SpacingKey.base.value        // 24
        }
    }

    var compactTextStyle: TextStyle {
        switch self {
        case .xxsmall, .xsmall: return .labelSm600
        case .small, .medium: return .labelBase600
        case .large: return .labelMd600
        case .xlarge, .xxlarge: return .labelLg600
        }
    }

    var compactFontSize: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return 12
        case .small, .medium: return 14
        case .large: return 16
        case .xlarge, .xxlarge: return 18
        }
    }
}
