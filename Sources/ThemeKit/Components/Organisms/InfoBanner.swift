//
//  InfoBanner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum InfoBannerType {
    case neutral, info, success, warning, error

    var background: Color {
        switch self {
        case .neutral: return Theme.shared.background(.bgElevatorPrimary)
        case .info: return Theme.shared.background(.systemcolorsBgInfoLight)
        case .success: return Theme.shared.background(.systemcolorsBgSuccessLight)
        case .warning: return Theme.shared.background(.systemcolorsBgWarningLight)
        case .error: return Theme.shared.background(.systemcolorsBgErrorLight)
        }
    }

    var accent: Color {
        switch self {
        case .neutral: return Theme.shared.text(.textSecondary)
        case .info: return Theme.shared.foreground(.systemcolorsFgInfo)
        case .success: return Theme.shared.foreground(.systemcolorsFgSuccess)
        case .warning: return Theme.shared.foreground(.systemcolorsFgWarning)
        case .error: return Theme.shared.foreground(.systemcolorsFgError)
        }
    }

    var border: Color {
        switch self {
        case .neutral: return Theme.shared.border(.borderPrimary)
        case .info: return Theme.shared.border(.systemcolorsBorderInfoLight)
        case .success: return Theme.shared.border(.systemcolorsBorderSuccessLight)
        case .warning: return Theme.shared.border(.systemcolorsBorderWarningLight)
        case .error: return Theme.shared.border(.systemcolorsBorderErrorLight)
        }
    }

    var systemImage: String {
        switch self {
        case .neutral, .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "exclamationmark.octagon.fill"
        }
    }
}

/// Improved, token-bound rewrite of the reference InfoMessage. Semantic types
/// drive a light-surface banner with a colored icon, optional title and an
/// optional dismiss action.
public struct InfoBanner: View {
    private let type: InfoBannerType
    private let title: String?
    private let message: String
    private let links: [(substring: String, action: () -> Void)]
    private let showIcon: Bool
    private let banner: Bool
    private let actionTitle: String?
    private let onAction: (() -> Void)?
    private let onDismiss: (() -> Void)?

    public init(
        _ message: String,
        type: InfoBannerType = .info,
        title: String? = nil,
        links: [(substring: String, action: () -> Void)] = [],
        showIcon: Bool = true,
        banner: Bool = false,
        actionTitle: String? = nil,
        onAction: (() -> Void)? = nil,
        onDismiss: (() -> Void)? = nil
    ) {
        self.type = type
        self.title = title
        self.message = message
        self.links = links
        self.showIcon = showIcon
        self.banner = banner
        self.actionTitle = actionTitle
        self.onAction = onAction
        self.onDismiss = onDismiss
    }

    private var radius: CGFloat { banner ? 0 : Theme.RadiusKey.md.value }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            if showIcon {
                Icon(systemName: type.systemImage, size: .sm, color: type.accent)
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(Theme.shared.text(.textPrimary))
                }
                if links.isEmpty {
                    Text(message)
                        .textStyle(.bodySm400)
                        .foregroundStyle(Theme.shared.text(.textSecondary))
                } else {
                    InlineText(message, links: links, baseColor: Theme.shared.text(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle).textStyle(.labelSm600).foregroundStyle(type.accent)
                }
                .buttonStyle(.plain)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Icon(systemName: "xmark", size: .xs, color: Theme.shared.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: banner ? .infinity : nil, alignment: .leading)
        .background(type.background, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(type.border, lineWidth: banner ? 0 : 1)
        )
    }
}

#Preview {
    VStack(spacing: 12) {
        InfoBanner("This is an informational message.", type: .info, title: "Heads up")
        InfoBanner("Your changes were saved.", type: .success)
        InfoBanner("Please double-check this field.", type: .warning)
        InfoBanner("Something went wrong.", type: .error, onDismiss: {})
        InfoBanner("A neutral note.", type: .neutral)
    }
    .padding()
}
