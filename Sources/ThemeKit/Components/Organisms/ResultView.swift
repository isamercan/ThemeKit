//
//  ResultView.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum ResultStatus: String, CaseIterable {
    case success, info, warning, error
    case notFound      // 404
    case forbidden     // 403
    case serverError   // 500

    /// Semantic color driving the icon and primary action.
    public var color: SemanticColor {
        switch self {
        case .success: return .success
        case .info: return .primary
        case .warning: return .warning
        case .error: return .error
        case .notFound, .forbidden, .serverError: return .neutral
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .error: return "xmark.octagon.fill"
        case .notFound: return "magnifyingglass"
        case .forbidden: return "lock.fill"
        case .serverError: return "exclamationmark.arrow.triangle.2.circlepath"
        }
    }

    /// Exception status code shown as a large numeral, when applicable.
    var code: String? {
        switch self {
        case .notFound: return "404"
        case .forbidden: return "403"
        case .serverError: return "500"
        default: return nil
        }
    }
}

/// Ant-style "Result" template: a full-page status view for the outcome of an
/// operation (success / info / warning / error) or an exception page
/// (404 / 403 / 500), with up to two actions. Generalizes `EmptyState`.
/// See docs/result-templates.md.
public struct ResultView: View {
    @Environment(\.theme) private var theme

    private let status: ResultStatus
    private let title: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var message: String?
    private var primaryTitle: String?
    private var onPrimary: (() -> Void)?
    private var secondaryTitle: String?
    private var onSecondary: (() -> Void)?
    private var customIcon: AnyView?      // Ant `icon` override
    private var extraContent: AnyView?    // Ant `extra` (arbitrary actions)
    private var bodyContent: AnyView?     // Ant children (body between subtitle + extra)

    public init(_ status: ResultStatus, title: String) {   // R1
        self.status = status
        self.title = title
    }

    public var body: some View {
        VStack(spacing: Theme.SpacingKey.base.value) {
            emblem

            VStack(spacing: Theme.SpacingKey.sm.value) {
                Text(title)
                    .textStyle(.headingBase)
                    .foregroundStyle(theme.text(.textPrimary))
                    .multilineTextAlignment(.center)
                if let message {
                    Text(message)
                        .textStyle(.bodyBase400)
                        .foregroundStyle(theme.text(.textSecondary))
                        .multilineTextAlignment(.center)
                }
            }

            if let bodyContent { bodyContent }   // Ant children (e.g. an error-detail box)

            extra
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.SpacingKey.lg.value)
    }

    /// The top emblem — a caller-provided icon/illustration or the status default.
    @ViewBuilder private var emblem: some View {
        if let customIcon {
            customIcon
        } else {
            statusEmblem
        }
    }

    @ViewBuilder private var statusEmblem: some View {
        if let code = status.code {
            Text(code)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(status.color.base)
                .overlay(alignment: .bottomTrailing) {
                    Icon(systemName: status.systemImage).size(.md).colorOverride(status.color.base)
                        .padding(6)
                        .background(theme.background(.bgWhite), in: Circle())
                        .offset(x: 10, y: 4)
                }
        } else {
            ZStack {
                Circle().fill(status.color.bg).frame(width: 88, height: 88)
                Icon(systemName: status.systemImage).size(.xl).colorOverride(status.color.base)
            }
        }
    }

    /// The actions area — a caller-provided `extra` slot, else the primary/secondary buttons.
    @ViewBuilder private var extra: some View {
        if let extraContent {
            extraContent.padding(.top, Theme.SpacingKey.xs.value)
        } else if primaryTitle != nil || secondaryTitle != nil {
            HStack(spacing: Theme.SpacingKey.sm.value) {
                if let secondaryTitle, let onSecondary {
                    OutlineButton(secondaryTitle, action: onSecondary)
                }
                if let primaryTitle, let onPrimary {
                    ThemeButton(primaryTitle, action: onPrimary).color(status.color)
                }
            }
            .padding(.top, Theme.SpacingKey.xs.value)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ResultView {
    /// Supporting text under the title.
    func message(_ text: String?) -> Self { copy { $0.message = text } }
    /// Alias for ``message(_:)`` — mirrors Ant's `subTitle`.
    func subtitle(_ text: String?) -> Self { copy { $0.message = text } }
    /// Replace the status emblem with a custom icon / illustration (Ant `icon`).
    func icon(@ViewBuilder _ content: () -> some View) -> Self { copy { $0.customIcon = AnyView(content()) } }
    /// Arbitrary body content between the subtitle and the actions (Ant children).
    func content(@ViewBuilder _ content: () -> some View) -> Self { copy { $0.bodyContent = AnyView(content()) } }
    /// A custom actions area, replacing the primary/secondary buttons (Ant `extra`).
    func extra(@ViewBuilder _ content: () -> some View) -> Self { copy { $0.extraContent = AnyView(content()) } }

    /// Primary (status-tinted) action button — renders when both title and action are set.
    func primaryAction(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.primaryTitle = title; $0.onPrimary = action }
    }

    /// Secondary (outline) action button — renders when both title and action are set.
    func secondaryAction(_ title: String?, action: (() -> Void)? = nil) -> Self {
        copy { $0.secondaryTitle = title; $0.onSecondary = action }
    }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("ResultView") {
        PreviewCase("Success · two actions") {
            ResultView(.success, title: "Reservation confirmed")
                .message("A confirmation email has been sent.")
                .primaryAction("Details", action: {})
                .secondaryAction("Home", action: {})
        }
        PreviewCase("Error") {
            ResultView(.error, title: "Payment failed")
                .message("Your card was declined. Please try another method.")
                .primaryAction("Try again", action: {})
        }
        PreviewCase("404 exception page") {
            ResultView(.notFound, title: "Page not found")
                .message("The page you're looking for may have been moved or deleted.")
                .primaryAction("Back to home", action: {})
        }
    }
}
