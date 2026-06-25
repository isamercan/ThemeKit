//
//  Callout.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Organism. Inline status text with a leading icon. More compact than
//  InfoBanner — used to highlight a single line of information.
//  Figma: success / error / info / warning / neutral; plain or soft style.
//

import SwiftUI

public enum CalloutType {
    case neutral, info, success, warning, error

    var accent: Color {
        switch self {
        case .neutral: return Theme.shared.text(.textSecondary)
        case .info: return Theme.shared.foreground(.systemcolorsFgInfo)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        }
    }
    var soft: Color {
        switch self {
        case .neutral: return Theme.shared.background(.bgElevatorPrimary)
        case .info: return Theme.shared.background(.systemcolorsBgInfoLight)
        case .success: return Theme.shared.background(.systemcolorsBgSuccessLight)
        case .warning: return Theme.shared.background(.systemcolorsBgWarningLight)
        case .error: return Theme.shared.background(.systemcolorsBgErrorLight)
        }
    }
    var systemImage: String {
        switch self {
        case .neutral, .info: return "info.circle"
        case .success: return "checkmark.circle"
        case .warning: return "exclamationmark.triangle"
        case .error: return "exclamationmark.circle"
        }
    }
}

public enum CalloutStyle {
    case plain   // transparent, colored icon + text
    case soft    // light tinted surface
}

public struct Callout: View {
    private let text: String
    private let type: CalloutType
    private let style: CalloutStyle

    public init(_ text: String, type: CalloutType = .info, style: CalloutStyle = .plain) {
        self.text = text
        self.type = type
        self.style = style
    }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            Image(systemName: type.systemImage)
                .font(.system(size: 14))
            Text(text)
                .textStyle(.bodySm400)
        }
        .foregroundStyle(type.accent)
        .padding(.horizontal, style == .soft ? Theme.SpacingKey.sm.value : 0)
        .padding(.vertical, style == .soft ? Theme.SpacingKey.xs.value : 0)
        .background {
            if style == .soft {
                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous).fill(type.soft)
            }
        }
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 10) {
        Callout("Lorem ipsum placeholder text.", type: .success)
        Callout("Lorem ipsum placeholder text.", type: .error)
        Callout("Lorem ipsum placeholder text.", type: .info)
        Callout("Lorem ipsum placeholder text.", type: .warning, style: .soft)
        Callout("Lorem ipsum placeholder text.", type: .neutral, style: .soft)
    }
    .padding()
}
