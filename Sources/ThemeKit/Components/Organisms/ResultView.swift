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
    private let message: String?
    private let primaryTitle: String?
    private let onPrimary: (() -> Void)?
    private let secondaryTitle: String?
    private let onSecondary: (() -> Void)?

    public init(
        _ status: ResultStatus,
        title: String,
        message: String? = nil,
        primaryTitle: String? = nil,
        onPrimary: (() -> Void)? = nil,
        secondaryTitle: String? = nil,
        onSecondary: (() -> Void)? = nil
    ) {
        self.status = status
        self.title = title
        self.message = message
        self.primaryTitle = primaryTitle
        self.onPrimary = onPrimary
        self.secondaryTitle = secondaryTitle
        self.onSecondary = onSecondary
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

            if primaryTitle != nil || secondaryTitle != nil {
                HStack(spacing: Theme.SpacingKey.sm.value) {
                    if let secondaryTitle, let onSecondary {
                        OutlineButton(secondaryTitle, action: onSecondary)
                    }
                    if let primaryTitle, let onPrimary {
                        ThemeButton(primaryTitle, color: status.color, action: onPrimary)
                    }
                }
                .padding(.top, Theme.SpacingKey.xs.value)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.SpacingKey.lg.value)
    }

    @ViewBuilder
    private var emblem: some View {
        if let code = status.code {
            Text(code)
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(status.color.base)
                .overlay(alignment: .bottomTrailing) {
                    Icon(systemName: status.systemImage, size: .md, color: status.color.base)
                        .padding(6)
                        .background(theme.background(.bgWhite), in: Circle())
                        .offset(x: 10, y: 4)
                }
        } else {
            ZStack {
                Circle().fill(status.color.bg).frame(width: 88, height: 88)
                Icon(systemName: status.systemImage, size: .xl, color: status.color.base)
            }
        }
    }
}

#Preview {
    ScrollView {
        VStack(spacing: 40) {
            ResultView(.success, title: "Rezervasyon onaylandı",
                       message: "Onay e-postası gönderildi.",
                       primaryTitle: "Detaylar", onPrimary: {},
                       secondaryTitle: "Ana sayfa", onSecondary: {})
            ResultView(.notFound, title: "Sayfa bulunamadı",
                       message: "Aradığınız sayfa taşınmış veya silinmiş olabilir.",
                       primaryTitle: "Ana sayfaya dön", onPrimary: {})
        }
        .padding()
    }
}
