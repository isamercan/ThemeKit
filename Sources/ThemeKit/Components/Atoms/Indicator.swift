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
        overlay(alignment: position.alignment) {
            content().modifier(IndicatorNudge(offset: position.offset))
        }
    }

    /// Overlays a small status dot at a corner, in the error token — the
    /// classic notification dot.
    func indicatorDot(position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(semantic: nil, rawColor: nil) }
    }

    /// Overlays a small status dot at a corner, tinted by a semantic color
    /// (e.g. `.success` for an online dot).
    func indicatorDot(_ accent: SemanticColor, position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(semantic: accent, rawColor: nil) }
    }

    /// Raw dot tint (back-compat); prefer the `SemanticColor` overload —
    /// or `indicatorDot(position:)` for the error-token default.
    @available(*, deprecated, message: "Use indicatorDot(_: SemanticColor, position:) — the token-fed overload.")
    func indicatorDot(_ color: Color? = nil, position: IndicatorPosition = .topTrailing) -> some View {
        indicator(position) { IndicatorDot(semantic: nil, rawColor: color) }
    }
}

/// Pushes the badge outward past the corner. The `alignment` itself mirrors in
/// RTL (`.topTrailing` resolves to the top-LEFT corner), but `.offset(x:)` does
/// not — so the outward x-nudge flips sign by hand to keep pointing outward.
private struct IndicatorNudge: ViewModifier {
    @Environment(\.layoutDirection) private var layoutDirection
    let offset: CGSize

    func body(content: Content) -> some View {
        content.offset(x: layoutDirection == .rightToLeft ? -offset.width : offset.width,
                       y: offset.height)
    }
}

// Extracted into a View so the dot + halo resolve the injected `\.theme`.
// `semantic` is resolved here (in `body`), not at modifier-call time, so it
// honors per-subtree `.theme(_:)` (ADR-0006); `rawColor` is the raw-`Color`
// escape hatch (deprecated `indicatorDot(_: Color?, position:)`).
private struct IndicatorDot: View {
    let semantic: SemanticColor?
    let rawColor: Color?
    @Environment(\.theme) private var theme

    var body: some View {
        Circle()
            .fill(semantic.map { theme.resolve($0).base } ?? rawColor ?? theme.foreground(.systemcolorsFgError))
            .frame(width: 10, height: 10)
            .overlay(Circle().stroke(theme.background(.bgWhite), lineWidth: 2))
            // Color-only status dot — decorative to VoiceOver; the host view
            // carries the semantic (e.g. an "unread" / "online" label).
            .accessibilityHidden(true)
    }
}

#Preview {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            PreviewMatrix("Indicator") {
                PreviewCase("Notification dot") {
                    Icon(systemName: "bell").size(.lg).colorOverride(theme.text(.textPrimary))
                        .indicatorDot()
                }
                PreviewCase("Status dot") {
                    Icon(systemName: "wifi").size(.lg).colorOverride(theme.text(.textPrimary))
                        .indicatorDot(.success)
                }
                PreviewCase("Badge") {
                    Icon(systemName: "envelope").size(.lg).colorOverride(theme.text(.textPrimary))
                        .indicator { Badge("3").badgeStyle(.error).size(.small) }
                }
            }
        }
    }
    return Demo()
}

#Preview("RTL") {
    struct Demo: View {
        @Environment(\.theme) var theme
        var body: some View {
            // `.topTrailing` resolves to the top-LEFT corner here; the outward nudge
            // must push the badge past that corner, not back inward.
            HStack(spacing: 32) {
                Icon(systemName: "bell").size(.lg).colorOverride(theme.text(.textPrimary))
                    .indicatorDot()
                Icon(systemName: "wifi").size(.lg).colorOverride(theme.text(.textPrimary))
                    .indicatorDot(.success, position: .bottomLeading)
                Icon(systemName: "envelope").size(.lg).colorOverride(theme.text(.textPrimary))
                    .indicator { Badge("3").badgeStyle(.error).size(.small) }
            }
            .padding()
            .environment(\.layoutDirection, .rightToLeft)
        }
    }
    return Demo()
}
