//
//  ScoreBadge.swift
//  ThemeKit
//  Created by İsa Mercan on 23.06.2026.
//

import SwiftUI

/// Atom. A numeric rating score in a filled rounded box (e.g. "9.0").
public struct ScoreBadge: View {
    private let score: Double
    private let large: Bool

    public init(_ score: Double, large: Bool = false) {
        self.score = score
        self.large = large
    }

    public var body: some View {
        Text(String(format: "%.1f", score))
            .textStyle(large ? .labelMd700 : .labelSm700)
            .foregroundStyle(Theme.shared.foreground(.fgSecondary))
            .padding(.horizontal, large ? Theme.SpacingKey.sm.value : Theme.SpacingKey.xs.value)
            .frame(minWidth: large ? 40 : 32, minHeight: large ? 32 : 24)
            .background(Theme.shared.background(.bgTurquoise),
                       in: RoundedRectangle(cornerRadius: Theme.RadiusKey.xs.value, style: .continuous))
            // Give the bare number context: VoiceOver reads "Score: 9.0".
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text(String(themeKit: "Score")))
            .accessibilityValue(Text(String(format: "%.1f", score)))
    }
}

#Preview {
    HStack {
        ScoreBadge(9.0)
        ScoreBadge(8.5)
        ScoreBadge(9.8, large: true)
    }
    .padding()
}
