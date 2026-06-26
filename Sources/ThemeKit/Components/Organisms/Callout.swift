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
    private let showIcon: Bool
    private let actionTitle: String?
    private let onAction: (() -> Void)?
    private let onClose: (() -> Void)?

    public init(
        _ text: String,
        type: CalloutType = .info,
        style: CalloutStyle = .plain,
        showIcon: Bool = true,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.text = text
        self.type = type
        self.style = style
        self.showIcon = showIcon
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.onClose = onClose
    }

    private var hasAction: Bool { actionTitle != nil && onAction != nil }
    private var hasTrailing: Bool { hasAction || onClose != nil }

    public var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Theme.SpacingKey.xs.value) {
            if showIcon {
                Image(systemName: type.systemImage)
                    .font(.system(size: 14))
            }
            Text(text)
                .textStyle(.bodySm400)
            if hasTrailing {
                Spacer(minLength: Theme.SpacingKey.sm.value)
                if let actionTitle, let onAction {
                    Button(action: onAction) {
                        Text(actionTitle).textStyle(.labelSm600)
                    }
                    .buttonStyle(.plain)
                }
                if let onClose {
                    Button(action: onClose) {
                        Image(systemName: "xmark").font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(String(themeKit: "Dismiss"))
                }
            }
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
