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

    public init(_ title: String = "Share", item: String) {
        self.title = title
        self.item = item
    }

    public var body: some View {
        ShareLink(item: item) {
            Label(title, systemImage: "square.and.arrow.up")
                .textStyle(.labelBase600)
                .padding(.horizontal, Theme.SpacingKey.md.value)
                .frame(height: 44)
                .foregroundStyle(theme.foreground(.fgSecondary))
                .background(theme.foreground(.fgHero),
                            in: RoundedRectangle(cornerRadius: Theme.RadiusKey.sm.value, style: .continuous))
        }
    }
}

#Preview {
    ShareButton(item: "https://github.com/isamercan/ThemeKit")
        .padding()
}
