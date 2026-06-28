//
//  InfoBanner.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum InfoBannerType {
    case neutral, info, success, warning, error

    func background(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.background(.bgElevatorPrimary)
        case .info: return theme.background(.systemcolorsBgInfoLight)
        case .success: return theme.background(.systemcolorsBgSuccessLight)
        case .warning: return theme.background(.systemcolorsBgWarningLight)
        case .error: return theme.background(.systemcolorsBgErrorLight)
        }
    }

    func accent(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.text(.textSecondary)
        case .info: return theme.foreground(.systemcolorsFgInfo)
        case .success: return theme.foreground(.systemcolorsFgSuccess)
        case .warning: return theme.foreground(.systemcolorsFgWarning)
        case .error: return theme.foreground(.systemcolorsFgError)
        }
    }

    func border(_ theme: Theme) -> Color {
        switch self {
        case .neutral: return theme.border(.borderPrimary)
        case .info: return theme.border(.systemcolorsBorderInfoLight)
        case .success: return theme.border(.systemcolorsBorderSuccessLight)
        case .warning: return theme.border(.systemcolorsBorderWarningLight)
        case .error: return theme.border(.systemcolorsBorderErrorLight)
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
    @Environment(\.theme) private var theme

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
                Icon(systemName: type.systemImage, size: .sm, color: type.accent(theme))
            }

            VStack(alignment: .leading, spacing: 2) {
                if let title {
                    Text(title)
                        .textStyle(.labelBase600)
                        .foregroundStyle(theme.text(.textPrimary))
                }
                if links.isEmpty {
                    Text(message)
                        .textStyle(.bodySm400)
                        .foregroundStyle(theme.text(.textSecondary))
                } else {
                    InlineText(message, links: links, baseColor: theme.text(.textSecondary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let actionTitle, let onAction {
                Button(action: onAction) {
                    Text(actionTitle).textStyle(.labelSm600).foregroundStyle(type.accent(theme))
                }
                .buttonStyle(.plain)
            }

            if let onDismiss {
                Button(action: onDismiss) {
                    Icon(systemName: "xmark", size: .xs, color: theme.text(.textTertiary))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Theme.SpacingKey.md.value)
        .frame(maxWidth: banner ? .infinity : nil, alignment: .leading)
        .background(type.background(theme), in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: radius, style: .continuous)
                .stroke(type.border(theme), lineWidth: banner ? 0 : 1)
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
