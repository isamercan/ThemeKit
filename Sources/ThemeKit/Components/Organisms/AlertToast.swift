//
//  AlertToast.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum AlertToastType {
    case success, warning, danger, info

    func background(_ theme: Theme) -> Color {
        switch self {
        case .success: return theme.background(.systemcolorsBgSuccess)
        case .warning: return theme.background(.systemcolorsBgWarning)
        case .danger: return theme.background(.systemcolorsBgError)
        case .info: return theme.background(.systemcolorsBgInfo)
        }
    }

    /// Warning uses dark text for contrast on the bright amber fill.
    func foreground(_ theme: Theme) -> Color {
        switch self {
        case .warning: return theme.text(.textPrimary)
        case .success, .danger, .info: return theme.foreground(.fgSecondary)
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

/// Improved, token-bound rewrite of the reference AlertView — a solid-fill
/// status banner (complements the light-surface InfoBanner).
public struct AlertToast: View {
    @Environment(\.theme) private var theme

    private let title: String
    // Appearance/state — mutated only through the modifiers below (R2).
    private var message: String?
    private var type: AlertToastType = .info
    private var systemImage: String?
    private var isLoading: Bool = false
    private var action: ToastAction?
    private var onClose: (() -> Void)?

    public init(_ title: String) {   // R1 — content only
        self.title = title
    }

    public var body: some View {
        HStack(alignment: .top, spacing: Theme.SpacingKey.sm.value) {
            // Leading accessory: an activity spinner while loading, otherwise the
            // status icon (a caller override falls back to the type's default).
            if isLoading {
                Spinner(size: IconSize.sm.value, lineWidth: 2, color: type.foreground(theme))
            } else {
                Icon(systemName: systemImage ?? type.systemImage, size: .sm, color: type.foreground(theme))
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
                    Icon(systemName: "xmark", size: .xs, color: type.foreground(theme))
                }
                .buttonStyle(.plain)
            }
        }
        .foregroundStyle(type.foreground(theme))
        .padding(.vertical, 12)
        .padding(.horizontal, Theme.SpacingKey.md.value)
        .background(type.background(theme), in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension AlertToast {
    /// Secondary line under the title.
    func message(_ text: String?) -> Self { copy { $0.message = text } }

    /// Status treatment: success / warning / danger / info (drives fill + icon).
    func variant(_ v: AlertToastType) -> Self { copy { $0.type = v } }

    /// Override the leading status glyph (otherwise derived from the variant).
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }

    /// Swap the leading icon for an activity spinner while `on`.
    func loading(_ on: Bool = true) -> Self { copy { $0.isLoading = on } }

    /// Inline tappable action (e.g. "Undo"), rendered before the close button.
    func action(_ action: ToastAction?) -> Self { copy { $0.action = action } }

    /// Trailing dismiss button; the handler is invoked on tap.
    func onClose(_ handler: (() -> Void)?) -> Self { copy { $0.onClose = handler } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 12) {
        AlertToast("Saved successfully").variant(.success).onClose {}
        AlertToast("Check your input").message("One field needs attention.").variant(.warning)
        AlertToast("Something went wrong").variant(.danger).onClose {}
        AlertToast("New update available").variant(.info)
        AlertToast("Message deleted").variant(.info).action(ToastAction("Undo") {}).onClose {}
        AlertToast("Uploading…").variant(.info).loading()
    }
    .padding()
}
