//
//  AspectRatio.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Aspect-ratio tokens from the Figma design system.
//

import SwiftUI

public enum AspectRatioToken: String, CaseIterable {
    case square = "1:1"
    case portrait1x2 = "1:2"
    case landscape2x1 = "2:1"
    case portrait2x3 = "2:3"
    case landscape3x2 = "3:2"
    case landscape3x1 = "3:1"
    case landscape4x1 = "4:1"
    case portrait3x4 = "3:4"
    case landscape4x3 = "4:3"
    case portrait9x16 = "9:16"
    case portrait10x16 = "10:16"
    case landscape16x9 = "16:9"
    case landscape16x10 = "16:10"

    /// width / height
    public var ratio: CGFloat {
        let parts = rawValue.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 2, parts[1] != 0 else { return 1 }
        return CGFloat(parts[0] / parts[1])
    }
}

public extension View {
    /// Constrains the view to a design-system aspect ratio.
    func aspectRatioToken(_ token: AspectRatioToken, contentMode: ContentMode = .fit) -> some View {
        aspectRatio(token.ratio, contentMode: contentMode)
    }
}
