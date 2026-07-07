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
        case .neutral: return theme.background(.bgBase)
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

    // Appearance/state — mutated only through the modifiers below (R2).
    private var type: InfoBannerType = .info
    private var showIcon = true
    private var banner = false
    private var actionTitle: String?
    private var onAction: (() -> Void)?
    private var onDismiss: (() -> Void)?

    private let message: String
    private let title: String?
    private let links: [(substring: String, action: () -> Void)]

    public init(
        _ message: String,
        title: String? = nil,
        links: [(substring: String, action: () -> Void)] = []
    ) {   // R1 — content + content/data
        self.message = message
        self.title = title
        self.links = links
    }

    private var radius: CGFloat { banner ? 0 : Theme.RadiusKey.md.value }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            if showIcon {
                Icon(systemName: type.systemImage).size(.sm).color(type.accent(theme))
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
                    InlineText(message, links: links).color(theme.text(.textSecondary))
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
                    Icon(systemName: "xmark").size(.xs).color(theme.text(.textTertiary))
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
        InfoBanner("This is an informational message.", title: "Heads up").variant(.info)
        InfoBanner("Your changes were saved.").variant(.success)
        InfoBanner("Please double-check this field.").variant(.warning)
        InfoBanner("Something went wrong.").variant(.error).onDismiss {}
        InfoBanner("A neutral note.").variant(.neutral)
    }
    .padding()
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension InfoBanner {
    /// Semantic type: neutral / info / success / warning / error — drives the
    /// surface, accent, border and leading icon.
    func variant(_ t: InfoBannerType) -> Self { copy { $0.type = t } }

    /// Show or hide the type's leading icon.
    func showsIcon(_ on: Bool = true) -> Self { copy { $0.showIcon = on } }

    /// Edge-to-edge banner treatment: stretch to full width and drop the
    /// rounded corners / border (Ant Alert `banner`).
    func fullWidth(_ on: Bool = true) -> Self { copy { $0.banner = on } }

    /// Trailing inline action button: its label + handler.
    func action(_ title: String?, onAction: (() -> Void)? = nil) -> Self {
        copy { $0.actionTitle = title; $0.onAction = onAction }
    }

    /// Trailing dismiss (×) button handler.
    func onDismiss(_ handler: (() -> Void)?) -> Self { copy { $0.onDismiss = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}
