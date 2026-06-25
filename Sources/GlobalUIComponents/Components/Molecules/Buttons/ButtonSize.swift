//
//  ButtonSize.swift
//  GlobalUIComponents
//  Created by İsa Mercan on 23.06.2026.
//
//  Button sizing driven by spacing + typography tokens.
//

import SwiftUI

public enum ButtonSize: CaseIterable {
    case xxsmall
    case xsmall
    case small
    case medium
    case large

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
}
