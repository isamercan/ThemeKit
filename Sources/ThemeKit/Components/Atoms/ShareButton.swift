//
//  ShareButton.swift
//  ThemeKit
//

import SwiftUI

/// Atom. A share action wrapping SwiftUI `ShareLink` with kit chrome — opens the
/// system share sheet for a URL or string. (An iOS-native kit staple.)
public struct ShareButton: View {
    @Environment(\.theme) private var theme

    private let title: String
    private let item: String

    // Appearance — mutated only through the modifiers below (R2).
    private var systemImage = "square.and.arrow.up"
    private var size: ButtonSize?   // nil → the stock 44 pt chrome
    private var accent: SemanticColor?

    public init(_ title: String = String(themeKit: "Share"), item: String) {
        self.title = title
        self.item = item
    }

    public var body: some View {
        ShareLink(item: item) {
            Label(title, systemImage: systemImage)
                .textStyle(size?.textStyle ?? .labelBase600)
                .padding(.horizontal, size?.horizontalPadding ?? Theme.SpacingKey.md.value)
                .frame(height: size?.height ?? 44)
                .foregroundStyle(accent.map { $0.onSolid } ?? theme.foreground(.fgSecondary))
                .background(accent.map { $0.solid } ?? theme.foreground(.fgHero),
                            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        }
    }
}

// MARK: - Modifiers (R2 copy-on-write · R5 standard vocabulary)

public extension ShareButton {
    /// SF Symbol on the label (default `square.and.arrow.up`).
    func icon(_ systemName: String) -> Self { copy { $0.systemImage = systemName } }
    /// Kit button size ramp (height / padding / type); unset keeps the stock 44 pt chrome.
    func size(_ s: ButtonSize) -> Self { copy { $0.size = s } }
    /// Token-fed fill (label auto-contrasts); `nil` keeps the hero fill.
    func accent(_ color: SemanticColor?) -> Self { copy { $0.accent = color } }

    private func copy(_ mutate: (inout Self) -> Void) -> Self {   // R2 — single mutation point
        var c = self
        mutate(&c)
        return c
    }
}

#Preview {
    VStack(spacing: 16) {
        ShareButton(item: "https://github.com/isamercan/ThemeKit")
        ShareButton("Send", item: "https://github.com/isamercan/ThemeKit")
            .icon("paperplane.fill")
            .accent(.success)
            .size(.small)
    }
    .padding()
}
