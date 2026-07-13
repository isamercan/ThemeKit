//
//  ButtonSize.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Button sizing driven by spacing + typography tokens. The scale is the kit's
//  single control-size token — shared by `ThemeButton`, the preset buttons and
//  `ButtonGroup` — so a size added here flows through every one of them.
//

import SwiftUI

public enum ButtonSize: CaseIterable {
    case xxsmall
    case xsmall
    case small
    case medium
    case large
    case xlarge
    case xxlarge

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
}
