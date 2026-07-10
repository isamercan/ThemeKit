//
//  Indicator.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Atom. Positions a small badge / dot on the corner of any view.
//  (daisyUI "Indicator".)
//

import SwiftUI

public enum IndicatorPosition {
    case topTrailing, topLeading, bottomTrailing, bottomLeading

    var alignment: Alignment {
        switch self {
        case .topTrailing: return .topTrailing
        case .topLeading: return .topLeading
        case .bottomTrailing: return .bottomTrailing
        case .bottomLeading: return .bottomLeading
        }
    }
    var offset: CGSize {
        switch self {
        case .topTrailing: return CGSize(width: 4, height: -4)
        case .topLeading: return CGSize(width: -4, height: -4)
        case .bottomTrailing: return CGSize(width: 4, height: 4)
        case .bottomLeading: return CGSize(width: -4, height: 4)
        }
    }
}

public extension View {
    /// Overlays `content` at a corner of this view.
    func indicator<Content: View>(_ position: IndicatorPosition = .topTrailing, @ViewBuilder content: () -> Content) -> some View {
        let offset = position.offset
        return overlay(alignment: position.alignment) {
            content().offset(x: offset.width, y: offset.height)
        }
    }

    /// Overlays a small status dot at a corner, in the error token — the
    /// classic notification dot.
    func indicatorDot(position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(color: nil) }
    }

    /// Overlays a small status dot at a corner, tinted by a semantic color
    /// (e.g. `.success` for an online dot).
    func indicatorDot(_ accent: SemanticColor, position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(color: accent.base) }
    }

    /// Raw dot tint (back-compat); prefer the `SemanticColor` overload —
    /// or `indicatorDot(position:)` for the error-token default.
    @available(*, deprecated, message: "Use indicatorDot(_: SemanticColor, position:) — the token-fed overload.")
    func indicatorDot(_ color: Color? = nil, position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(color: color) }
    }
}

// Extracted into a View so the dot + halo resolve the injected `\.theme`.
private struct IndicatorDot: View {
    let color: Color?
    @Environment(\.theme) private var theme

    var body: some View {
        Circle()
            .fill(color ?? theme.foreground(.systemcolorsFgError))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.background(.bgWhite), lineWidth: 2))
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    HStack(spacing: 32) {
        Icon(systemName: "bell").size(.lg).colorOverride(theme.text(.textPrimary))
            .indicatorDot()
        Icon(systemName: "wifi").size(.lg).colorOverride(theme.text(.textPrimary))
            .indicatorDot(.success)
        Icon(systemName: "envelope").size(.lg).colorOverride(theme.text(.textPrimary))
            .indicator { Badge("3").badgeStyle(.error).size(.small) }
    }
    .padding()
}
