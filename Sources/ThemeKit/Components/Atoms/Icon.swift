//
//  Icon.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum IconSize: String, CaseIterable {
    case xs, sm, md, lg, xl

    /// Point size, aligned with the type scale.
    public var value: CGFloat {
        switch self {
        case .xs: return 12
        case .sm: return 16
        case .md: return 20
        case .lg: return 24
        case .xl: return 32
        }
    }

    /// Font for a Font-Awesome glyph at this size (when the FA font is bundled).
    public func font(weight: Font.Weight = .regular) -> Font {
        Font.system(size: value, weight: weight)
    }
}

/// Icon system. The Figma design system uses Font Awesome Pro, which is a
/// licensed font and cannot be bundled here. `Icon` renders an SF Symbol by
/// default; to switch to Font Awesome, bundle the FA Pro `.ttf` and render a
/// glyph with `IconSize.font` instead.
public struct Icon: View {
    private let systemName: String
    private let size: IconSize
    private let color: Color?

    /// Renders an SF Symbol at a token size. Pass a theme color, or `nil` to
    /// inherit the surrounding `foregroundStyle`.
    public init(systemName: String, size: IconSize = .md, color: Color? = nil) {
        self.systemName = systemName
        self.size = size
        self.color = color
    }

    public var body: some View {
        Image(systemName: systemName)
            .font(.system(size: size.value))
            .foregroundStyle(color ?? Color.primary)
    }
}

#Preview {
    HStack(spacing: 12) {
        ForEach(IconSize.allCases, id: \.self) { s in
            Icon(systemName: "star.fill", size: s, color: Theme.shared.foreground(.fgHero))
        }
    }
    .padding()
}
