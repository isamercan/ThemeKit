//
//  ButtonSize.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Button sizing driven by spacing + typography tokens. Two density ramps:
//  the default touch-optimized ramp and a compact web/HeroUI ramp.
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

    // MARK: - Regular (touch) ramp — the default; unchanged.

    var height: CGFloat {
        switch self {
        case .xxsmall: return 32
        case .xsmall: return 40
        case .small: return 48
        case .medium: return 56
        case .large: return Theme.SpacingKey.xl4.value   // 64
        }
    }

    var horizontalPadding: CGFloat {
        switch self {
        case .xxsmall: return Theme.SpacingKey.sm.value          // 8
        case .xsmall, .small: return Theme.SpacingKey.md.value   // 16
        case .medium, .large: return Theme.SpacingKey.base.value // 24
        }
    }

    var textStyle: TextStyle {
        switch self {
        case .xxsmall, .xsmall: return .labelSm600
        case .small: return .labelBase600
        case .medium, .large: return .labelMd600
        }
    }

    /// SF Symbol point size for a leading/trailing glyph at this size.
    var fontSize: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return 12
        case .small: return 14
        case .medium, .large: return 16
        }
    }

    // MARK: - Compact (web / HeroUI) ramp — 24 / 28 / 32 / 36 / 40.
    // HeroUI sm(32) · md(36) · lg(40) map to compact small · medium · large;
    // xxsmall/xsmall extend the ramp below the Figma's three sizes.

    var compactHeight: CGFloat {
        switch self {
        case .xxsmall: return 24
        case .xsmall: return 28
        case .small: return 32   // HeroUI sm
        case .medium: return 36  // HeroUI md
        case .large: return 40   // HeroUI lg
        }
    }

    var compactHorizontalPadding: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return Theme.SpacingKey.sm.value        // 8
        case .small, .medium, .large: return Theme.SpacingKey.md.value  // 16
        }
    }

    var compactTextStyle: TextStyle {
        switch self {
        case .xxsmall, .xsmall: return .labelSm600
        case .small, .medium: return .labelBase600
        case .large: return .labelMd600
        }
    }

    var compactFontSize: CGFloat {
        switch self {
        case .xxsmall, .xsmall: return 12
        case .small, .medium: return 14
        case .large: return 16
        }
    }
}
