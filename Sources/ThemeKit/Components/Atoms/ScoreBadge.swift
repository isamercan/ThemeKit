//
//  ScoreBadge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Size tiers for ``ScoreBadge`` — the kit's uniform size-enum vocabulary
/// (replaces the boolean `large()` toggle, C5).
public enum ScoreBadgeSize: Sendable {
    case small, large
}

/// Atom. A numeric rating score in a filled rounded box (e.g. "9.0").
public struct ScoreBadge: View {
    @Environment(\.theme) private var theme

    private let score: Double

    // Appearance — mutated only through the modifiers below (R2).
    private var size: ScoreBadgeSize
    private var accent: SemanticColor?

    public init(_ score: Double, large: Bool = false) {
        self.score = score
        self.size = large ? .large : .small
    }

    /// Fill — the accent's solid role when set, else the stock turquoise token.
    private var fill: Color { accent.map { $0.solid } ?? theme.background(.bgTurquoise) }
    /// Content on the fill — auto-contrasting on a custom accent.
    private var content: Color { accent.map { $0.onSolid } ?? theme.foreground(.fgSecondary) }

    private var isLarge: Bool { size == .large }

    public var body: some View {
        Text(String(format: "%.1f", score))
            .textStyle(isLarge ? .labelMd700 : .labelSm700)
            .foregroundStyle(content)
            .padding(.horizontal, isLarge ? Theme.SpacingKey.sm.value : Theme.SpacingKey.xs.value)
            .frame(minWidth: isLarge ? 40 : 32, minHeight: isLarge ? 32 : 24)
            .background(fill,
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            // Give the bare number context: VoiceOver reads "Score: 9.0".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(themeKit: "Score")))
            .accessibilityValue(Text(String(format: "%.1f", score)))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ScoreBadge {
    /// Size tier: small (default) / large — the kit's uniform size-enum axis.
    func size(_ s: ScoreBadgeSize) -> Self { copy { $0.size = s } }
    /// Larger box + type — the boolean twin of the init's `large:` flag.
    @available(*, deprecated, message: "Use size(_:) with a ScoreBadgeSize.")
    func large(_ on: Bool = true) -> Self { size(on ? .large : .small) }
    /// Token-fed fill override (content auto-contrasts); `nil` keeps the
    /// stock turquoise token.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    HStack {
        ScoreBadge(9.0)
        ScoreBadge(8.5)
        ScoreBadge(9.8, large: true)
        ScoreBadge(7.4).accent(.warning)
        ScoreBadge(9.2).size(.large).accent(.success)   // C5 — size enum axis
    }
    .padding()
}
