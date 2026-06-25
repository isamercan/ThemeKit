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

public struct AlertToast: View {
    private let title: String
    private let message: String?
    private let type: AlertToastType
    private let onClose: (() -> Void)?

    public init(
        _ title: String,
        message: String? = nil,
        type: AlertToastType = .info,
        onClose: (() -> Void)? = nil
    ) {
        self.title = title
        self.message = message
        self.type = type
        self.onClose = onClose
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            Icon(systemName: type.systemImage, size: .sm, color: type.foreground)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).textStyle(.labelBase600)
                if let message {
                    Text(message).textStyle(.bodySm400).opacity(0.9)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

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
    }
    .padding()
}
