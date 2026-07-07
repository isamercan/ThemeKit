//
//  SearchBadge.swift
//  ThemeKit
//
//  Atom. The soft-blue pill used inside search inputs — an airport code (SAW), a
//  short date (23 Jul '24), a count (4 Guests). Token-bound: every colour is a
//  theme token key (never a raw colour), so it re-themes with the brand.
//

import SwiftUI

public struct SearchBadge: View {
    @Environment(\.theme) private var theme
    private let text: String
    // Appearance — mutated only through the modifiers below (R2). Token keys, not raw colours.
    private var backgroundKey: Theme.BackgroundColorKey?
    private var foregroundKey: Theme.TextColorKey?
    private var systemImage: String?

    public init(_ text: String) { self.text = text }   // R1

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).font(.system(size: 11)) }
            Text(text).textStyle(.bodySm400)
        }
        .foregroundStyle(theme.text(foregroundKey ?? .textPrimary))
        .padding(.horizontal, Theme.SpacingKey.sm.value)
        .frame(minHeight: 20)
        .background(theme.background(backgroundKey ?? .bgElevatorTertiary),
                    in: RoundedRectangle(cornerRadius: Theme.RadiusRole.selector.value, style: .continuous))
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension SearchBadge {
    /// Recolour the pill from theme token keys (background and/or text).
    func colors(background: Theme.BackgroundColorKey? = nil, foreground: Theme.TextColorKey? = nil) -> Self {
        copy { if let background { $0.backgroundKey = background }; if let foreground { $0.foregroundKey = foreground } }
    }
    /// A leading SF Symbol inside the pill.
    func icon(_ systemName: String?) -> Self { copy { $0.systemImage = systemName } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    HStack {
        SearchBadge("SAW")
        SearchBadge("23 Jul '24")
        SearchBadge("4 Guests")
        SearchBadge("Direct").colors(background: .badgeBgPurple, foreground: .textPurple).icon("bolt.fill")
    }
    .padding()
}
