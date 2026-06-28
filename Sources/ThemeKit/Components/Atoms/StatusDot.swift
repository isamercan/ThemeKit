//
//  StatusDot.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

public enum StatusKind {
    case online, offline, busy, away, neutral

    func color(_ theme: Theme) -> Color {
        switch self {
        case .online: return theme.foreground(.systemcolorsFgSuccess)
        case .offline: return theme.text(.textTertiary)
        case .busy: return theme.foreground(.systemcolorsFgError)
        case .away: return theme.foreground(.systemcolorsFgWarning)
        case .neutral: return theme.foreground(.fgHero)
        }
    }

    /// Spoken status when no explicit label is supplied — so the state isn't
    /// conveyed by color alone (a WCAG / VoiceOver requirement).
    var accessibleName: String {
        switch self {
        case .online: return String(themeKit: "Online")
        case .offline: return String(themeKit: "Offline")
        case .busy: return String(themeKit: "Busy")
        case .away: return String(themeKit: "Away")
        case .neutral: return String(themeKit: "Status")
        }
    }
}

/// Atom. A small status indicator dot with an optional pulse + label.
/// (daisyUI "Status".)
public struct StatusDot: View {
    @Environment(\.theme) private var theme

    private let kind: StatusKind
    private let size: CGFloat
    private let label: String?
    private let pulse: Bool

    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init(_ kind: StatusKind, size: CGFloat = 10, label: String? = nil, pulse: Bool = false) {
        self.kind = kind
        self.size = size
        self.label = label
        self.pulse = pulse
    }

    /// The pulse ring only animates when motion is allowed.
    private var pulses: Bool { pulse && !reduceMotion }

    public var body: some View {
        HStack(spacing: Theme.SpacingKey.xs.value) {
            ZStack {
                if pulses {
                    Circle().fill(kind.color(theme)).opacity(animating ? 0 : 0.5)
                        .scaleEffect(animating ? 2.2 : 1)
                        .frame(width: size, height: size)
                }
                Circle().fill(kind.color(theme)).frame(width: size, height: size)
            }
            .onAppear { if pulses { withAnimation(.easeOut(duration: 1.2).repeatForever(autoreverses: false)) { animating = true } } }

            if let label {
                Text(label).textStyle(.labelSm600).foregroundStyle(theme.text(.textPrimary))
            }
        }
        // Collapse dot + label into one element so the status is always spoken,
        // even when the dot is shown without a visible label.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(label ?? kind.accessibleName))
    }
}

#Preview {
    VStack(alignment: .leading, spacing: 12) {
        StatusDot(.online, label: "Online", pulse: true)
        StatusDot(.busy, label: "Busy")
        StatusDot(.away, label: "Away")
        StatusDot(.offline, label: "Offline")
    }
    .padding()
}
