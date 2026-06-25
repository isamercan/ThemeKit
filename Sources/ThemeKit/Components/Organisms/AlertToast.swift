//
//  AlertToast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Improved, token-bound rewrite of the reference AlertView — a solid-fill
//  status banner (complements the light-surface InfoBanner).
//

import SwiftUI

public enum AlertToastType {
    case success, warning, danger, info

    var background: Color {
        switch self {
        case .success: return Theme.shared.background(.systemcolorsBgSuccess)
        case .warning: return Theme.shared.background(.systemcolorsBgWarning)
        case .danger: return Theme.shared.background(.systemcolorsBgError)
        case .info: return Theme.shared.background(.systemcolorsBgInfo)
        }
    }

    /// Warning uses dark text for contrast on the bright amber fill.
    var foreground: Color {
        switch self {
        case .warning: return Theme.shared.text(.textPrimary)
        case .success, .danger, .info: return Theme.shared.foreground(.fgSecondary)
        }
    }

    var systemImage: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "exclamationmark.octagon.fill"
        case .info: return "info.circle.fill"
        }
    }
}

/// An optional tappable action rendered inline in a toast (e.g. "Undo"). Its
/// label inherits the toast's foreground color so it reads on the solid fill.
public struct ToastAction {
    public let title: String
    public let handler: () -> Void

    public init(_ title: String, handler: @escaping () -> Void) {
        self.title = title
        self.handler = handler
    }
}

public struct AlertToast: View {
    private let title: String
    private let message: String?
    private let type: AlertToastType
    private let systemImage: String?
    private let isLoading: Bool
    private let action: ToastAction?
    private let onClose: (() -> Void)?

    public init(
        _ title: String,
        message: String? = nil,
        type: AlertToastType = .info,
        systemImage: String? = nil,
        isLoading: Bool = false,
        action: ToastAction? = nil,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.systemImage = systemImage
        self.isLoading = isLoading
        self.action = action
        self.onClose = onClose
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            // Leading accessory: an activity spinner while loading, otherwise the
            // status icon (a caller override falls back to the type's default).
            if isLoading {
                Spinner(size: IconSize.sm.value, lineWidth: 2, color: type.foreground)
            } else {
                Icon(systemName: systemImage ?? type.systemImage, size: .sm, color: type.foreground)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.labelBase600)
                if let message {
                    Text(message).textStyle(.bodySm400).opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if let action {
                Button(action: action.handler) {
                    Text(action.title).textStyle(.labelBase700).underline()
                }
                .buttonStyle(.plain)
            }

            if let onClose {
                Button(action: onClose) {
                    Icon(systemName: "xmark", size: .xs, color: type.foreground)
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(type.foreground)
        .padding(.vertical, 12)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .background(type.background, in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

#Preview {
    VStack(spacing: 12) {
        AlertToast("Saved successfully", type: .success, onClose: {})
        AlertToast("Check your input", message: "One field needs attention.", type: .warning)
        AlertToast("Something went wrong", type: .danger, onClose: {})
        AlertToast("New update available", type: .info)
        AlertToast("Message deleted", type: .info, action: ToastAction("Undo") {}, onClose: {})
        AlertToast("Uploading…", type: .info, isLoading: true)
    }
    .padding()
}
