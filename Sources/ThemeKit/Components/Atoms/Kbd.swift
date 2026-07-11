//
//  Kbd.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Size tier of a `Kbd` key cap. (daisyUI `kbd-xs` … `kbd-lg`.)
public enum KbdSize: String, CaseIterable, Sendable {
    case xs, sm, md, lg

    var fontSize: CGFloat {
        switch self {
        case .xs: return 10
        case .sm: return 11
        case .md: return 13   // default — matches the original `.footnote` cap
        case .lg: return 16
        }
    }
    var minSide: CGFloat {
        switch self {
        case .xs: return 18
        case .sm: return 22
        case .md: return 28   // default — original metric
        case .lg: return 36
        }
    }
    var horizontalPadding: CGFloat {
        switch self {
        case .xs, .sm: return Theme.SpacingKey.xs.value   // 4
        case .md: return Theme.SpacingKey.sm.value        // 8 — original metric
        case .lg: return Theme.SpacingKey.sm.value + Theme.SpacingKey.xs.value   // 12
        }
    }
}

/// Atom. A keyboard key cap. (daisyUI "Kbd".)
public struct Kbd: View {
    @Environment(\.theme) private var theme

    private let text: String

    // Appearance/config — mutated only through the modifiers below (R2).
    private var size: KbdSize = .md

    public init(_ text: String) { self.text = text }

    public var body: some View {
        Text(text)
            .font(.system(size: size.fontSize, design: .monospaced).weight(.semibold))
            .foregroundStyle(theme.text(.textPrimary))
            .padding(.horizontal, size.horizontalPadding)
            .frame(minWidth: size.minSide, minHeight: size.minSide)
            .background(theme.background(.bgBase),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous)
                    .stroke(theme.border(.borderPrimary), lineWidth: 1)
            )
            .overlay(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(theme.border(.borderPrimary))
                    .frame(height: 2)
                    .padding(.horizontal, 4)
                    .offset(y: 1)
            }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Kbd {
    /// Size tier: xs / sm / md (default) / lg — scales font, cap side and padding.
    func size(_ s: KbdSize) -> Self { copy { $0.size = s } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    PreviewMatrix("Kbd") {
        PreviewCase("Shortcut") {
            HStack(spacing: 6) {
                Kbd("⌘"); Kbd("K")
                Text("then").font(.caption).foregroundStyle(.secondary)
                Kbd("esc")
            }
        }
        PreviewCase("Sizes") {
            HStack(spacing: 6) {
                Kbd("A").size(.xs)
                Kbd("A").size(.sm)
                Kbd("A").size(.md)
                Kbd("A").size(.lg)
            }
        }
    }
}
