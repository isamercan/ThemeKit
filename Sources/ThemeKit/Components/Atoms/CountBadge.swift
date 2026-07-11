//
//  CountBadge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//
//  Ant "Badge": a small count / dot overlaid on the corner of any view, plus a
//  corner Ribbon. (Our `Badge` atom is Ant's "Tag"; this fills the real Ant
//  Badge role.)
//

import SwiftUI

public extension View {
    /// Overlays a count bubble in the top-trailing corner (Ant `Badge count`).
    func countBadge(_ count: Int, overflowCount: Int = 99, showZero: Bool = false, color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) {
            CountBubble(count: count, overflowCount: overflowCount, showZero: showZero, color: color)
        }
    }

    /// Overlays a status dot in the top-trailing corner (Ant `Badge dot`).
    func dotBadge(color: SemanticColor = .error) -> some View {
        overlay(alignment: .topTrailing) { DotBadge(color: color) }
    }
}

// Extracted into Views so the white halo stroke resolves the injected `\.theme`
// (an extension method can't read the environment; a View body can).
private struct CountBubble: View {
    let count: Int
    let overflowCount: Int
    let showZero: Bool
    let color: SemanticColor
    @Environment(\.theme) private var theme
    @Environment(\.locale) private var locale

    var body: some View {
        // `count` is an Int badge value, not a collection — `isEmpty` doesn't apply.
        // swiftlint:disable:next empty_count
        if count > 0 || showZero {
            Text(count > overflowCount
                ? "\(overflowCount.formatted(.number.locale(locale)))+"
                : count.formatted(.number.locale(locale)))
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(color.onSolid)
                .padding(.horizontal, 5)
                .frame(minWidth: 18, minHeight: 18)
                .background(color.solid, in: Capsule())
                .overlay(Capsule().strokeBorder(theme.background(.bgWhite), lineWidth: 1.5))
                .offset(x: 9, y: -9)
        }
    }
}

private struct DotBadge: View {
    let color: SemanticColor
    @Environment(\.theme) private var theme

    var body: some View {
        Circle().fill(color.solid).frame(width: 10, height: 10)
            .overlay(Circle().strokeBorder(theme.background(.bgWhite), lineWidth: 1.5))
            .offset(x: 4, y: -4)
            // Color-only status dot — decorative to VoiceOver; the host view
            // carries the semantic (e.g. an "unread" label).
            .accessibilityHidden(true)
    }
}

/// A corner ribbon wrapping any content (Ant `Badge.Ribbon`).
public struct Ribbon<Content: View>: View {
    private let text: String
    private let content: Content
    // Appearance/config — mutated only through the modifiers below (R2).
    private var color: SemanticColor = .primary

    public init(_ text: String, @ViewBuilder content: () -> Content) {   // R1 — content only
        self.text = text
        self.content = content()
    }

    public var body: some View {
        content.overlay(alignment: .topTrailing) {
            Text(text)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(color.onSolid)
                .padding(.horizontal, Theme.SpacingKey.sm.value)
                .padding(.vertical, 3)
                .background(color.solid)
                .clipShape(RoundedRectangle(cornerRadius: 4, style: .continuous))
                .offset(x: 6, y: 8)
                .themeShadow(.soft)
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension Ribbon {
    /// Semantic color of the ribbon; `nil` restores the default (`.primary`).
    func accent(_ color: SemanticColor?) -> Self { copy { $0.color = color ?? .primary } }

    /// Semantic color of the ribbon (back-compat); prefer `accent(_:)`.
    @available(*, deprecated, message: "Use accent(_:) with a SemanticColor token.")
    func color(_ c: SemanticColor) -> Self { copy { $0.color = c } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    @Previewable @Environment(\.theme) var theme
    HStack(spacing: 32) {
        Image(systemName: "bell.fill").font(.title).countBadge(5)
        Image(systemName: "envelope.fill").font(.title).countBadge(128)
        Image(systemName: "cart.fill").font(.title).dotBadge(color: .success)
        Ribbon("New") {
            RoundedRectangle(cornerRadius: 12).fill(theme.background(.bgElevatorTertiary)).frame(width: 100, height: 70)
        }
        .accent(.error)
    }
    .padding(40)
}
